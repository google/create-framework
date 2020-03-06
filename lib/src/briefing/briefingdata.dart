// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';

const Namespace BRIEFING_NAMESPACE = const Namespace('Briefing App', 'briefing');

enum AddressCategory { Person, Group, Source }

class Address extends BaseCompositeData {
  final DataId dataId;
  final Ref<String> email;
  final Ref<String> name;
  final Ref<String> shortName;
  final Ref<bool> isExplicitName;
  ReadRef<String> _contextDisplayName;
  AddressCategory _category;

  Address(this.dataId, String email, String name, String shortName, bool isExplicitName,
      [String contextDisplayName, this._category])
      : email = Boxed<String>(email),
        name = Boxed<String>(name),
        shortName = Boxed<String>(shortName),
        isExplicitName = Boxed<bool>(isExplicitName),
        _contextDisplayName =
            contextDisplayName != null ? Constant<String>(contextDisplayName) : null;

  AddressType get dataType => ADDRESS_DATATYPE;

  AddressCategory get category {
    if (_category == null) {
      if (email.value == null) {
        _category = AddressCategory.Person;
      } else {
        int at = email.value.indexOf('@');
        String account = at > 0 ? email.value.substring(0, at) : email.value;
        if (account.indexOf('-') >= 0 || _groupsWithNoDashes.contains(account)) {
          _category = AddressCategory.Group;
        } else {
          _category = AddressCategory.Person;
        }
      }
    }

    return _category;
  }

  ReadRef<String> _computeContextDisplayName() {
    if (category == AddressCategory.Group && email.value != null) {
      int at = email.value.indexOf('@');
      if (at > 0) {
        return Constant<String>(email.value.substring(0, at + 1));
      }
    }

    return name;
  }

  ReadRef<String> get contextDisplayName {
    if (_contextDisplayName == null) {
      _contextDisplayName = _computeContextDisplayName();
    }
    return _contextDisplayName;
  }

  void visit(FieldVisitor visitor) {
    // TODO: implement visitor
  }

  String toString() =>
      '$dataId: ${name.value} (${shortName.value}) <${email.value}>, e:${isExplicitName.value}';

  bool operator ==(o) => o is Address && dataId == o.dataId;
  int get hashCode => dataId.hashCode + 68;
}

class AddressType extends CompositeDataType {
  const AddressType() : super(BRIEFING_NAMESPACE, 'address');

  Address newInstance(DataId dataId) => Address(dataId, null, null, null, null);
}

const AddressType ADDRESS_DATATYPE = const AddressType();

Set<String> _groupsWithNoDashes = Set<String>.from([
  // SCRUBBED
]);

const String FROM_FIELD = 'from';
const String DESCENDANTS_FIELD = 'descendants';
const String SCORE_FIELD = 'score';
const String TIME_FIELD = 'time';
const String TITLE_FIELD = 'title';
const String URL_FIELD = 'url';
const String UNREAD_FIELD = 'unread';
const String ADDRESSES_FIELD = 'addresses';

class ItemRecordType extends CompositeDataType {
  const ItemRecordType() : super(BRIEFING_NAMESPACE, 'item_record');

  ItemRecord newInstance(DataId dataId) =>
      ItemRecord(dataId, null, null, null, null, null, null, null, BaseMutableList<Address>());
}

const ItemRecordType ITEM_RECORD_DATATYPE = const ItemRecordType();

class ItemRecord extends BaseCompositeData {
  final DataId dataId;
  final Ref<String> from;
  final Ref<int> descendants;
  final Ref<int> score;
  final Ref<int> time;
  final Ref<String> title;
  final Ref<String> url;
  final Ref<bool> unread;
  final MutableList<Address> addresses;

  ItemRecord(this.dataId, String from, int descendants, int score, int time, String title,
      String url, bool unread, this.addresses)
      : from = Boxed<String>(from),
        descendants = Boxed<int>(descendants),
        score = Boxed<int>(score),
        time = Boxed<int>(time),
        title = Boxed<String>(title),
        url = Boxed<String>(url),
        unread = Boxed<bool>(unread);

  ItemRecordType get dataType => ITEM_RECORD_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.stringField(FROM_FIELD, from);
    visitor.intField(DESCENDANTS_FIELD, descendants);
    visitor.intField(SCORE_FIELD, score);
    visitor.intField(TIME_FIELD, time);
    visitor.stringField(TITLE_FIELD, title);
    visitor.stringField(URL_FIELD, url);
    visitor.boolField(UNREAD_FIELD, unread);
    visitor.listField(ADDRESSES_FIELD, addresses, ADDRESS_DATATYPE);
  }

  String toString() => dataId.toString();
}

bool isEmptyString(String s) {
  return s == null || s.isEmpty;
}

String normalizeSearchQuery(String query) {
  return query != null ? query.trim().toLowerCase() : '';
}

String normalizeEmail(String email) {
  return email.trim().toLowerCase();
}

class ItemQuery extends QueryType<CompositeData> {
  final String query;
  final bool isUnread;

  ItemQuery(String query, this.isUnread) : query = normalizeSearchQuery(query);

  @override
  bool matches(CompositeData data) {
    if (data is! ItemRecord) {
      return false;
    }

    ItemRecord item = data as ItemRecord;

    if (isUnread && item.unread.value == false) {
      return false;
    }

    // TODO: more query rewriting, or support for custom categories.
    String q = query.startsWith(HASH_PREFIX) ? query.substring(HASH_PREFIX.length) : query;

    if (item.title.value != null && normalizeSearchQuery(item.title.value).contains(q)) {
      return true;
    }
    if (item.url.value != null && normalizeSearchQuery(item.url.value).contains(q)) {
      return true;
    }

    return false;
  }

  @override
  void observe(CompositeData item, Operation observer, Lifespan lifespan) {
    if (item is ItemRecord && isUnread) {
      item.unread.observeRef(observer, lifespan);
    }
  }

  String toString() => isUnread ? '[$query /unread]' : '[$query]';

  bool operator ==(o) => o is ItemQuery && query == o.query && isUnread == o.isUnread;
  int get hashCode => query.hashCode + (isUnread ? 42 : 68);
}

class ContextQuery extends QueryType<CompositeData> {
  final ItemQuery itemQuery;
  final AddressCategory category;

  ContextQuery(this.itemQuery, this.category);

  @override
  bool matches(CompositeData data) {
    // TODO: implement
    return false;
  }

  String toString() => 'Context of $itemQuery/$category';

  bool operator ==(o) => o is ContextQuery && itemQuery == o.itemQuery && category == o.category;
  int get hashCode => itemQuery.hashCode + category.hashCode + 68;
}

class Category {
  String id;
  String name;
  String description;

  Category(this.id, this.name, [this.description]);

  String get toQuery => id.isEmpty ? "" : HASH_PREFIX + id;
}

List<Category> categories = <Category>[
  Category("", "Inbox", ""),
  Category("byme", "By me", "by you"),
  Category("starred", "Starred", "starred"),
  Category("important", "Important", "you don't want to miss"),
  Category("personal", "Personal", "referencing you"),
  // SCRUBBED
];

// TODO: store categories in datastore
List<Category> genericCategories = <Category>[
  Category("", "All Items"),
  // SCRUBBED
];
