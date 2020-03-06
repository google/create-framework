// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../views.dart';

class PaintData extends BaseCompositeData {
  final DataId dataId;
  final MutableList<Point> points;

  PaintData(this.dataId, List<Point> points, [VersionId version = VERSION_ZERO])
      : points = BaseMutableList<Point>(points) {
    this.version = version;
  }

  PaintDataType get dataType => PAINT_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.listField(POINTS_FIELD, points, POINT_DATATYPE);
  }

  String toString() => 'Version $version ${points.size.value} points';
}

const String POINTS_FIELD = 'points';

class PaintApp extends BaseZone {
  final PaintData data;
  ApplicationView view;

  PaintApp(this.data) : super(null, 'paintapp') {
    mainViewPadding = true;
    View canvasView = CanvasView(Constant<ReadList<Point>>(data.points));
    View mainView = GestureActionView(Constant<View>(canvasView), gestureHandler);
    view = ApplicationView(Constant<View>(mainView), Constant<String>('Paint'),
        buttonIcon: Constant<IconId>(CLEAR_ICON),
        buttonOperation: Constant<Operation>(makeOperation(clear)));
  }

  void gestureHandler(GestureActionType type, Point point) {
    switch (type) {
      case GestureActionType.dragStart:
      case GestureActionType.dragUpdate:
        data.points.add(point);
        break;
      case GestureActionType.dragEnd:
        List<Point> points = data.points.elements;
        if (points.isNotEmpty && points.last != null) {
          data.points.add(null);
        }
        break;
    }
  }

  void clear() {
    data.points.clear();
  }
}

const Namespace PAINT_NAMESPACE = const Namespace('Paint', 'paint');

class PaintDataType extends CompositeDataType {
  const PaintDataType() : super(PAINT_NAMESPACE, 'paint_data');

  PaintData newInstance(DataId dataId) => PaintData(dataId, null);
}

const PaintDataType PAINT_DATATYPE = const PaintDataType();
