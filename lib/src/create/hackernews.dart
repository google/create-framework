// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' as convert;

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import '../briefing/dataset0.dart';

const Namespace HACKER_NEWS_NAMESPACE = const Namespace('Hacker News', 'news.ycombinator');

UserCompositeType itemRecordType = makeItemRecordType();

const String FROM_FIELD = 'from';
const String TITLE_FIELD = 'title';
const String URL_FIELD = 'url';
const String UNREAD_FIELD = 'unread';

InMemoryDatastore<CompositeData> newDatastore() {
  return InMemoryDatastore<CompositeData>([itemRecordType].toSet());
}

InMemoryDatastore<CompositeData> initItemRecordSet() {
  Map<String, dynamic> jsonData = convert.json.decode(hackerNewsRaw);
  List<dynamic> jsonItems = jsonData['items'];
  List<UserCompositeValue> itemRecords = [];
  for (int i = 0; i < jsonItems.length && i < MAX_ITEMS; ++i) {
    UserCompositeValue value = parseHackerNewsItem(jsonItems[i] as Map);
    // TODO: this is for demo purposes only.
    if (i % 3 == 0) {
      value.field(UNREAD_FIELD).value = false;
    }
    itemRecords.add(value);
  }

  InMemoryDatastore<CompositeData> datastore = newDatastore();
  datastore.addAll(itemRecords, datastore.version);
  return datastore;
}

UserCompositeType makeItemRecordType() {
  UserCompositeType type = UserCompositeType(HACKER_NEWS_NAMESPACE, 'item_record');

  type.fields.add(FieldInfo(FROM_FIELD, STRING_DATATYPE));
  type.fields.add(FieldInfo(TITLE_FIELD, STRING_DATATYPE));
  type.fields.add(FieldInfo(URL_FIELD, STRING_DATATYPE));
  type.fields.add(FieldInfo(UNREAD_FIELD, BOOLEAN_DATATYPE));

  return type;
}

UserCompositeValue parseHackerNewsItem(Map<String, dynamic> itemJson) {
  int id = itemJson['id'] as int;
  String from = itemJson['by'] as String;
  String title = itemJson['title'] as String;
  // TODO: reenable URLs
  // String url = itemJson['url'] as String;
  String url = '';
  bool unread = true;

  DataId dataId = TaggedDataId.fromInt(HACKER_NEWS_NAMESPACE, id);

  UserCompositeValue value = itemRecordType.newInstance(dataId);
  value.field(FROM_FIELD).value = from;
  value.field(TITLE_FIELD).value = title;
  value.field(URL_FIELD).value = url;
  value.field(UNREAD_FIELD).value = unread;

  return value;
}
