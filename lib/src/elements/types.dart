// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'base.dart';
import 'runtime.dart';

/// Type for values each of which has a name.
/// The name is mostly used for debugging.
abstract class Named {
  String get name;
}

abstract class BaseNamed implements Named {
  final String name;
  const BaseNamed(this.name);
  String toString() => name;
}

/// The display function is used to render a human-readable name of an object.
typedef String DisplayFunction(Object object);

/// Identify namespace/module that type or value is associated with.
/// 'name' is a human-readable name, 'id' is an unique id for serialization.
class Namespace extends BaseNamed {
  final String id;
  const Namespace(String name, this.id) : super(name);
}

const Namespace ELEMENTS_NAMESPACE = const Namespace('Elements', 'elements');

/// Data types identify runtime type of Data objects.
abstract class DataType implements Named, Data {
  Namespace get namespace;
}

const DataType TYPE_ID_DATATYPE = const BuiltinDataType('type_id');

const DataType VOID_DATATYPE = const BuiltinDataType('void');
const DataType BOOLEAN_DATATYPE = const BuiltinDataType('boolean');
const DataType INTEGER_DATATYPE = const BuiltinDataType('integer');
const DataType REAL_DATATYPE = const BuiltinDataType('real');
const DataType STRING_DATATYPE = const BuiltinDataType('string');
const DataType LIST_DATATYPE = const BuiltinDataType('list');
const DataType ANY_DATATYPE = const BuiltinDataType('any');

/// Base datatypes consist of a namespace and a name.
abstract class BaseDataType extends BaseNamed implements DataType, DataId {
  final Namespace namespace;

  const BaseDataType(this.namespace, String name) : super(name);

  /// BaseDataType is its own dataId
  DataId get dataId => this;

  DataType get dataType => TYPE_ID_DATATYPE;
}

class BuiltinDataType extends BaseDataType {
  const BuiltinDataType(String name) : super(ELEMENTS_NAMESPACE, name);
}

/// Data IDs uniquely identify instances of Data objects.
/// Equality and hashCode should be correctly defined on DataIds.
abstract class DataId {}

/// Data objects are have type and identity.
abstract class Data {
  // Data types are immutable for the lifetime of the data object
  DataType get dataType;
  // Data ids are immutable and globally unique
  DataId get dataId;
}

/// Data types for EnumData objects.
abstract class EnumDataType extends BaseDataType {
  const EnumDataType(Namespace namespace, String name) : super(namespace, name);

  List<EnumData> get values;
}

/// Enum values are immutable data objects that are of the specified type.
abstract class EnumData extends BaseNamed implements Data, DataId, Observable {
  const EnumData(String name) : super(name);

  /// Enum data value is its own dataId
  DataId get dataId => this;

  EnumDataType get dataType;

  String get enumId => name.toLowerCase();

  /// Enum data values are immutable, hence observe() is a noop
  void observe(Operation observer, Lifespan lifespan) => null;
}

/// Data types for composite objects (regular classes, not enums.)
abstract class CompositeDataType extends BaseDataType {
  const CompositeDataType(Namespace namespace, String name) : super(namespace, name);

  CompositeData newInstance(DataId dataId);
}

/// Data types for composite objects (regular classes, not enums.)
abstract class ImmutableCompositeDataType extends CompositeDataType {
  const ImmutableCompositeDataType(Namespace namespace, String name) : super(namespace, name);

  ImmutableCompositeData newInstance(DataId dataId);
}

/// Data types for immutable composite objects
abstract class ImmutableDataType extends BaseDataType {
  const ImmutableDataType(Namespace namespace, String name) : super(namespace, name);
}

/// Version identifiers.
abstract class VersionId {
  VersionId nextVersion();
  bool isAfter(VersionId other);
}

/// Generator for DataIds.
abstract class DataIdSource {
  DataId nextId();
}

