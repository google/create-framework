// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../elements.dart';
import '../../firestore.dart';

import 'slider.dart';

const SLIDER_COLLECTION = 'slider';

class SliderFirestoreSync extends FirestoreSync {
  final SliderData localState;

  SliderFirestoreSync(this.localState, Zone zone) : super(zone, SLIDER_COLLECTION);

  void start() {
    AutoSync dataSync = AutoSync(this, localState);
    dataSync.autoBumpVersion();
    dataSync.start();
  }
}
