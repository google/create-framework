// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/gmail/v1.dart';

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import 'address.dart';
import 'briefingdata.dart';
import 'priorities.dart';

const List<String> _SCOPES = [GmailApi.GmailReadonlyScope];

const _FROM_HEADER = 'From';
const _TO_HEADER = 'To';
const _CC_HEADER = 'Cc';
const _SUBJECT_HEADER = 'Subject';
const _DATE_HEADER = 'Date';

const List<String> _METADATA_HEADERS = [
  _FROM_HEADER,
  _TO_HEADER,
  _CC_HEADER,
  _SUBJECT_HEADER,
  _DATE_HEADER
];

const List<String> _ADDRESS_HEADERS = [_FROM_HEADER, _TO_HEADER, _CC_HEADER];

class GmailClient extends Datastore<CompositeData> {
  final ClientId _clientId;
  AuthClient _client;
  GmailApi _api;
  final Zone defaultZone = BaseZone(null, 'gmail_client');
  final DataIdSource _idSource = SequentialIdSource(BRIEFING_NAMESPACE);
  final RequestThrotller throttler = RequestThrotller(MAX_CONCURRENT_REQUESTS, LOG_REQUESTS);
  final Ref<String> _myEmail = Boxed<String>(null);
  AddressHandler _addresses;
  Map<DataId, ItemRecord> _items = LinkedHashMap<DataId, ItemRecord>();
  Map<ItemQuery, ReadList<ItemRecord>> queryCache =
      LinkedHashMap<ItemQuery, ReadList<ItemRecord>>();
  Set<DataId> _threadsLoaded = Set<DataId>();
  Map<String, String> _rewriteRules = Map<String, String>();

  GmailClient(this._clientId) {
    _addresses = AddressHandler(_myEmail, _idSource);
  }

  Set<DataType> get dataTypes => Set<DataType>.of([ITEM_RECORD_DATATYPE]);

  ItemRecord _getOrCreateItem(DataId threadId, bool isUnread, bool getThread, Lifespan lifespan) {
    ItemRecord record = _items[threadId];

    if (record == null) {
      record = ItemRecord(threadId, '', 0, 0, 0, '', '', isUnread, BaseMutableList<Address>());
      _items[threadId] = record;
    } else if (isUnread) {
      record.unread.value = true;
    }

    if (getThread && !_threadsLoaded.contains(record.dataId)) {
      _threadsLoaded.add(record.dataId);
      _scheduleRequest(
          (Operation done) => _threadsGet(record, done), null, defaultZone, METADATA_PRIORITY);
    }

    return record;
  }

  Zone _zoneOf(Lifespan lifespan) {
    return lifespan != null ? lifespan.zone : defaultZone;
  }

  // TODO: this is currently not used, as we do not render snippets.
  String stripMarkupFromSnippet(String snippet) {
    return snippet
        .replaceAll('<b>', '')
        .replaceAll('</b>', '')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&#39;', '\'')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
  }

  void _initRewriteRules() {
    _rewriteRules["inbox"] = "";
    _rewriteRules["byme"] = "from:" + _myEmail.value;
    _rewriteRules["starred"] = "is:starred";
    _rewriteRules["important"] = "is:important";
    _rewriteRules["personal"] = _myEmail.value;
  }

  @override
  ReadList<CompositeData> runQuery(
      QueryType<CompositeData> query, Lifespan lifespan, Priority priority) {
    if (query is ItemQuery) {
      return runItemQuery(query, lifespan, priority);
    } else if (query is ContextQuery) {
      return runContextQuery(query, lifespan, priority);
    } else {
      throw UnimplementedError('Unknown query $query');
    }
  }

  ReadList<ItemRecord> runItemQuery(ItemQuery itemQuery, Lifespan lifespan, Priority priority) {
    ReadList<ItemRecord> cachedQuery = queryCache[itemQuery];
    if (cachedQuery != null) {
      return cachedQuery;
    }

    MutableList<ItemRecord> result = BaseMutableList<ItemRecord>();
    queryCache[itemQuery] = result;

    void _startQuery() {
      List<Thread> threads = [];
      void _threadsListDone() {
        List<ItemRecord> itemList = [];
        for (Thread thread in threads) {
          ItemRecord itemRecord =
              _getOrCreateItem(_fromGmailId(thread.id), itemQuery.isUnread, true, lifespan);
          itemList.add(itemRecord);
        }
        result.addAll(itemList);
      }

      _scheduleRequest((Operation done) => _threadsList(MAX_ITEMS, itemQuery, threads, done),
          _zoneOf(lifespan).makeOperation(_threadsListDone), lifespan, priority);
    }

    if (_isReady) {
      _startQuery();
    } else {
      _myEmail.observeRef(_zoneOf(lifespan).makeOperation(_startQuery), lifespan);
    }

    return result;
  }

