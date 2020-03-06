// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elements.dart';
import '../../sync.dart';

import 'base.dart';
import 'datastoresync.dart';

const String SERVER_TIMESTAMP = '#timestamp';

abstract class DataSync<T extends CompositeData> {
  FirestoreSync _firestoreSync;
  final T _localState;
  T _networkState;
  bool _writeInProgress = false;
  bool _enableBumpVersion = true;

  DataSync(this._firestoreSync, this._localState);

  Firestore get firestore => _firestoreSync.firestore;

  DatastoreSync get datastoreSync => _firestoreSync is DatastoreSync ? _firestoreSync : null;

  bool get logSync => _firestoreSync.logSync;

  Zone get zone => _firestoreSync.zone;

  String get collectionId => _firestoreSync.collectionId;

  DataId get dataId => _localState.dataId;

  CompositeDataType get dataType => _localState.dataType;

  void start() {
    observeLocalState(_localState, zone.makeOperation(updatedLocal, 'updatedLocal'));

    _networkState = initNetworkState();
    Stream<DocumentSnapshot> snapshots = dataDocument.snapshots();
    snapshots.listen((DocumentSnapshot snapshot) {
      if (snapshot == null || !snapshot.exists || snapshot.data == null) {
        log('Null snapshot', _localState);
        setNetworkData();
      } else {
        Timestamp timestamp = snapshot.data[SERVER_TIMESTAMP];
        if (timestamp != null) {
          log('Snapshot', snapshot.data);
          log('Timestamp', timestamp.millisecondsSinceEpoch);
          _writeInProgress = false;
          updatedNetwork(fromSnapshot(snapshot));
        } else {
          log('Null timestamp', snapshot.data);
        }
      }
    });
  }

  void autoBumpVersion() {
    Operation op = (zone as BaseZone).makeSynchronousOperation(_bumpVersion, 'bumpVersion');
    observeLocalState(_localState, op);
  }

  void _bumpVersion() {
    if (_enableBumpVersion) {
      _localState.version = _localState.version.nextVersion();
    }
  }

  DocumentReference get dataDocument =>
      firestore.collection(collectionId).document(marshalDataId(dataId));

  void updatedNetwork(T fromNetwork) {
    if (_localState.version == fromNetwork.version) {
      log('updatedNetwork(same)', fromNetwork);
      return;
    }

    bool firstUpdate = _networkState.version == VERSION_ZERO;

    if (firstUpdate || fromNetwork.version.isAfter(_localState.version)) {
      log('updatedNetwork(networkNewer)', fromNetwork);
      _networkState = fromNetwork;
      updateLocalData();
      return;
    }

    log('updatedNetwork(localNewer)', _localState);
    setNetworkData();
  }

  void updatedLocal() {
    if (_localState.version == _networkState.version) {
      log('updatedLocal(same)', _networkState);
      return;
    }

    if (_networkState.version.isAfter(_localState.version)) {
      log('updatedLocal(networkNewer)', _networkState);
      updateLocalData();
      return;
    }

    log('updatedLocal(localNewer)', _localState);
    setNetworkData();
  }

  setNetworkData() {
    if (_writeInProgress) {
      return;
    }

    _networkState = copy(_localState);

    Map<String, dynamic> json = toJson(_networkState);
    json[SERVER_TIMESTAMP] = FieldValue.serverTimestamp();

    _writeInProgress = true;
    dataDocument.setData(json);
  }

  void updateLocalData() {
    _enableBumpVersion = false;
    setLocalData(_localState, _networkState);
    _enableBumpVersion = true;
  }

  void log(String text, [Object data]) {
    if (logSync) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;

      if (data != null) {
        print('$timestamp $text $dataId $data');
      } else {
        print('$timestamp $text $dataId');
      }
    }
  }

  void observeLocalState(T localState, Operation operation);

  T initNetworkState();

  void setLocalData(T localState, T fromNetwork);

  T copy(T origin);

  Map<String, dynamic> toJson(T state);

  T fromSnapshot(DocumentSnapshot snapshot);
}
