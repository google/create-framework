// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elements.dart';
import '../../sync.dart';

import 'base.dart';
import 'datasync.dart';
import 'datastoresync.dart';

// DataSyncer that uses FieldVisitor API to access CompositeData state.
class AutoSync extends DataSync<CompositeData> {
  AutoSync(FirestoreSync firestoreSync, CompositeData localState)
      : super(firestoreSync, localState);

  void observeLocalState(CompositeData localState, Operation operation) {
    localState.visit(_ObserveFields(operation, zone));
  }

  CompositeData initNetworkState() {
    CompositeData result = dataType.newInstance(dataId);

    result.version = VERSION_ZERO;
    result.visit(_InitFields());

    return result;
  }

  void setLocalData(CompositeData localState, CompositeData fromNetwork) {
    localState.version = fromNetwork.version;

    List<dynamic> fields = [];
    fromNetwork.visit(_ReadFields(fields));
    localState.visit(_WriteFields(fields));
  }

  CompositeData copy(CompositeData origin) {
    CompositeData result = dataType.newInstance(dataId);

    setLocalData(result, origin);

    return result;
  }

  Map<String, dynamic> toJson(CompositeData state) {
    Map<String, dynamic> fieldMap = LinkedHashMap<String, dynamic>();

    fieldMap[TYPE_FIELD] = marshalType(state.dataType);
    fieldMap[VERSION_FIELD] = marshalVersion(state.version);
    fieldMap[DEPENDENCY_FIELD] = state.dependency;

    state.visit(_MarshallFields(fieldMap));

    return fieldMap;
  }

  CompositeData fromSnapshot(DocumentSnapshot snapshot) {
    CompositeData result = dataType.newInstance(dataId);

    result.version = unmarshalVersion(snapshot.data[VERSION_FIELD]);
    result.visit(_UnmarshallFields(snapshot.data, datastoreSync));

    return result;
  }
}

CompositeData dataFromSnapshot(DatastoreSync datastoreSync, DocumentSnapshot snapshot) {
  String typeId = snapshot.data[TYPE_FIELD];

  if (typeId == null) {
    throw StateError('Type field not set.');
  }

  DataType dataType = datastoreSync.lookupType(typeId);
  DataId dataId = unmarshalDataId(snapshot.documentID);

  CompositeData data = (dataType as CompositeDataType).newInstance(dataId);

  data.version = unmarshalVersion(snapshot.data[VERSION_FIELD]);
  data.dependency = snapshot.data[DEPENDENCY_FIELD] as bool;
  data.visit(_UnmarshallFields(snapshot.data, datastoreSync));

  return data;
}

// A helper class that registers and observer on all fields of a composite data type.
// TODO: the same code is in lib/src/elements/types.dart
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

// Initialize fields of CompositeData.
class _InitFields implements FieldVisitor {
  void stringField(String fieldName, Ref<String> field) => field.value = '';
  void boolField(String fieldName, Ref<bool> field) => field.value = false;
  void intField(String fieldName, Ref<int> field) => field.value = 0;
  void doubleField(String fieldName, Ref<double> field) => field.value = 0.0;
  void dataField(String fieldName, Ref<Data> field, DataType dataType) => field.value = null;
  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      field.clear();
}

// Copy fields of CompositeData into a list.
class _ReadFields implements FieldVisitor {
  final List<dynamic> fields;

  _ReadFields(this.fields);

  void stringField(String fieldName, Ref<String> field) => fields.add(field.value);
  void boolField(String fieldName, Ref<bool> field) => fields.add(field.value);
  void intField(String fieldName, Ref<int> field) => fields.add(field.value);
  void doubleField(String fieldName, Ref<double> field) => fields.add(field.value);
  void dataField(String fieldName, Ref<Data> field, DataType dataType) => fields.add(field.value);
  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      fields.add(field.elements);
}

// Copy fields of CompositeData from a list into a data object.
class _WriteFields implements FieldVisitor {
  final List<dynamic> fields;
  int index = 0;

  _WriteFields(this.fields);

  void stringField(String fieldName, Ref<String> field) => field.value = fields[index++] as String;
  void boolField(String fieldName, Ref<bool> field) => field.value = fields[index++] as bool;
  void intField(String fieldName, Ref<int> field) => field.value = fields[index++] as int;
  void doubleField(String fieldName, Ref<double> field) => field.value = fields[index++] as double;
  void dataField(String fieldName, Ref<Data> field, DataType dataType) =>
      field.value = fields[index++] as Data;
  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      field.replaceWith(fields[index++] as List<dynamic>);
}

// Marshal fields of CompositeData into a JSON.
class _MarshallFields implements FieldVisitor {
  final Map<String, dynamic> fieldMap;

  _MarshallFields(this.fieldMap);

  void stringField(String fieldName, Ref<String> field) {
    fieldMap[fieldName] = field.value;
  }

