// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import '../../elements.dart';
import '../../views.dart';

class SliderData extends BaseCompositeData {
  final DataId dataId;
  final Ref<double> state;

  SliderData(this.dataId, double state, [VersionId version = VERSION_ZERO])
      : state = Boxed<double>(state) {
    this.version = version;
  }

  SliderDataType get dataType => SLIDER_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.doubleField(STATE_FIELD, state);
  }

  String toString() => 'Version $version State ${state.value}';
}

class SliderApp extends BaseZone {
  final SliderData data;
  ApplicationView view;

  SliderApp(this.data) : super(null, 'sliderapp') {
    mainViewPadding = true;

    DataId styleId = TaggedDataId(SLIDER_NAMESPACE, 'column');
    FlexStyle columnStyle = FlexStyle(styleId, START_MAIN_AXIS, CENTER_CROSS_AXIS);

    View mainView = ColumnView(
        ImmutableList<View>([
          SliderInput(data.state),
          LabelView(describeState, Constant<Style>(BODY2_STYLE)),
          ButtonView(Constant<String>('Increase the value'), Constant<Style>(BUTTON_STYLE),
              Constant<Operation>(increaseValue)),
          ButtonView(Constant<String>('Decrease the value'), Constant<Style>(BUTTON_STYLE),
              Constant<Operation>(decreaseValue)),
          SliderInput(data.state),
        ]),
        Constant<Style>(columnStyle));
    view = ApplicationView(Constant<View>(mainView), Constant<String>('Data!'));
  }

  ReadRef<String> get describeState => ReactiveFunction<double, String>(
      data.state, (double stateValue) => 'The value is $stateValue', this);

  Operation get increaseValue => makeOperation(() {
        data.state.value = math.min(data.state.value + 0.1, 1.0);
      });

  Operation get decreaseValue => makeOperation(() {
        data.state.value = math.max(data.state.value - 0.1, 0.0);
      });
}

const Namespace SLIDER_NAMESPACE = const Namespace('Slider', 'slider');

const String STATE_FIELD = 'state';

class SliderDataType extends CompositeDataType {
  const SliderDataType() : super(SLIDER_NAMESPACE, 'slider_data');

  SliderData newInstance(DataId dataId) => SliderData(dataId, null);
}

const SliderDataType SLIDER_DATATYPE = const SliderDataType();
