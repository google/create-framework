// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../flutterviews.dart';

import 'counter.dart';

void counterMain() {
  FlutterApp(CounterApp(CounterData()).view).run();
}

void main() {
  counterMain();
}
