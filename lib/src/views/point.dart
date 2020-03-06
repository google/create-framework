// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

import 'styles.dart';

const X_FIELD = 'x';
const Y_FIELD = 'y';

class Point extends ImmutableCompositeData {
  final DataId dataId;
  final WriteOnce<double> x;
  final WriteOnce<double> y;

  Point(double x, double y)
      : dataId = styleIdSource.nextId(),
        x = WriteOnce<double>(x),
        y = WriteOnce<double>(y);

  Point.uninitialized([DataId dataId])
      : dataId = dataId != null ? dataId : styleIdSource.nextId(),
        x = WriteOnce<double>(),
        y = WriteOnce<double>();

  PointDataType get dataType => POINT_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.doubleField(X_FIELD, x);
    visitor.doubleField(Y_FIELD, y);
  }

  @override
  int get hashCode => x.value.hashCode * 31 + y.value.hashCode;

  @override
  bool operator ==(dynamic o) => o is Point && o.x.value == x.value && o.y.value == y.value;
}

class PointDataType extends ImmutableCompositeDataType {
  const PointDataType() : super(STYLES_NAMESPACE, 'point');

  @override
  Point newInstance(DataId dataId) => Point.uninitialized(dataId);
}

const PointDataType POINT_DATATYPE = const PointDataType();
