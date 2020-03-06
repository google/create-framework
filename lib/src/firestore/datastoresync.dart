// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elements.dart';
import '../../datastore.dart';
import '../../sync.dart';

import 'base.dart';
import 'autosync.dart';

const Priority FIRESTORE_PRIORITY = Priority.NORMAL;

class DatastoreSync extends FirestoreSync {
  final InMemoryDatastore<CompositeData> datastore;
  final Map<String, DataType> _typesByName = new Map<String, DataType>();
  final Map<String, EnumData> _enumMap = new Map<String, EnumData>();
  ReadList<CompositeData> _records;
  Map<DataId, AutoSync> _autoSyncs = Map<DataId, AutoSync>();
  Map<String, AutoSync> _autoSyncsByName = Map<String, AutoSync>();

  DatastoreSync(this.datastore, String collectionId) : super(datastore, collectionId) {
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

  EnumData enumLookupByName(String name) {
    return _enumMap[name];
  }

  void start() {
    _records = datastore.runQuery(StarQuery(), zone, FIRESTORE_PRIORITY);
    _records.observe(zone.makeOperation(_recordsUpdated), zone);
    _recordsUpdated();

    // TODO: optimize the query so only recent documents are returned
    // by setting a constraint on version
    firestore.collection(collectionId).snapshots().listen(_collectionUpdated);
  }

  void _collectionUpdated(QuerySnapshot data) {
    for (DocumentSnapshot snapshot in data.documents) {
      if (!_autoSyncsByName.containsKey(snapshot.documentID)) {
        CompositeData data = dataFromSnapshot(this, snapshot);
        AutoSync autoSync = AutoSync(this, data);
        _addAutoSync(autoSync);
        datastore.add(data);
        autoSync.autoBumpVersion();
        autoSync.start();
      }
    }
  }

  void _addAutoSync(AutoSync autoSync) {
    _autoSyncs[autoSync.dataId] = autoSync;
    _autoSyncsByName[marshalDataId(autoSync.dataId)] = autoSync;
  }

  void _recordsUpdated() {
    List<CompositeData> recordsList = _records.elements;

    for (int i = 0; i < recordsList.length; ++i) {
      CompositeData record = recordsList[i];
      if (_autoSyncs.containsKey(record.dataId)) {
        continue;
      }

      AutoSync autoSync = AutoSync(this, record);
      _addAutoSync(autoSync);
      autoSync.autoBumpVersion();
      autoSync.start();
    }
  }
}
