// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import '../../elements.dart';

import 'base.dart';

class InMemoryDatastore<R extends CompositeData> extends BaseZone implements Datastore<R> {
  final Set<DataType> dataTypes = Set<DataType>();
  final List<R> _records = new List<R>();
  final Map<DataId, R> _recordsById = new HashMap<DataId, R>();
  final Set<_LiveQuery> _liveQueries = new Set<_LiveQuery>();
  final ObserverManager _stateObsevers = ObserverManager();
  VersionId _version = VERSION_ZERO;
  bool _bulkUpdateInProgress = false;
  _RecursiveAdder<R> _adder;
  Operation _stateUpdated;

  InMemoryDatastore(Iterable<DataType> dataTypeSet) : super(null, 'datastore') {
    dataTypes.addAll(dataTypeSet);
    _adder = new _RecursiveAdder<R>(this);
    _stateUpdated = makeOperation(_updated);
  }

  bool hasRecord(DataId dataId) {
    return _recordsById.containsKey(dataId);
  }

  /// Retrieve a record by id
  R lookupById(DataId dataId) {
    return _recordsById[dataId];
  }

  /// Run a query and get a list of matching results back.
  /// If lifespan is not null, then the query is 'live' and result list gets updated
  /// to reflect new records added to the datastore.  When the lifespan is disposed,
  /// updates stop.
  /// If the lifespan is null, a "snapshot" of the results is returned as an immutable list.
  @override
  ReadList<R> runQuery(QueryType<R> query, Lifespan lifespan, Priority priority) {
    bool matchWithDependencies(R record) => query.includeDependencies
        ? query.matches(record)
        : !record.dependency && query.matches(record);

    List<R> results = new List<R>.from(_records.where(matchWithDependencies));

    if (lifespan != null) {
      final _LiveQuery<R> liveQuery = new _LiveQuery<R>(query, lifespan, this, results);
      for (R record in _records) {
        liveQuery.observe(record);
      }
      lifespan.addResource(liveQuery);
      _liveQueries.add(liveQuery);
      print('Datastore: query added; ${_liveQueries.length} active queries.');
      return liveQuery._result;
    } else {
      return new ImmutableList<R>(results);
    }
  }

  @override
  ReadRef<int> count(QueryType<R> query, Lifespan lifespan, Priority priority) {
    // TODO: optimize
    return runQuery(query, lifespan, priority).size;
  }

  @override
  ImmutableList<R> runQuerySync(QueryType<R> query) =>
      runQuery(query, null, Priority.HIGHEST) as ImmutableList<R>;

  VersionId get version => _version;

  int get size => _recordsById.length;

  bool _isKnownType(DataType type) {
    return dataTypes.contains(type);
  }

  /// For use by clients that know what they are doing.
  /// Must not mutate the result object, and must process it right away.
  Iterable<R> get entireDatastoreState => _records;

  void startBulkUpdate(VersionId version) {
    // TODO: investigate when this assertion fails.
    //assert(!_bulkUpdateInProgress);
    _version = version;
    _bulkUpdateInProgress = true;
  }

  VersionId advanceVersion() {
    if (!_bulkUpdateInProgress) {
      _version = _version.nextVersion();
    }
    return _version;
  }

  void stopBulkUpdate() {
    assert(_bulkUpdateInProgress);
    Operation stop = makeOperation(() => _bulkUpdateInProgress = false, 'stopBulkUpdate');
    // Schedule stopping bulk update after all observers run
    stop.scheduleObserver();
  }

  void _doAdd(R record) {
    assert(_isKnownType(record.dataType));
    if (_recordsById.containsKey(record.dataId)) {
      print('Duplicate $record');
    }
    assert(!_recordsById.containsKey(record.dataId));

    record.version = advanceVersion();
    // On state change, we advance the version on both the record and the datastore
    Operation bumpVersion = makeOperation(() {
      record.version = advanceVersion();
      _stateUpdated.scheduleObserver();
    }, 'bumpVersion');

    record.observe(bumpVersion, this);
    _records.add(record);
    _recordsById[record.dataId] = record;
    _liveQueries.forEach((q) => q.newRecordAdded(record));
  }

  @override
  void add(R record) {
    _doAdd(record);
    _adder.addDependencies(record);
  }

  void addAll(List<R> records, VersionId version) {
    startBulkUpdate(version);

    records.forEach((record) => _doAdd(record));
    int beforeDepsSize = size;

    records.forEach(_adder.addDependencies);

    print('Datastore: added all records, now at $size, $beforeDepsSize before dependencies');
    stopBulkUpdate();
  }

  void observeState(Operation observer, Lifespan lifespan) {
    _stateObsevers.observe(observer, lifespan);
  }

  void _updated() {
    _stateObsevers.triggerObservers();
  }

  void _unregister(_LiveQuery liveQuery) {
    _liveQueries.remove(liveQuery);
    print('Datastore: query removed; ${_liveQueries.length} active queries.');
  }

  String get describe => 'Version $_version, ${_records.length} records';

  void dump() {
    print('Datastore: $describe');
    for (int i = 0; i < _records.length; ++i) {
      CompositeData record = _records[i];
      print('Element: $record ${record.runtimeType} t:${record.dataType}');
    }
  }
}

class _LiveQuery<R extends CompositeData> implements Disposable {
  MutableList<R> _result;
  Operation _refresh;
  final QueryType<R> _query;
  final Lifespan _lifespan;
  final InMemoryDatastore<R> _datastore;

  _LiveQuery(this._query, this._lifespan, this._datastore, List<R> firstResults) {
    _result = new BaseMutableList<R>(firstResults);
    _refresh = _datastore.makeOperation(refresh);
  }

  bool matchWithDependencies(R record) {
    return _query.includeDependencies
        ? _query.matches(record)
        : !record.dependency && _query.matches(record);
  }

  void refresh() {
    List<R> newResults = List<R>.from(_datastore._records.where(matchWithDependencies));
    _result.replaceWith(newResults);
  }

  void observe(R record) {
    _query.observe(record, _refresh, _lifespan);
  }

  void newRecordAdded(R record) {
    if (_query.matches(record)) {
      _result.add(record); // This will trigger observers
    }
    observe(record);
  }

  void dispose() {
    _datastore._unregister(this);
  }
}

class _RecursiveAdder<R extends CompositeData> implements FieldVisitor {
  final InMemoryDatastore<R> _datastore;

  _RecursiveAdder(this._datastore);

  void addDependencies(R record) {
    record.visit(this);
  }

  void processDependency(Object data) {
    if (data == null || data is! CompositeData) {
      return;
    }

    R record = data as R;

    if (_datastore.hasRecord(record.dataId)) {
      return;
    }

    record.dependency = true;
    _datastore.add(record);
    addDependencies(record);
  }

  void boolField(String fieldName, Ref<bool> field) => null;
  void intField(String fieldName, Ref<int> field) => null;
  void stringField(String fieldName, Ref<String> field) => null;
  void doubleField(String fieldName, Ref<double> field) => null;

  void dataField(String fieldName, Ref<Data> field, DataType dataType) {
    processDependency(field.value);
  }

  void listField(String fieldName, MutableList<Object> field, DataType elementType) {
    field.elements.forEach(processDependency);
  }
}
