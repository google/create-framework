// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../firestore.dart';

import 'paint.dart';

const PAINT_COLLECTION = 'paint';

class PaintFirestoreSync extends FirestoreSync {
  final PaintData localState;

  PaintFirestoreSync(this.localState, Zone zone) : super(zone, PAINT_COLLECTION);

  void start() {
    AutoSync dataSync = AutoSync(this, localState);
    dataSync.autoBumpVersion();
    dataSync.start();
  }
}
