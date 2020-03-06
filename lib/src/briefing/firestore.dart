// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elements.dart';
import '../../datastore.dart';
import '../../firestore.dart';
import '../../sync.dart';

import 'briefingdata.dart';

const ITEMS_COLLECTION = 'items';

class BriefingFirestoreSync extends FirestoreSync {
  final InMemoryDatastore<CompositeData> datastore;
  ReadList<ItemRecord> items;
  Map<DataId, BriefingDataSync> dataSyncs = Map<DataId, BriefingDataSync>();

  BriefingFirestoreSync(this.datastore) : super(datastore, ITEMS_COLLECTION);

  void start() {
    items = datastore.runQuery(StarQuery(), zone, FIRESTORE_PRIORITY).cast<ItemRecord>();
    items.observe(zone.makeOperation(_itemsUpdated), zone);
  }

  void _itemsUpdated() {
    List<ItemRecord> itemsList = items.elements;

    for (int i = 0; i < itemsList.length; ++i) {
      ItemRecord item = itemsList[i];
      if (dataSyncs.containsKey(item.dataId)) {
        continue;
      }

      BriefingDataSync dataSync = BriefingDataSync(this, item);
      dataSyncs[item.dataId] = dataSync;
      dataSync.start();
    }
  }
}

class BriefingDataSync extends DataSync<ItemRecord> {
  BriefingDataSync(FirestoreSync firestoreSync, ItemRecord localState)
      : super(firestoreSync, localState);

  void observeLocalState(ItemRecord localState, Operation operation) {
    localState.unread.observeRef(operation, zone);
  }

  ItemRecord _newItemRecord(VersionId version, bool unread) {
    ItemRecord item =
        ItemRecord(dataId, null, null, null, null, null, null, unread, BaseMutableList<Address>());
    item.version = version;
    return item;
  }

  ItemRecord initNetworkState() {
    return _newItemRecord(VERSION_ZERO, false);
  }

  void setLocalData(ItemRecord localState, ItemRecord fromNetwork) {
    localState.version = fromNetwork.version;
    localState.unread.value = fromNetwork.unread.value;
  }

  ItemRecord copy(ItemRecord origin) {
    return _newItemRecord(origin.version, origin.unread.value);
  }

  Map<String, dynamic> toJson(ItemRecord state) {
    return {VERSION_FIELD: marshalVersion(state.version), UNREAD_FIELD: state.unread.value};
  }

  ItemRecord fromSnapshot(DocumentSnapshot snapshot) {
    VersionId version = unmarshalVersion(snapshot.data[VERSION_FIELD]);
    bool unread = snapshot.data[UNREAD_FIELD] as bool;

    return _newItemRecord(version, unread);
  }
}
