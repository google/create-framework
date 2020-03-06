// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async' as async;
import 'dart:collection';

import 'base.dart';

/// Adapter for converting a procedure into a disposable object.
class DisposeProcedure implements Disposable {
  final void Function() _dispose;

  DisposeProcedure(this._dispose);

  @override
  void dispose() {
    _dispose();
  }
}

/// A mixin that implements resourece management part of lifespan.
abstract class _ResourceManager implements Lifespan {
  final Set<Disposable> _resources = new Set<Disposable>();

  void addResource(Disposable resource) {
    _resources.add(resource);
  }

  void dispose() {
    _resources.forEach((r) => r.dispose());
    _resources.clear();
  }
}

/// An implementation of a hierarchical lifespan.
class BaseLifespan extends Lifespan with _ResourceManager {
  final Lifespan parent;
  final Zone zone;

  BaseLifespan(this.parent, this.zone) {
    if (parent != null) {
      parent.addResource(this);
    }
  }

  @override
  Lifespan makeSubSpan() => new BaseLifespan(this, zone);
}

/// An implementation of a zone.
class BaseZone extends Zone with _ResourceManager {
  final Zone parent;
  final String name;
  Zone get zone => this;

  BaseZone(this.parent, this.name) {
    if (parent != null) {
      parent.addResource(this);
    }
  }

  @override
  Lifespan makeSubSpan() => new BaseLifespan(this, this);

  @override
  Operation makeOperation(void procedure(), [String name]) =>
      new _BaseOperation(procedure, this, name, false);

  // For internal use by runtime and sync.
  Operation makeSynchronousOperation(void procedure(), String name) =>
      new _BaseOperation(procedure, this, name, true);
}

/// A mixin for immutable state.  Adding observer is an noop since state never changes.
/// A constant is a reference whose value never changes.
abstract class BaseImmutable implements Observable {
  @override
  void observe(Operation observer, Lifespan lifespan) => null;
}

class Constant<T> extends ReadRef<T> {
  final T value;

  const Constant(this.value);

  @override
  ReadRef<D> cast<D>() => Constant<D>(value as D);

  @override
  void observeRef(Operation observer, Lifespan lifespan) => null;
}

/// Maintains the set of observers for values.
abstract class _ObserverManager implements Observable {
  Set<Operation> _observers = new Set<Operation>();

  @override
  void observe(Operation observer, Lifespan lifespan) {
    _observers.add(observer);
    // TODO: make this work correctly if the same observer is registered multiple times
    lifespan.addResource(new DisposeProcedure(() => _observers.remove(observer)));
  }

  /// Trigger observers--to be used by the subclasses of ObserverManager.
  void _triggerObservers() {
    // We create a copy to avoid concurrent modification exceptions
    // from the observer code.
    // TODO: once event loops are introduced, we can stop doing it.
    _observers.toSet().forEach((observer) => observer.scheduleObserver());
  }
}

/// Public and non-abstract definition of ObserverManager
class ObserverManager extends _ObserverManager {
  void triggerObservers() => _triggerObservers();
}

/// Stores the value of type T, triggering observers when it changes.
abstract class _BaseState<T> extends ReadRef<T> {
  T _value;
  Set<Operation> _observers = new Set<Operation>();

  _BaseState([this._value]);

  @override
  T get value => _value;

  void observeRef(Operation observer, Lifespan lifespan) {
    _observers.add(observer);
    // TODO: make this work correctly if the same observer is registered multiple times
    lifespan.addResource(new DisposeProcedure(() => _observers.remove(observer)));
  }

  /// Update the state to a new value.
  void _setState(T newValue) {
    if (newValue != _value) {
      _value = newValue;
      _triggerObservers();
    }
  }

  /// Trigger observers.
  void _triggerObservers() {
    // We create a copy to avoid concurrent modification exceptions
    // from the observer code.
    // TODO: once event loops are introduced, we can stop doing it.
    _observers.toSet().forEach((observer) => observer.scheduleObserver());
  }
}

class _CastReadRef<S, T> extends ReadRef<T> {
  ReadRef<S> ref;

  _CastReadRef(this.ref);

  T get value => ref.value as T;

  void observeRef(Operation observer, Lifespan lifespan) => ref.observeRef(observer, lifespan);

  ReadRef<D> cast<D>() => new _CastReadRef<S, D>(ref);
}

class _CastRef<S, T> extends Ref<T> {
  Ref<S> ref;

  _CastRef(this.ref);

  T get value => ref.value as T;