  void boolField(String fieldName, Ref<bool> field) {
    fieldMap[fieldName] = field.value;
  }

  void intField(String fieldName, Ref<int> field) {
    fieldMap[fieldName] = field.value;
  }

  void doubleField(String fieldName, Ref<double> field) {
    fieldMap[fieldName] = field.value;
  }

  Object _marshallData(Object anyData) {
    if (anyData == null) {
      return null;
    }

    if (anyData is double) {
      return anyData;
    }

    Data data = anyData as Data;

    if (data is EnumData) {
      return marshalEnum(data);
    }

    if (data is DataType) {
      return marshalType(TYPE_ID_DATATYPE) + ID_SEPARATOR + marshalType(data);
    }

    StringBuffer result = StringBuffer(marshalType(data.dataType));
    result.write(ID_SEPARATOR);
    result.write(marshalDataId(data.dataId));

    if (data is Named) {
      result.write(NAME_SEPARATOR);
      result.write((data as Named).name);
    }

    return result.toString();
  }

  void dataField(String fieldName, Ref<Data> field, DataType dataType) {
    fieldMap[fieldName] = _marshallData(field.value);
  }

  void listField(String fieldName, MutableList<Object> field, DataType elementType) {
    if (elementType is ImmutableCompositeDataType) {
      List<dynamic> elements = [];
      for (Data element in field.elements) {
        if (element != null) {
          assert(element.dataType == elementType);
          Map<String, dynamic> dataMap = LinkedHashMap<String, dynamic>();
          (element as ImmutableCompositeData).visit(_MarshallFields(dataMap));
          elements.add(dataMap);
        } else {
          elements.add(null);
        }
      }

      fieldMap[fieldName] = elements;
    } else {
      fieldMap[fieldName] = List.from(field.elements.map(_marshallData));
    }
  }
}

// Unmarshal fields from JSON to a CompositeData object.
class _UnmarshallFields implements FieldVisitor {
  final Map<String, dynamic> fieldMap;
  final DatastoreSync datastoreSync;

  _UnmarshallFields(this.fieldMap, this.datastoreSync);

  void stringField(String fieldName, Ref<String> field) {
    field.value = fieldMap[fieldName] as String;
  }

  void boolField(String fieldName, Ref<bool> field) {
    field.value = fieldMap[fieldName] as bool;
  }

  void intField(String fieldName, Ref<int> field) {
    field.value = fieldMap[fieldName] as int;
  }

  void doubleField(String fieldName, Ref<double> field) {
    field.value = fieldMap[fieldName] as double;
  }

  Object _unmarshallData(Object value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    String stringValue = value as String;
    int idIndex = stringValue.indexOf(ID_SEPARATOR);
    if (idIndex < 0) {
      return null;
    }

    if (datastoreSync == null) {
      throw StateError('Can\'t unmarshall data with no datastore.');
    }
    DataType dataType = datastoreSync.lookupType(stringValue.substring(0, idIndex));

    idIndex += ID_SEPARATOR.length;
    String id;
    int nameIndex = stringValue.indexOf(NAME_SEPARATOR, idIndex);
    if (nameIndex > 0) {
      id = stringValue.substring(idIndex, nameIndex);
    } else {
      id = stringValue.substring(idIndex);
    }

    if (dataType == TYPE_ID_DATATYPE) {
      return datastoreSync.lookupType(id);
    } else if (dataType is CompositeDataType) {
      return datastoreSync.lookupById(unmarshalDataId(id));
    } else if (dataType is EnumDataType) {
      EnumData result = datastoreSync.enumLookupByName(stringValue);
      // Fallback to a linear lookup
      if (result == null) {
        result = dataType.values.firstWhere((value) => (value.enumId == id), orElse: () => null);
      }
      if (result == null) {
        print('Unknown enum value for $stringValue');
      }
      return result;
    } else {
      print('Unknown type for $stringValue');
      return null;
    }
  }

  void dataField(String fieldName, Ref<Data> field, DataType dataType) {
    field.value = _unmarshallData(fieldMap[fieldName] as String);
  }

  void listField(String fieldName, MutableList<Object> field, DataType elementType) {
    List<dynamic> jsonElements = fieldMap[fieldName] as List<dynamic>;
    if (jsonElements == null) {
      return;
    }

    List<Data> elements;

    if (elementType is ImmutableCompositeDataType) {
      elements = List<Data>();
      for (dynamic element in jsonElements) {
        if (element != null) {
          ImmutableCompositeData data = elementType.newInstance(null);
          Map<String, dynamic> dataMap = element.cast<String, dynamic>();
          data.visit(_UnmarshallFields(dataMap, datastoreSync));
          elements.add(data);
        } else {
          elements.add(null);
        }
      }
    } else {
      elements = List.from(jsonElements.map((v) => _unmarshallData(v)));
    }

    field.replaceWith(elements);
  }
}