/// Declaration of composite data value that's stored in the Datastore.
abstract class CompositeData implements Data, Observable {
  CompositeDataType get dataType;
  VersionId version;
  bool dependency = false;

  CompositeData(this.version);

  void visit(FieldVisitor visitor);
}

/// Declaration of composite data that never changes state.
abstract class ImmutableCompositeData extends CompositeData with BaseImmutable {
  ImmutableCompositeDataType get dataType;

  ImmutableCompositeData() : super(VERSION_ZERO);
}

/// Field visitor is used for reflection on the composite data values.
abstract class FieldVisitor {
  void stringField(String fieldName, Ref<String> field);
  void boolField(String fieldName, Ref<bool> field);
  void intField(String fieldName, Ref<int> field);
  void doubleField(String fieldName, Ref<double> field);
  void dataField(String fieldName, Ref<Data> field, DataType dataType);
  void listField(String fieldName, MutableList<Object> field, DataType elementType);
}

/// Timestamps as version identifiers.
class TimestampVersion implements VersionId {
  final int milliseconds;

  const TimestampVersion(this.milliseconds);

  VersionId nextVersion() => new TimestampVersion(new DateTime.now().millisecondsSinceEpoch);
  bool isAfter(VersionId other) => milliseconds > ((other as TimestampVersion).milliseconds);

  String toString() => milliseconds.toString();
  bool operator ==(o) => o is TimestampVersion && milliseconds == o.milliseconds;
  int get hashCode => milliseconds.hashCode;
}

/// The smallest version idnetfier.
const VersionId VERSION_ZERO = const TimestampVersion(0);

/// String tags as DataIds.
// TODO(dynin): switch to using UUIDs.
class TaggedDataId implements DataId {
  final String tag;

  TaggedDataId(Namespace namespace, String id) : tag = namespace.id + ':' + id;
  TaggedDataId.fromInt(Namespace namespace, int id) : tag = namespace.id + ':' + id.toString();
  TaggedDataId.deserialize(this.tag);

  String get stripNamespace => tag.substring(tag.indexOf(':') + 1);

  String toString() => tag;
  bool operator ==(o) => o is TaggedDataId && tag == o.tag;
  int get hashCode => tag.hashCode;
}

/// Generator of sequential DataIds.
class SequentialIdSource extends DataIdSource {
  Namespace namespace;
  int _nextNumber = 0;

  SequentialIdSource(this.namespace);

  DataId nextId() => TaggedDataId.fromInt(namespace, _nextNumber++);
}

/// Generator of random DataIds.
class RandomIdSource extends DataIdSource {
  Namespace namespace;
  math.Random _random = new math.Random();

  RandomIdSource(this.namespace);
  DataId nextId() => TaggedDataId.fromInt(namespace, _random.nextInt(math.pow(2, 31)));
}

/// Base class for composite data types.
abstract class BaseCompositeData extends CompositeData {
  BaseCompositeData() : super(VERSION_ZERO);

  void observe(Operation observer, Lifespan lifespan) {
    visit(new _ObserveFields(observer, lifespan));
  }
}

/// A helper class that registers and observer on all fields of a composite data type.
class _ObserveFields implements FieldVisitor {
  final Operation observer;
  final Lifespan lifespan;

  _ObserveFields(this.observer, this.lifespan);

  void stringField(String fieldName, Ref<String> field) => observeDeep(field);
  void boolField(String fieldName, Ref<bool> field) => observeDeep(field);
  void intField(String fieldName, Ref<int> field) => observeDeep(field);
  void doubleField(String fieldName, Ref<double> field) => observeDeep(field);
  void dataField(String fieldName, Ref<Data> field, DataType dataType) => observeDeep(field);
  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      field.observe(observer, lifespan);

  void observeDeep(ReadRef ref) {
    ref.observeDeep(observer, lifespan);
  }
}

/// A function that returns a name for displaying to the user.
DisplayFunction displayName(String nullName) => (value) => (value is Named ? value.name : nullName);
