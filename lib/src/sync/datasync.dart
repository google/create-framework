// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library datasync;

import 'dart:async';
import 'dart:collection';
import 'dart:convert' as convert;

import '../../elements.dart';
import '../../datastore.dart';

const String NAMESPACE_SEPARATOR = '.';
const String ID_SEPARATOR = ':';
const String NAME_SEPARATOR = '//';

const SYNC_INTERVAL = const Duration(seconds: 1);

const String RECORDS_FIELD = 'records';
const String TYPE_FIELD = '#type';
const String ID_FIELD = '#id';
const String VERSION_FIELD = '#version';
const String DEPENDENCY_FIELD = '#dependency';

String marshalType(DataType dataType) =>
    dataType.namespace.id + NAMESPACE_SEPARATOR + dataType.name;

String marshalEnum(EnumData data) => marshalType(data.dataType) + ID_SEPARATOR + data.enumId;

String marshalDataId(DataId dataId) => (dataId as TaggedDataId).tag;

// TODO: error handling
DataId unmarshalDataId(String id) => new TaggedDataId.deserialize(id);

dynamic marshalVersion(VersionId versionId) => (versionId as TimestampVersion).milliseconds;

// TODO: error handling
VersionId unmarshalVersion(dynamic object) => new TimestampVersion(object as int);

abstract class DataTransport {
  void store(String content, void onComplete());
  void load(void onSuccess(String s), void onFailure(), void onComplete());
  void listen(void received(String s));
}

class DataSyncer {
  final InMemoryDatastore datastore;
  final DataTransport transport;
  final Map<String, DataType> _typesByName = new Map<String, DataType>();
  final Map<String, EnumData> _enumMap = new Map<String, EnumData>();
  final convert.JsonEncoder encoder = const convert.JsonEncoder.withIndent('  ');
  bool listening = false;
  bool observing = false;
  VersionId lastPushed;

  DataSyncer(this.datastore, this.transport) {
    datastore.dataTypes.forEach(_initType);
  }

  void _initType(DataType dataType) {
    _typesByName[marshalType(dataType)] = dataType;
    if (dataType is EnumDataType) {
      dataType.values.forEach((EnumData data) => _enumMap[marshalEnum(data)] = data);
    }
  }

  DataType lookupType(String name) {
    return _typesByName[name];
  }

  CompositeData lookupById(DataId dataId) {
    return datastore.lookupById(dataId);
  }

  void _scheduleSync() {
    new Timer(SYNC_INTERVAL, sync);
  }

  void sync() {
    if (datastore.version != lastPushed) {
      push();
    } else {
      pull();
    }
  }

  void push() {
    print('Pushing datastore: ${datastore.describe}');
    _pushState(_scheduleSync);

    if (!observing) {
      observing = true;
      Zone zone = datastore;
      Operation doPush = zone.makeOperation(() => _pushState(() => null));
      datastore.observeState(doPush, zone);
    }
  }

  void _pushState(void onComplete()) {
    List jsonRecords = new List.from(datastore.entireDatastoreState.map(_recordToJson));
    lastPushed = datastore.version;
    Map datastoreJson = {VERSION_FIELD: marshalVersion(lastPushed), RECORDS_FIELD: jsonRecords};

    transport.store(encoder.convert(datastoreJson), onComplete);
  }

  void _received(String content) {
    tryUmarshalling(content, datastore.version);
  }

  Map<String, dynamic> _recordToJson(CompositeData record) {
    _Marshaller marshaller = new _Marshaller(record);
    record.visit(marshaller);
    return marshaller.fieldMap;
  }

  void pull() {
    print('Pulling datastore: ${datastore.describe}');
    load(datastore.version, null, null);

    if (!listening) {
      listening = true;
      transport.listen(_received);
    }
  }

  void initialize(WriteRef<bool> dataReady, String fallbackDatastoreState) {
    void initCompleted() {
      dataReady.value = true;
    }

    load(null, initCompleted, (() {
      initFallback(fallbackDatastoreState);
      initCompleted();
    }));
  }

  void load(VersionId currentVersion, void onSuccess(), void onFailure()) {
    void unmarshal(String content) {
      if (tryUmarshalling(content, currentVersion)) {
        if (onSuccess != null) {
          onSuccess();
        }
      } else {
        if (onFailure != null) {
          onFailure();
        }
      }
    }

    if (transport != null) {
      transport.load(unmarshal, onFailure, _scheduleSync);
    } else {
      // Do an initFallback
      onFailure();
    }
  }

  bool tryUmarshalling(String responseBody, VersionId currentVersion) {
    try {
      print('Trying to unmarshal, response size ${responseBody.length}...');
      Map<String, dynamic> datastoreJson = convert.json.decode(responseBody);
      if (datastoreJson == null) {
        print('Decoded content is null');
        return false;
      }
      VersionId newVersion = unmarshalVersion(datastoreJson[VERSION_FIELD]);
      List<Map<String, dynamic>> jsonRecords =
          (datastoreJson[RECORDS_FIELD] as List<dynamic>).cast<Map<String, dynamic>>();
      if (newVersion == null || jsonRecords == null) {
        print('JSON fields missing');
        return false;
      }
      if (newVersion == currentVersion) {
        print('Same datastore version, no update.');
        return true;
      }
      print('Unmarshalling ${jsonRecords.length} records.');
      unmarshalDatastore(newVersion, jsonRecords);
      return true;
    } catch (e) {
      print('Got error $e');
      return false;
    }
  }