  set value(T newValue) => ref.value = newValue as S;

  void observeRef(Operation observer, Lifespan lifespan) => ref.observeRef(observer, lifespan);

  Ref<D> cast<D>() => new _CastRef<S, D>(ref);
}

/// Boxed read-write value, exposing `WriteRef.set()`.
class Boxed<T> extends _BaseState<T> implements Ref<T> {
  Boxed([T value]) : super(value);

  @override
  set value(T newValue) => _setState(newValue);

  @override
  Ref<D> cast<D>() => new _CastRef<T, D>(this);
}

/// A reference that is written to exactly once.
/// Used in ImmutableCompositeType instances.
class WriteOnce<T> extends Ref<T> {
  T _value;

  WriteOnce([this._value]);

  @override
  T get value {
    if (_value == null) {
      throw StateError('Trying to access the state of WriteOnce instance that\'s not initialized');
    }
    return _value;
  }

  @override
  set value(T newValue) {
    if (_value != null) {
      throw StateError('Trying to set the state of WriteOnce instance that\'s been initialized');
    }
    _value = newValue;
  }

  @override
  void observeRef(Operation observer, Lifespan lifespan) {
    if (_value == null) {
      throw StateError('Trying to observe the state of WriteOnce instance that\'s not initialized');
    }
    // After the instance is initialized, it's state never changes.
  }

  @override
  Ref<D> cast<D>() => new _CastRef<T, D>(this);
}

const bool IMMEDIATE_OBSERVER_TRIGGER = false;

Set<_BaseOperation> _pendingObservers = new LinkedHashSet<_BaseOperation>();
List<_BaseOperation> _pendingActions = new List<_BaseOperation>();

bool get _hasPendingOperations => _pendingObservers.isNotEmpty || _pendingActions.isNotEmpty;

void _triggerPendingOperations() {
  while (_hasPendingOperations) {
    if (_pendingObservers.isNotEmpty) {
      _BaseOperation next = _pendingObservers.first;
      next._procedure();
      _pendingObservers.remove(next);
    } else {
      assert(_pendingActions.isNotEmpty);
      _BaseOperation next = _pendingActions.first;
      next._procedure();
      _pendingActions.removeAt(0);
    }
  }
}

/// A simple operation
class _BaseOperation implements Operation {
  final void Function() _procedure;
  final Zone zone;
  final String name;
  final bool synchronous;

  _BaseOperation(this._procedure, this.zone, this.name, this.synchronous);

  @override
  void scheduleAction() {
    if (synchronous || IMMEDIATE_OBSERVER_TRIGGER) {
      _procedure();
      return;
    }

    bool hadPendingOperations = _hasPendingOperations;
    _pendingActions.add(this);
    if (!hadPendingOperations) {
      async.scheduleMicrotask(_triggerPendingOperations);
    }
  }

  @override
  void scheduleObserver() {
    if (synchronous || IMMEDIATE_OBSERVER_TRIGGER) {
      _procedure();
      return;
    }

    if (_pendingObservers.contains(this)) {
      // print('Collapsing observer $this');
      return;
    }

    bool hadPendingOperations = _hasPendingOperations;
    _pendingObservers.add(this);
    if (!hadPendingOperations) {
      async.scheduleMicrotask(_triggerPendingOperations);
    }
  }

  @override
  String toString() => 'Operation ${zone.name}:$name';
}

/// A reactive function that converts a value of type S into a value of type T.
class ReactiveFunction<S, T> extends _BaseState<T> {
  final ReadRef<S> _source;
  final T Function(S source) _function;
  final Lifespan _lifespan;

  ReactiveFunction(this._source, this._function, this._lifespan) {
    _source.observeDeep(_lifespan.zone.makeOperation(_recompute), _lifespan);
    // TODO: we should lazily compute the value when the priority increases.
    _recompute();
  }

  void _recompute() {
    _setState(_function(_source.value));
  }

  @override
  ReadRef<D> cast<D>() => new _CastReadRef<T, D>(this);
}

/// A two-argument reactive function that combines values of S1 and S2 into a value of type T.
class ReactiveFunction2<S1, S2, T> extends _BaseState<T> {
  final ReadRef<S1> _source1;
  final ReadRef<S2> _source2;
  final T Function(S1 source1, S2 source2) _function;
  final Lifespan _lifespan;

  ReactiveFunction2(this._source1, this._source2, this._function, this._lifespan) {
    Operation recomputeOp = _lifespan.zone.makeOperation(recompute);
    _source1.observeDeep(recomputeOp, _lifespan);
    _source2.observeDeep(recomputeOp, _lifespan);
    // TODO: we should lazily compute the value when the priority increases.
    recompute();
  }

