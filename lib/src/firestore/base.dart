// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config.dart';
import '../../elements.dart';

abstract class FirestoreSync {
  final logSync = LOG_SYNC_REQUESTS;
  Firestore firestore;
  final Zone zone;
  final String collectionId;

  FirestoreSync(this.zone, this.collectionId);

  void setup() {
    WidgetsFlutterBinding.ensureInitialized();

    Future<Firestore> firestoreFuture = _setupAsync();
    firestoreFuture.then((Firestore configuredFirestore) {
      firestore = configuredFirestore;
      print('Starting Firestore sync.');
      start();
    }, onError: (Object obj) {
      if (obj is MissingPluginException) {
        print('Firestore plugin not found (works on iOS only).');
      } else {
        print('Firestore setup error: $obj');
      }
      print('Turning off Firestore sync.');
    });
  }

  FutureOr<Firestore> _setupAsync() async {
    final FirebaseApp app = await FirebaseApp.configure(
      name: 'test',
      // TODO: make options configurable
      options: null
    );
    final Firestore firestore = Firestore(app: app);
    await firestore.settings();
    return firestore;
  }

  void start();
}
