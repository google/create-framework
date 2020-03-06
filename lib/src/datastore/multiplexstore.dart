// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

import 'base.dart';

class SubDatastore<R extends CompositeData> {
  final Datastore<R> datastore;
  final Ref<bool> active = new Boxed<bool>(true);
  final ReadRef<String> name;

  SubDatastore(this.datastore, String name) : name = new Constant<String>(name);
}

class MuliplexDatastore<R extends CompositeData> implements Datastore<R> {
  // TODO(dynin): smarter support for multiple datastores.
  Set<DataType> get dataTypes => substores.elements[0].datastore.dataTypes;
  ReadList<SubDatastore<R>> substores;
  int addIndex;

  MuliplexDatastore(List<SubDatastore<R>> substores, this.addIndex)
      : substores = new ImmutableList<SubDatastore<R>>(substores);

  Iterable<SubDatastore<R>> get _activeSubstores =>
      substores.elements.where((SubDatastore<R> substore) => substore.active.value);

  @override
  ReadList<R> runQuery(QueryType<R> query, Lifespan lifespan, Priority priority) {
    if (lifespan == null) {
      List<R> result = new List<R>();
      for (SubDatastore<R> substore in _activeSubstores) {
        result.addAll(substore.datastore.runQuery(query, lifespan, priority).elements);
      }
      return new ImmutableList<R>(result);
    } else {
      JoinedList<R> result = new JoinedList<R>(lifespan);
      for (SubDatastore<R> substore in _activeSubstores) {
        result.addList(substore.datastore.runQuery(query, lifespan, priority));
      }
      return result;
    }
  }

  @override
  ReadRef<int> count(QueryType<R> query, Lifespan lifespan, Priority priority) {
    // TODO: optimize
    return runQuery(query, lifespan, priority).size;
  }

  @override
  ImmutableList<R> runQuerySync(QueryType<R> query) {
    List<R> result = [];
    for (SubDatastore<R> substore in _activeSubstores) {
      result.addAll(substore.datastore.runQuerySync(query).elements);
    }
    return ImmutableList<R>(result);
  }

  @override
  void add(R record) {
    substores.elements[addIndex].datastore.add(record);
  }
}
