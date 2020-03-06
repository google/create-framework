// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;

import 'package:firebase/firebase_io.dart';
import "package:eventsource/eventsource.dart";

import 'datasync.dart';

const String _JSON_SUFFIX = '.json';

const String _BRIEFING_API = 'https://briefing2.firebaseio.com/';
const String _BRIEFING_STRINGSTORE = _BRIEFING_API + 'stringstore' + _JSON_SUFFIX;

const String DATA_KEY = 'data';

class FirebaseTransport extends DataTransport {
  final FirebaseClient firebase = FirebaseClient.anonymous();

  FirebaseTransport() {
    print('Firebase transport: $_BRIEFING_STRINGSTORE');
  }

  void store(String content, void onComplete()) {
    Map<String, dynamic> json = {DATA_KEY: content};
    firebase.put(_BRIEFING_STRINGSTORE, json).then((result) {
      print('Store: put completed');
    }).whenComplete(onComplete);
  }

  void load(void onSuccess(String s), void onFailure(), void onComplete()) {
    firebase.get(_BRIEFING_STRINGSTORE).then((response) {
      print('Load: got state from server');
      if (onSuccess != null) {
        onSuccess(response[DATA_KEY]);
      }
    }, onError: (e) {
      print('Load: got error from server');
      if (onFailure != null) {
        onFailure();
      }
    }).whenComplete(onComplete);
  }

  void listen(void received(String s)) {
    EventSource.connect(_BRIEFING_STRINGSTORE).then((response) {
      response.listen((Event event) {
        if (event.event != 'put') {
          return;
        }

        Map<String, dynamic> dataJson = convert.json.decode(event.data);
        String data = dataJson['data'][DATA_KEY];
        print('Listen: got state from server');
        received(data);
      });
    });
  }
}