  void recompute() {
    _setState(_function(_source1.value, _source2.value));
  }

  @override
  ReadRef<D> cast<D>() => new _CastReadRef<T, D>(this);
}

abstract class _BaseReadList<E> implements ReadList<E> {
  ReadList<D> cast<D>() => new _CastList<E, D>(this);
}

/// Cast list from S (source type) to D (destination type).
class _CastList<S, D> extends _BaseReadList<D> {
  ReadList<S> _baseList;

  _CastList(this._baseList);

  void observe(Operation observer, Lifespan lifespan) => _baseList.observe(observer, lifespan);

  ReadRef<int> get size => _baseList.size;

  List<D> get elements => _baseList.elements.cast<D>();
}

/// An immutable list that implements ReadList interface.
class ImmutableList<E> extends _BaseReadList<E> with BaseImmutable {
  final List<E> elements;

  ImmutableList(this.elements);

  // TODO: cache the constant?
  ReadRef<int> get size => new Constant<int>(elements.length);
}

/// Since Dart doesn't have generic functions, we have to declare a special type here.
class MappedList<S, T> extends _BaseReadList<T> with _ObserverManager {
  final ReadList<S> _source;
  final T Function(S source) _function;
  List<T> _cachedElements;

  MappedList(this._source, this._function, Lifespan lifespan) {
    _source.observe(lifespan.zone.makeOperation(_sourceChanged), lifespan);
  }

  void _sourceChanged() {
    _cachedElements = null;
    _triggerObservers();
  }

  ReadRef<int> get size => _source.size;

  List<T> get elements {
    if (_cachedElements == null) {
      _cachedElements = new List<T>.from(_source.elements.map(_function));
    }
    return _cachedElements;
  }
}

/// A reactive function that converts a list of type S into a list of type T.
class ReactiveListFunction<S, T> extends _BaseReadList<T> with _ObserverManager {
  final MutableList<S> _source;
  final ReadList<T> Function(MutableList<S> source) _function;
  final Ref<int> size = new Boxed<int>();
  List<T> elements;

  ReactiveListFunction(this._source, this._function, Lifespan lifespan) {
    _source.observe(lifespan.zone.makeOperation(_recompute), lifespan);
    // TODO: we should lazily compute the value when the priority increases.
    _recompute();
  }

  void _recompute() {
    elements = _function(_source).elements;
    size.value = elements.length;
    _triggerObservers();
  }
}

/// Since Dart doesn't have generic functions, we have to declare a special type here.
class MappedWithIndexList<S, T> extends _BaseReadList<T> with _ObserverManager {
  final MutableList<S> _source;
  final T Function(Ref<S> source, int index) _function;
  List<T> _cachedElements;

  MappedWithIndexList(this._source, this._function, Lifespan lifespan) {
    _source.observe(lifespan.zone.makeOperation(_sourceChanged), lifespan);
  }

  void _sourceChanged() {
    _cachedElements = null;
    _triggerObservers();
  }

  ReadRef<int> get size => _source.size;

  List<T> get elements {
    if (_cachedElements == null) {
      _cachedElements = new List<T>();
      int sourceSize = _source.size.value;
      for (int i = 0; i < sourceSize; ++i) {
        _cachedElements.add(_function(_source.at(i), i));
      }
    }
    return _cachedElements;
  }
}

/// A list that can change state.
class JoinedList<E> extends _BaseReadList<E> with _ObserverManager {
  final Lifespan lifespan;
  final List<Object> backingElements = new List<Object>();
  final Ref<int> size = new Boxed<int>(0);
  List<E> elements = [];
  Operation update;

  JoinedList(this.lifespan) {
    update = lifespan.zone.makeOperation(_update, 'JoinedList.update');
  }

  void _update() {
    elements = new List<E>();
    for (Object listElement in backingElements) {
      if (listElement is ReadRef) {
        E element = listElement.value;
        if (element != null) {
          elements.add(element);
        }
      } else if (listElement is ReadList<E>) {
        elements.addAll(listElement.elements);
      } else {
        new StateError('Uncrecognized element $listElement');
      }
    }

    size.value = elements.length;
    _triggerObservers();
  }

  void add(ReadRef<E> elementRef) {
    backingElements.add(elementRef);
    elementRef.observeRef(update, lifespan);
    update.scheduleObserver();
  }