  ReadList<Address> runContextQuery(
      ContextQuery contextQuery, Lifespan lifespan, Priority priority) {
    MutableList<Address> result = BaseMutableList<Address>();
    ReadList<ItemRecord> items = runItemQuery(contextQuery.itemQuery, lifespan, priority);

    Operation updateOp;

    void updateResult() {
      if (items.size.value == 0) {
        result.clear();
      } else {
        result.replaceWith(_getTopAddresses(items, contextQuery.category, updateOp, lifespan));
      }
    }

    updateOp = _zoneOf(lifespan).makeOperation(updateResult);
    updateResult();
    items.observe(updateOp, lifespan);

    return result;
  }

  List<Address> _getTopAddresses(
      ReadList<ItemRecord> items, AddressCategory category, Operation updateOp, Lifespan lifespan) {
    Map<Address, _AddressPopularity> popularityMap = HashMap<Address, _AddressPopularity>();
    for (ItemRecord item in items.elements) {
      ReadList<Address> addresses = item.addresses;
      addresses.observe(updateOp, lifespan);
      for (Address address in addresses.elements) {
        if (address.category != category || address.email.value == _myEmail.value) {
          continue;
        }

        _AddressPopularity popularity = popularityMap[address];
        if (popularity != null) {
          popularity.count += 1;
        } else {
          popularityMap[address] = _AddressPopularity(address);
        }
      }
    }

    Set<_AddressPopularity> popularitySet = SplayTreeSet<_AddressPopularity>();
    popularitySet.addAll(popularityMap.values);

    return List<Address>.from(
        popularitySet.take(MAX_CONTEXT_ITEMS).map((_AddressPopularity ap) => ap.address));
  }

  DataId _fromGmailId(String gmailId) {
    return TaggedDataId(BRIEFING_NAMESPACE, gmailId);
  }

  String _toGmailId(DataId dataId) {
    return (dataId as TaggedDataId).stripNamespace;
  }

  String toGmailQuery(QueryType<ItemRecord> query) {
    if (query is! ItemQuery) {
      throw new StateError("ItemQuery expected in GmailClient");
    }

    ItemQuery itemQuery = query as ItemQuery;
    if (itemQuery.isUnread) {
      return '{itemQuery.query} is:unread';
    } else {
      return itemQuery.query;
    }
  }

  @override
  ReadRef<int> count(QueryType<CompositeData> query, Lifespan lifespan, Priority priority) {
    Ref<int> count = Boxed<int>(0);
    List<ItemRecord> items = [];

    void _updateCount() {
      int c = 0;
      for (ItemRecord record in items) {
        if (record.unread.value == true) {
          ++c;
        }
      }

      count.value = c;
    }

    void _startQuery() {
      ItemQuery itemQuery = query as ItemQuery;
      List<Thread> threads = [];
      void _threadsListDone() {
        Operation updateCount = _zoneOf(lifespan).makeOperation(_updateCount, 'updateCount');
        for (Thread thread in threads) {
          ItemRecord itemRecord =
              _getOrCreateItem(_fromGmailId(thread.id), itemQuery.isUnread, false, lifespan);
          items.add(itemRecord);
          if (itemQuery.isUnread) {
            itemRecord.unread.observeRef(updateCount, lifespan);
          }
        }
        _updateCount();
      }

      _scheduleRequest((Operation done) => _threadsList(MAX_ITEMS, itemQuery, threads, done),
          _zoneOf(lifespan).makeOperation(_threadsListDone), lifespan, priority);
    }

    if (_isReady) {
      _startQuery();
    } else {
      _myEmail.observeRef(_zoneOf(lifespan).makeOperation(_startQuery), lifespan);
    }

    return count;
  }

  @override
  void add(CompositeData record) {
    throw new UnimplementedError("Can't add records in GmailClient");
  }

  @override
  ImmutableList<ItemRecord> runQuerySync(QueryType<CompositeData> query) {
    // TODO: make a best effort to execute a query
    throw new UnimplementedError("runQuerySync() is not supported by GmailClient");
  }

  void start() {
    clientViaUserConsent(_clientId, _SCOPES, _userPrompt).then((AuthClient client) {
      _client = client;
      _api = GmailApi(client);
      _scheduleRequest(_usersGetProfile, null, null, Priority.HIGHEST);
    }).catchError((error) {
      if (error is UserConsentException) {
        print("You did not grant access :(");
      } else {
        print("An unknown error occured: $error");
      }
    });
  }

