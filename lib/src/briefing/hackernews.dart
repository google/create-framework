// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import 'briefingdata.dart';
import 'dataset0.dart';

const Namespace HACKER_NEWS_NAMESPACE = const Namespace('Hacker News', 'news.ycombinator');

InMemoryDatastore<CompositeData> newDatastore() {
  return InMemoryDatastore<CompositeData>([ITEM_RECORD_DATATYPE].toSet());
}

ItemRecord parseHackerNewsItem(Map<String, dynamic> itemJson) {
  String from = itemJson['by'] as String;
  int descendants = itemJson['descendants'] as int;
  int id = itemJson['id'] as int;
  int score = itemJson['score'] as int;
  int time = itemJson['time'] as int;
  String title = itemJson['title'] as String;
  String url = itemJson['url'] as String;

  DataId dataId = TaggedDataId.fromInt(HACKER_NEWS_NAMESPACE, id);
  bool unread = true;
  MutableList<Address> addresses = BaseMutableList<Address>();

  return ItemRecord(dataId, from, descendants, score, time, title, url, unread, addresses);
}

Datastore<CompositeData> initHackerNewsPrepared() {
  Map<String, dynamic> jsonData = convert.json.decode(hackerNewsRaw);
  List<dynamic> jsonItems = jsonData['items'];
  List<ItemRecord> itemRecords = [];
  for (int i = 0; i < jsonItems.length && i < MAX_ITEMS; ++i) {
    ItemRecord record = parseHackerNewsItem(jsonItems[i] as Map);
    // TODO: this is for demo purposes only.
    if (i % 3 == 0) {
      record.unread.value = false;
    }
    itemRecords.add(record);
  }

  InMemoryDatastore<CompositeData> datastore = newDatastore();
  datastore.addAll(itemRecords, datastore.version);
  return datastore;
}
