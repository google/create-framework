// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'config.dart';
import 'src/briefing/main.dart';
import 'src/counter/main.dart';
import 'src/create/main.dart';
import 'src/paint/main.dart';
import 'src/slider/main.dart';

void main() {
  print('Config: $APPLICATION');

  switch (APPLICATION) {
    case ApplicationConfig.BRIEFING_GMAIL:
    case ApplicationConfig.BRIEFING_HACKER_NEWS_PREPARED:
    case ApplicationConfig.BRIEFING_HACKER_NEWS_LIVE:
      briefingMain();
      break;

    case ApplicationConfig.COUNTER:
      counterMain();
      break;

    case ApplicationConfig.CREATE_LEGACY:
    case ApplicationConfig.CREATE_RESET:
    case ApplicationConfig.CREATE_FIRESTORE:
    case ApplicationConfig.CREATE_DEMO:
      createMain();
      break;

    case ApplicationConfig.PAINT:
      paintMain();
      break;

    case ApplicationConfig.SLIDER:
      sliderMain();
      break;

    default:
      throw StateError('Unknown app $APPLICATION');
  }
}