  void initFallback(String fallbackDatastoreState) {
    Map<String, dynamic> datastoreJson = convert.json.decode(fallbackDatastoreState);
    VersionId newVersion = unmarshalVersion(datastoreJson[VERSION_FIELD]);
    List<Map<String, dynamic>> jsonRecords =
        (datastoreJson[RECORDS_FIELD] as List<dynamic>).cast<Map<String, dynamic>>();
    print('Initializing fallback with ${jsonRecords.length} records.');
    unmarshalDatastore(newVersion, jsonRecords);
  }

  void unmarshalDatastore(VersionId newVersion, List<Map<String, dynamic>> jsonRecords) {
    List<_Unmarshaller> rawRecords =
        new List.from(jsonRecords.map((fields) => new _Unmarshaller(fields, this)));

    Map<DataId, _Unmarshaller> rawRecordsById = new Map<DataId, _Unmarshaller>();
    rawRecords.forEach((unmarshaller) => unmarshaller.addTo(rawRecordsById));
    bool hasLocalChanges = datastore.entireDatastoreState.any((CompositeData record) =>
        !rawRecordsById.containsKey(record.dataId) ||
        record.version.isAfter(rawRecordsById[record.dataId].version));

    datastore.startBulkUpdate(hasLocalChanges ? datastore.advanceVersion() : newVersion);
    rawRecords.forEach((unmarshaller) => unmarshaller.prepareRecord());
    rawRecords.forEach((unmarshaller) => unmarshaller.populateRecord());
    datastore.stopBulkUpdate();
    print('Unmarshalling done: ${datastore.describe}');
  }
}

class _Marshaller implements FieldVisitor {
  Map<String, dynamic> fieldMap = new LinkedHashMap<String, dynamic>();

  _Marshaller(CompositeData record) {
    fieldMap[TYPE_FIELD] = marshalType(record.dataType);
    fieldMap[ID_FIELD] = marshalDataId(record.dataId);
    fieldMap[VERSION_FIELD] = marshalVersion(record.version);
    fieldMap[DEPENDENCY_FIELD] = record.dependency;
  }

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

    if (anyData is double || anyData is int || anyData is bool) {
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
    fieldMap[fieldName] = List.from(field.elements.map(_marshallData));
  }
}

class _Unmarshaller implements FieldVisitor {
  final Map<String, dynamic> fieldMap;
  final DataSyncer datasyncer;
  DataType dataType;
  DataId dataId;
  VersionId version;
  bool dependency;
  CompositeData record;

  _Unmarshaller(this.fieldMap, this.datasyncer) {
    dataType = datasyncer.lookupType(fieldMap[TYPE_FIELD] as String);
    dataId = unmarshalDataId(fieldMap[ID_FIELD] as String);
    version = unmarshalVersion(fieldMap[VERSION_FIELD]);
    dependency = fieldMap[DEPENDENCY_FIELD] as bool;
  }

  bool get isValid => (dataType != null && dataId != null && version != null && dependency != null);

  void addTo(Map<DataId, _Unmarshaller> rawRecordsById) {
    if (isValid) {
      rawRecordsById[dataId] = this;
    }
  }

  void prepareRecord() {
    if (!isValid) {
      return;
    }

    assert(dataType is CompositeDataType);
    CompositeData oldRecord = datasyncer.lookupById(dataId);
    if (oldRecord == null) {
      Datastore datastore = datasyncer.datastore;
      record = (dataType as CompositeDataType).newInstance(dataId);
      record.version = version;
      record.dependency = dependency;
      datastore.add(record);
    } else {
      assert(oldRecord.dataType == dataType);
      // We update state only if the unmarshaled record is newer than the one in the datastore
      if (version.isAfter(oldRecord.version)) {
        record = oldRecord;
        record.version = version;
      }
    }
  }

  void populateRecord() {
    if (record == null) {
      return;
    }
    record.visit(this);
  }

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

  Object unmarshallData(Object value) {
    if (value == null) {
      return null;
    }

    if (value is double || value is int || value is bool) {
      return value;
    }

    String stringValue = value as String;
    int idIndex = stringValue.indexOf(ID_SEPARATOR);
    if (idIndex < 0) {
      return null;
    }
    DataType dataType = datasyncer.lookupType(stringValue.substring(0, idIndex));

    idIndex += ID_SEPARATOR.length;
    String id;
    int nameIndex = stringValue.indexOf(NAME_SEPARATOR, idIndex);
    if (nameIndex > 0) {
      id = stringValue.substring(idIndex, nameIndex);
    } else {
      id = stringValue.substring(idIndex);
    }

    if (dataType == TYPE_ID_DATATYPE) {
      return datasyncer.lookupType(id);
    } else if (dataType is CompositeDataType) {
      return datasyncer.lookupById(unmarshalDataId(id));
    } else if (dataType is EnumDataType) {
      EnumData result = datasyncer._enumMap[stringValue];
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
    field.value = unmarshallData(fieldMap[fieldName] as String);
  }

  void listField(String fieldName, MutableList<Object> field, DataType elementType) {
    List<Object> jsonElements = fieldMap[fieldName];
    if (jsonElements == null) {
      return;
    }
    List<Object> dataElements = List.from(jsonElements.map((v) => unmarshallData(v)));
    field.replaceWith(dataElements);
  }
}
