// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

abstract class QueryType<R> {
  bool matches(R data);
  void observe(R record, Operation observer, Lifespan lifespan) => null;
  bool get includeDependencies => false;
}

// All records, including dependencies
class StarQuery<R> extends QueryType<R> {
  @override
  bool matches(R data) => true;

  @override
  bool get includeDependencies => true;
}

class BaseQuery<R> extends QueryType<R> {
  final bool Function(R data) query;

  BaseQuery(this.query);

  @override
  bool matches(R data) => query(data);
}

class NamedQuery<R> extends QueryType<R> {
  final String name;

  NamedQuery(this.name);

  @override
  bool matches(R data) => data is Named && data.name == name;
  // TODO: observe Name field
}

abstract class Datastore<R extends CompositeData> {
  Set<DataType> get dataTypes;
  ReadList<R> runQuery(QueryType<R> query, Lifespan lifespan, Priority priority);
  ReadRef<int> count(QueryType<R> query, Lifespan lifespan, Priority priority);
  ImmutableList<R> runQuerySync(QueryType<R> query);
  void add(R record);
}