  void _scheduleRequest(
      void Function(Operation) start, Operation onDone, Lifespan lifespan, Priority priority) {
    throttler.schedule(start, onDone, _zoneOf(lifespan), priority);
  }

  void _usersGetProfile(Operation done) {
    _api.users.getProfile('me').then((Profile profile) {
      _myEmail.value = normalizeEmail(profile.emailAddress);
      print('Welcome, ${_myEmail.value}!');
      _initRewriteRules();
      done.scheduleAction();
    });
  }

  bool get _isReady => _myEmail.value != null;

  String _rewriteQuery(ItemQuery itemQuery) {
    String query = itemQuery.query;

    if (query.startsWith(HASH_PREFIX)) {
      query = query.substring(HASH_PREFIX.length);
      int index = query.indexOf(' ');
      if (index < 0) {
        index = query.length;
      }
      // TODO: rewrite terms that are not first
      String rewritten = _rewriteRules[query.substring(0, index)];
      if (rewritten != null) {
        query = rewritten + query.substring(index);
      }
    }

    return query;
  }

  void _threadsList(int max, ItemQuery itemQuery, List<Thread> threads, Operation done) {
    String gmailQuery = _rewriteQuery(itemQuery);
    List<String> labelIds = itemQuery.isUnread ? ['UNREAD'] : null;
    threads.clear();

    void next(String token) {
      _api.users.threads
          .list(_myEmail.value,
              q: gmailQuery, labelIds: labelIds, pageToken: token, maxResults: max)
          .then((ListThreadsResponse results) {
        if (results.threads != null && results.threads.isNotEmpty) {
          threads.addAll(results.threads);
          // If we would like to have more documents, we iterate.
          if (threads.length < max && results.nextPageToken != null) {
            next(results.nextPageToken);
            return;
          }
        }
        done.scheduleAction();
      }).catchError((error) {
        print('An error occured: $error');
        throw error;
      });
    }

    next(null);
  }

  void _threadsGet(ItemRecord record, Operation done) {
    String id = _toGmailId(record.dataId);
    _api.users.threads
        .get(_myEmail.value, id, format: 'metadata', metadataHeaders: _METADATA_HEADERS)
        .then((Thread thread) {
      _addresses.prepareAddresses(thread.messages, _ADDRESS_HEADERS);
      record.from.value = _buildFrom(thread.messages);
      record.title.value = _getSubject(thread.messages[0]);
      record.addresses.replaceWith(_addresses.parseAddresses(thread.messages, _ADDRESS_HEADERS));
      done.scheduleAction();
    });
  }

  String _getSubject(Message message) {
    List<MessagePartHeader> headers = message.payload.headers;
    for (MessagePartHeader header in headers) {
      if (header.name == 'Subject') {
        return header.value;
      }
    }

    return '[no subject]';
  }

  String _buildFrom(List<Message> messages) {
    List<Address> addresses = _addresses.parseAddresses(messages, <String>[_FROM_HEADER]);

    switch (addresses.length) {
      case 0:
        return '[from]';

      case 1:
        return addresses[0].name.value;

      case 2:
        return addresses[0].shortName.value + ', ' + addresses[1].shortName.value;

      default:
        return addresses[0].shortName.value +
            ' .. ' +
            addresses[addresses.length - 1].shortName.value +
            ' (' +
            addresses.length.toString() +
            ')';
    }
  }

  void close() {
    _client.close();
  }

  void _userPrompt(String url) {
    print("Please go to the following URL and grant access:");
    print("  => $url");
    print("");
  }
}

class _AddressPopularity implements Comparable {
  final Address address;
  int count = 1;

  _AddressPopularity(this.address);

  String toString() => '$address ($count)';

  int compareTo(dynamic otherObject) {
    _AddressPopularity other = otherObject as _AddressPopularity;
    int result = other.count - this.count;
    if (result != 0) {
      return result;
    } else if (address.email.value != null && other.address.email.value != null) {
      return address.email.value.compareTo(other.address.email.value);
    } else {
      return address.name.value.compareTo(other.address.name.value);
    }
  }
}

ClientId readId() {
  File file = File('/Users/dynin/.oauth');
  String content = file.readAsStringSync();
  List<String> lines = content.split('\n');
  String clientId = lines[0].trim();
  String clientSecret = lines[1].trim();
  return ClientId(clientId, clientSecret);
}
