// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../flutterviews.dart';

import 'slider.dart';
import 'firestore.dart';

void sliderMain() {
  DataId sliderId = TaggedDataId(SLIDER_NAMESPACE, '0');
  SliderData data = SliderData(sliderId, 0.0);

  SliderApp app = SliderApp(data);

  SliderFirestoreSync(data, app).setup();
  FlutterApp(app.view).run();
}

void main() {
  sliderMain();
}
