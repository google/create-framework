// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../flutterviews.dart';

import 'paint.dart';
import 'firestore.dart';

void paintMain() {
  DataId paintId = TaggedDataId(PAINT_NAMESPACE, '0');
  PaintData data = PaintData(paintId, []);

  PaintApp app = PaintApp(data);

  PaintFirestoreSync(data, app).setup();
  FlutterApp(app.view).run();
}