  void addConstant(E element) {
    add(new Constant<E>(element));
  }

  void addList(ReadList<E> elementsList) {
    backingElements.add(elementsList);
    elementsList.observe(update, lifespan);
    update.scheduleObserver();
  }

  ReadRef<E> at(int index) {
    assert(index >= 0 && index < elements.length);
    return new _JoinedListCell<E>(this, index);
  }
}

class _JoinedListCell<E> extends ReadRef<E> {
  final JoinedList<E> list;
  final int index;

  _JoinedListCell(this.list, this.index);

  @override
  E get value => list.elements[index];

  // TODO: precise observer.
  @override
  void observeRef(Operation observer, Lifespan lifespan) => list.observe(observer, lifespan);

  @override
  ReadRef<D> cast<D>() => new _CastReadRef<E, D>(this);
}

/// A list that can change state.
class BaseMutableList<E> extends MutableList<E> with _ObserverManager {
  final List<E> elements;
  Ref<int> size;

  BaseMutableList([List<E> initialState]) : elements = (initialState != null ? initialState : []) {
    size = new Boxed<int>(elements.length);
  }

  Ref<E> at(int index) {
    assert(index >= 0 && index < elements.length);
    return new _ListCell<E>(this, index);
  }

  void _updateSizeAndTriggerObservers() {
    size.value = elements.length;
    _triggerObservers();
  }

  void clear() {
    if (elements.isNotEmpty) {
      elements.clear();
      _updateSizeAndTriggerObservers();
    }
  }

  void add(E element) {
    elements.add(element);
    _updateSizeAndTriggerObservers();
  }

  void addAll(List<E> moreElements) {
    if (moreElements.isNotEmpty) {
      elements.addAll(moreElements);
      _updateSizeAndTriggerObservers();
    }
  }

  void replaceWith(List<dynamic> newElements) {
    bool listsEqual() {
      if (elements.length != newElements.length) {
        return false;
      }

      for (int i = 0; i < elements.length; ++i) {
        if (!(elements[i] == newElements[i])) {
          return false;
        }
      }

      return true;
    }

    if (!listsEqual()) {
      elements.clear();
      elements.addAll(newElements.cast<E>());
      _updateSizeAndTriggerObservers();
    }
  }

  void removeAt(int index) {
    assert(index >= 0 && index < elements.length);
    elements.removeAt(index);
    _updateSizeAndTriggerObservers();
  }

  MutableList<D> cast<D>() => new _CastMutableList<E, D>(this);
}

class _ListCell<E> extends Ref<E> {
  final BaseMutableList<E> list;
  final int index;

  _ListCell(this.list, this.index);

  @override
  E get value => list.elements[index];

  @override
  set value(E newValue) {
    if (list.elements[index] != newValue) {
      list.elements[index] = newValue;
      list._triggerObservers();
    }
  }

  // TODO: precise observer.
  @override
  void observeRef(Operation observer, Lifespan lifespan) => list.observe(observer, lifespan);

  @override
  Ref<D> cast<D>() => new _CastRef<E, D>(this);
}

/// Cast list from S (source type) to D (destination type).
class _CastMutableList<S, D> implements MutableList<D> {
  MutableList<S> _baseList;

  _CastMutableList(this._baseList);

  void observe(Operation observer, Lifespan lifespan) => _baseList.observe(observer, lifespan);

  ReadRef<int> get size => _baseList.size;

  List<D> get elements => _baseList.elements.cast<D>();

  Ref<D> at(int index) => _baseList.at(index).cast<D>();

  void clear() => _baseList.clear();

  void add(D element) => _baseList.add(element as S);

  void addAll(List<D> moreElements) => _baseList.addAll(moreElements.cast<S>());

  void replaceWith(List<D> newElements) => _baseList.replaceWith(newElements.cast<S>());

  void removeAt(int index) => _baseList.removeAt(index);

  MutableList<D2> cast<D2>() => new _CastMutableList<S, D2>(_baseList);
}

/// Check whether a reference is not null and holds a non-null value.
bool isNotNull(ReadRef ref) => (ref != null && ref.value != null);

// Missing from the Dart library; see https://github.com/dart-lang/sdk/issues/24374

/// Check whether this character is an ASCII digit.
bool isDigit(int c) {
  return c >= 0x30 && c <= 0x39;
}

/// Check whether this character is an ASCII letter.
bool isLetter(int c) {
  return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
}

/// Check whether this character is an ASCII letter or digit.
bool isLetterOrDigit(int c) {
  return isLetter(c) || isDigit(c);
}
