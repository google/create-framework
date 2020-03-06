// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../config.dart';
import '../../elements.dart';
import '../../flutterviews.dart';
import '../../datastore.dart';

import 'briefing.dart';
import 'firestore.dart';
import 'gmaildata.dart';
import 'hackernews.dart';
import 'hackernewssync.dart';

void briefingMain() {
  Datastore<CompositeData> datastore;

  switch (APPLICATION) {
    case ApplicationConfig.BRIEFING_GMAIL:
      datastore = GmailClient(readId())..start();
      break;

    case ApplicationConfig.BRIEFING_HACKER_NEWS_PREPARED:
      datastore = initHackerNewsPrepared();
      break;

    case ApplicationConfig.BRIEFING_HACKER_NEWS_LIVE:
      datastore = initHackerNewsLive();
      BriefingFirestoreSync(datastore).setup();
      break;

    default:
      throw StateError('Unknown app $APPLICATION');
  }

  new FlutterApp(BriefingApp(APPLICATION, datastore).view).run();
}

void main() {
  briefingMain();
}
