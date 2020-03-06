// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:firebase/firebase_io.dart';

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import 'briefingdata.dart';
import 'priorities.dart';
import 'hackernews.dart';

const String _JSON_SUFFIX = '.json';

const String _HACKER_NEWS_API = 'https://hacker-news.firebaseio.com/v0/';
const String _HACKER_NEWS_TOP_STORIES = _HACKER_NEWS_API + 'topstories' + _JSON_SUFFIX;
const String _HACKER_NEWS_ITEM = _HACKER_NEWS_API + 'item/';

class HackerNewsSync {
  final InMemoryDatastore<CompositeData> datastore;
  final Zone syncZone = BaseZone(null, 'hacker_news_sync');
  final FirebaseClient firebase = FirebaseClient.anonymous();
  final RequestThrotller throttler = RequestThrotller(MAX_CONCURRENT_REQUESTS, LOG_REQUESTS);
  final Map<int, ItemRecord> itemsByIndex = Map<int, ItemRecord>();
  int lastIndex = 0;

  HackerNewsSync(this.datastore);

  void start() {
    throttler.schedule(topStories, null, syncZone, SYNC_PRIORITY);
  }

  void topStories(Operation done) {
    Future<dynamic> response = firebase.get(_HACKER_NEWS_TOP_STORIES);

    response.then((idList) {
      List<dynamic> ids = idList as List<dynamic>;
      for (int i = 0; i < MAX_ITEMS && i < ids.length; ++i) {
        int id = ids[i] as int;
        throttler.schedule((Operation done) => item(id, i, done), null, syncZone, SYNC_PRIORITY);
      }
      done.scheduleAction();
    }, onError: (Object obj) {
      print('Firebase get error: $obj');
    });
  }

  void item(int id, int index, Operation done) {
    Future<dynamic> response = firebase.get(_itemUri(id));

    response.then((itemObject) {
      Map<String, dynamic> itemMap = itemObject as Map<String, dynamic>;
      ItemRecord item = parseHackerNewsItem(itemMap);
      // TODO: this is for demo purposes only.
      if (index % 3 == 0) {
        item.unread.value = false;
      }
      itemsByIndex[index] = item;
      _addItemsToDatastore();
      done.scheduleAction();
    });
  }

  void _addItemsToDatastore() {
    while (itemsByIndex.containsKey(lastIndex)) {
      datastore.add(itemsByIndex[lastIndex++]);
    }
  }

  String _itemUri(int id) {
    return _HACKER_NEWS_ITEM + id.toString() + _JSON_SUFFIX;
  }
}

Datastore<CompositeData> initHackerNewsLive() {
  InMemoryDatastore<CompositeData> datastore = newDatastore();

  HackerNewsSync hackerNewsSync = HackerNewsSync(datastore);
  hackerNewsSync.start();

  return datastore;
}
