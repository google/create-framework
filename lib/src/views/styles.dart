// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

const Namespace STYLES_NAMESPACE = const Namespace('Styles', 'styles');

DataIdSource styleIdSource = RandomIdSource(STYLES_NAMESPACE);

abstract class Style implements Data, Observable {}

const DataType STYLE_DATATYPE = const BuiltinDataType('style');

abstract class FontColorStyle implements Style {
  double get styleFontSize;
  NamedColor get styleColor;
}

// If you add elements here, you need to update flutterstyles
class ThemedStyleDataType extends EnumDataType {
  const ThemedStyleDataType() : super(STYLES_NAMESPACE, 'themed_style');

  List<ThemedStyle> get values =>
      [HEADLINE6_STYLE, SUBTITLE1_STYLE, BODY1_STYLE, BODY2_STYLE, CAPTION_STYLE, BUTTON_STYLE];
}

const ThemedStyleDataType THEMED_STYLE_DATATYPE = const ThemedStyleDataType();

class ThemedStyle extends EnumData implements Style {
  const ThemedStyle(String name) : super(name);

  EnumDataType get dataType => THEMED_STYLE_DATATYPE;
}

// When adding themes here, update flutterstyles.dart
const ThemedStyle HEADLINE6_STYLE = const ThemedStyle("Headline6");
const ThemedStyle SUBTITLE1_STYLE = const ThemedStyle("Subtitle1");
const ThemedStyle BODY1_STYLE = const ThemedStyle("Body1");
const ThemedStyle BODY2_STYLE = const ThemedStyle("Body2");
const ThemedStyle CAPTION_STYLE = const ThemedStyle("Caption");
const ThemedStyle BUTTON_STYLE = const ThemedStyle("Button");

class NamedColorDataType extends EnumDataType {
  const NamedColorDataType() : super(STYLES_NAMESPACE, 'named_color');

  List<NamedColor> get values => [
        BLACK_COLOR,
        WHITE_COLOR,
        RED_COLOR,
        GREEN_COLOR,
        BLUE_COLOR,
        LIGHT_TEAL_COLOR,
        LIGHT_GREY_COLOR,
        LIGHT_BLUE_COLOR
      ];
}

const NamedColorDataType NAMED_COLOR_DATATYPE = const NamedColorDataType();

class NamedColor extends EnumData {
  const NamedColor(String name) : super(name);

  EnumDataType get dataType => NAMED_COLOR_DATATYPE;
}

// When adding colors here, update flutterstyles.dart
const NamedColor BLACK_COLOR = const NamedColor('Black');
const NamedColor WHITE_COLOR = const NamedColor('White');
const NamedColor RED_COLOR = const NamedColor('Red');
const NamedColor GREEN_COLOR = const NamedColor('Green');
const NamedColor BLUE_COLOR = const NamedColor('Blue');
const NamedColor LIGHT_TEAL_COLOR = const NamedColor('Light Teal');
const NamedColor LIGHT_GREY_COLOR = const NamedColor('Light Grey');
const NamedColor LIGHT_BLUE_COLOR = const NamedColor('Light Blue');

const String FONT_SIZE_FIELD = 'font_size';
const String COLOR_FIELD = 'color';

class FontStyleType extends CompositeDataType {
  const FontStyleType() : super(STYLES_NAMESPACE, 'font_style');

  FontStyle newInstance(DataId dataId) => FontStyle(dataId, null, null);
}

const FontStyleType FONT_STYLE_DATATYPE = const FontStyleType();

class FontStyle extends BaseCompositeData implements FontColorStyle {
  final DataId dataId;
  final Ref<double> fontSize;
  final Ref<NamedColor> color;

  FontStyle(this.dataId, double fontSize, NamedColor color)
      : fontSize = Boxed<double>(fontSize),
        color = Boxed<NamedColor>(color);

  FontStyleType get dataType => FONT_STYLE_DATATYPE;

  double get styleFontSize => fontSize.value;
  NamedColor get styleColor => color.value;

  void visit(FieldVisitor visitor) {
    visitor.doubleField(FONT_SIZE_FIELD, fontSize);
    visitor.dataField(COLOR_FIELD, color, NAMED_COLOR_DATATYPE);
  }
}

// Icons from the Material Design library
class IconId {
  final String id;

  const IconId(this.id);
}

// When adding icons here, update flutterstyles.dart
const IconId ADD_CIRCLE_ICON = const IconId('content/add_circle');
const IconId ADD_ICON = const IconId('content/add');
const IconId ARROW_BACK_ICON = const IconId('navigation/arrow_back');
const IconId ARROW_DROP_DOWN_ICON = const IconId('navigation/arrow_drop_down');
const IconId ARROW_FORWARD_ICON = const IconId('navigation/arrow_forward');
const IconId CLEAR_ICON = const IconId('content/clear');
const IconId CLOUD_ICON = const IconId('file/cloud');
const IconId CODE_ICON = const IconId('action/code');
const IconId CONTENT_COPY_ICON = const IconId('content/content_copy');
const IconId EXPOSURE_PLUS_1_ICON = const IconId('image/exposure_plus_1');
const IconId EXPOSURE_PLUS_2_ICON = const IconId('image/exposure_plus_2');
const IconId EXTENSION_ICON = const IconId('action/extension');
const IconId HELP_ICON = const IconId('action/help');
const IconId LAUNCH_ICON = const IconId('action/launch');
const IconId MENU_ICON = const IconId('navigation/menu');
const IconId MODE_EDIT_ICON = const IconId('editor/mode_edit');
const IconId MORE_VERT_ICON = const IconId('navigation/more_vert');
const IconId RADIO_BUTTON_CHECKED_ICON = const IconId('toggle/radio_button_checked');
const IconId RADIO_BUTTON_UNCHECKED_ICON = const IconId('toggle/radio_button_unchecked');
const IconId REMOVE_CIRCLE_ICON = const IconId('content/remove_circle');
const IconId SEARCH_ICON = const IconId('action/search');
const IconId SETTINGS_ICON = const IconId('action/settings');
const IconId SETTINGS_SYSTEM_DAYDREAM_ICON = const IconId('device/settings_system_daydream');
const IconId STYLE_ICON = const IconId('image/style');
const IconId VIEW_QUILT_ICON = const IconId('action/view_quilt');
const IconId VISIBILITY_ICON = const IconId('action/visibility');
const IconId WIDGETS_ICON = const IconId('device/widgets');

class MainAxisDataType extends EnumDataType {
  const MainAxisDataType() : super(STYLES_NAMESPACE, 'main_axis');

  List<MainAxis> get values => [
        START_MAIN_AXIS,
        END_MAIN_AXIS,
        SPACE_BETWEEN_MAIN_AXIS,
        SPACE_AROUND_MAIN_AXIS,
        SPACE_EVENLY_MAIN_AXIS
      ];
}

const MainAxisDataType MAIN_AXIS_DATATYPE = const MainAxisDataType();

class MainAxis extends EnumData implements Style {
  const MainAxis(String name) : super(name);

  MainAxisDataType get dataType => MAIN_AXIS_DATATYPE;
}

// When adding styles here, update flutterwidgets.dart
const MainAxis START_MAIN_AXIS = const MainAxis("start");
const MainAxis END_MAIN_AXIS = const MainAxis("end");
const MainAxis SPACE_BETWEEN_MAIN_AXIS = const MainAxis("space_between");
const MainAxis SPACE_AROUND_MAIN_AXIS = const MainAxis("space_around");
const MainAxis SPACE_EVENLY_MAIN_AXIS = const MainAxis("space_evenly");

class CrossAxisDataType extends EnumDataType {
  const CrossAxisDataType() : super(STYLES_NAMESPACE, 'cross_axis');

  List<CrossAxis> get values => [
        START_CROSS_AXIS,
        END_CROSS_AXIS,
        CENTER_CROSS_AXIS,
        STRETCH_CROSS_AXIS,
        BASELINE_CROSS_AXIS
      ];
}

const CrossAxisDataType CROSS_AXIS_DATATYPE = const CrossAxisDataType();

class CrossAxis extends EnumData implements Style {
  const CrossAxis(String name) : super(name);

  CrossAxisDataType get dataType => CROSS_AXIS_DATATYPE;
}

// When adding styles here, update flutterwidgets.dart
const CrossAxis START_CROSS_AXIS = const CrossAxis("start");
const CrossAxis END_CROSS_AXIS = const CrossAxis("end");
const CrossAxis CENTER_CROSS_AXIS = const CrossAxis("center");
const CrossAxis STRETCH_CROSS_AXIS = const CrossAxis("stretch");
const CrossAxis BASELINE_CROSS_AXIS = const CrossAxis("baseline");

class ExpandedStyleDataType extends EnumDataType {
  const ExpandedStyleDataType() : super(STYLES_NAMESPACE, 'expanded_style');

  List<ExpandedStyle> get values => [
        NONE_STYLE,
        EXPANDED_STYLE,
        FLEXIBLE_STYLE,
        SCROLL_AND_FLEX_STYLE,
        EXPANDED_LIST_VIEW_STYLE,
        DOUBLE_EXPANDED_LIST_VIEW_STYLE
      ];
}

const ExpandedStyleDataType EXPANDED_STYLE_DATATYPE = const ExpandedStyleDataType();

class ExpandedStyle extends EnumData implements Style {
  const ExpandedStyle(String name) : super(name);

  ExpandedStyleDataType get dataType => EXPANDED_STYLE_DATATYPE;
}

// When adding styles here, update flutterwidgets.dart
const ExpandedStyle NONE_STYLE = const ExpandedStyle("none");
const ExpandedStyle EXPANDED_STYLE = const ExpandedStyle("expanded");
const ExpandedStyle FLEXIBLE_STYLE = const ExpandedStyle("flexible");
const ExpandedStyle SCROLL_AND_FLEX_STYLE = const ExpandedStyle("scroll_and_flex");
const ExpandedStyle EXPANDED_LIST_VIEW_STYLE = const ExpandedStyle("expanded_list_view");
const ExpandedStyle DOUBLE_EXPANDED_LIST_VIEW_STYLE =
    const ExpandedStyle("double_expanded_list_view");

class FlexStyleType extends CompositeDataType {
  const FlexStyleType() : super(STYLES_NAMESPACE, 'flex_style');

  @override
  FlexStyle newInstance(DataId dataId) => FlexStyle.uninitialized(dataId);
}

const FlexStyleType FLEX_STYLE_DATATYPE = const FlexStyleType();

const String MAIN_AXIS_FIELD = 'main_axis';
const String CROSS_AXIS_FIELD = 'cross_axis';
const String HEIGHT_FIELD = 'height';
const String EXPANDED_FIELD = 'expanded';

// TODO(dynin): no longer immutable.
class FlexStyle extends BaseCompositeData implements Style {
  final DataId dataId;
  final Ref<MainAxis> mainAxisAlignment;
  final Ref<CrossAxis> crossAxisAlignment;
  final Ref<double> height;
  final Ref<NamedColor> color;
  final Ref<ExpandedStyle> expanded;

  FlexStyle(this.dataId, MainAxis mainAxisAlignment, CrossAxis crossAxisAlignment,
      {double height, NamedColor color, ExpandedStyle expanded})
      : mainAxisAlignment = Boxed<MainAxis>(mainAxisAlignment),
        crossAxisAlignment = Boxed<CrossAxis>(crossAxisAlignment),
        height = Boxed<double>(height),
        color = Boxed<NamedColor>(color),
        expanded = Boxed<ExpandedStyle>(expanded);

  FlexStyle.uninitialized(DataId dataId)
      : dataId = dataId != null ? dataId : styleIdSource.nextId(),
        mainAxisAlignment = Boxed<MainAxis>(null),
        crossAxisAlignment = Boxed<CrossAxis>(null),
        height = Boxed<double>(null),
        color = Boxed<NamedColor>(null),
        expanded = Boxed<ExpandedStyle>(null);

  FlexStyleType get dataType => FLEX_STYLE_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.dataField(MAIN_AXIS_FIELD, mainAxisAlignment, MAIN_AXIS_DATATYPE);
    visitor.dataField(CROSS_AXIS_FIELD, crossAxisAlignment, CROSS_AXIS_DATATYPE);
    visitor.doubleField(HEIGHT_FIELD, height);
    visitor.dataField(COLOR_FIELD, color, NAMED_COLOR_DATATYPE);
    visitor.dataField(EXPANDED_FIELD, expanded, EXPANDED_STYLE_DATATYPE);
  }
}

class ContainerStyleType extends CompositeDataType {
  const ContainerStyleType() : super(STYLES_NAMESPACE, 'container_style');

  @override
  ContainerStyle newInstance(DataId dataId) => ContainerStyle.uninitialized(dataId);
}

const ContainerStyleType CONTAINER_STYLE_DATATYPE = const ContainerStyleType();

const String LEFT_FIELD = 'left';
const String TOP_FIELD = 'top';
const String RIGHT_FIELD = 'right';
const String BOTTOM_FIELD = 'bottom';
const String WIDTH_FIELD = 'width';

// TODO(dynin): no longer immutable.
class ContainerStyle extends BaseCompositeData implements Style {
  final DataId dataId;
  final Ref<double> left;
  final Ref<double> top;
  final Ref<double> right;
  final Ref<double> bottom;
  final Ref<double> width;
  final Ref<NamedColor> color;
  final Ref<ExpandedStyle> expanded;

  ContainerStyle.fromLTRB(this.dataId, double left, double top, double right, double bottom,
      {double width, NamedColor color, ExpandedStyle expanded})
      : left = Boxed<double>(left),
        top = Boxed<double>(top),
        right = Boxed<double>(right),
        bottom = Boxed<double>(bottom),
        width = Boxed<double>(width),
        color = Boxed<NamedColor>(color),
        expanded = Boxed<ExpandedStyle>(expanded);

  ContainerStyle.symmetric(this.dataId,
      {double vertical = 0.0,
      double horizontal = 0.0,
      double width,
      NamedColor color,
      ExpandedStyle expanded})
      : left = Boxed<double>(horizontal),
        top = Boxed<double>(vertical),
        right = Boxed<double>(horizontal),
        bottom = Boxed<double>(vertical),
        width = Boxed<double>(width),
        color = Boxed<NamedColor>(color),
        expanded = Boxed<ExpandedStyle>(expanded);

  ContainerStyle.all(this.dataId, double value,
      {double width, NamedColor color, ExpandedStyle expanded})
      : left = Boxed<double>(value),
        top = Boxed<double>(value),
        right = Boxed<double>(value),
        bottom = Boxed<double>(value),
        width = Boxed<double>(width),
        color = Boxed<NamedColor>(color),
        expanded = Boxed<ExpandedStyle>(expanded);

  ContainerStyle.uninitialized(DataId dataId)
      : dataId = dataId != null ? dataId : styleIdSource.nextId(),
        left = Boxed<double>(),
        top = Boxed<double>(),
        right = Boxed<double>(),
        bottom = Boxed<double>(),
        width = Boxed<double>(),
        color = Boxed<NamedColor>(),
        expanded = Boxed<ExpandedStyle>();

  ContainerStyleType get dataType => CONTAINER_STYLE_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.doubleField(LEFT_FIELD, left);
    visitor.doubleField(TOP_FIELD, top);
    visitor.doubleField(RIGHT_FIELD, right);
    visitor.doubleField(BOTTOM_FIELD, bottom);
    visitor.doubleField(WIDTH_FIELD, width);
    visitor.dataField(COLOR_FIELD, color, NAMED_COLOR_DATATYPE);
    visitor.dataField(EXPANDED_FIELD, expanded, EXPANDED_STYLE_DATATYPE);
  }
}

enum BooleanStyle { checkbox, switch_ }

class BooleanInputStyleType extends ImmutableDataType {
  const BooleanInputStyleType() : super(STYLES_NAMESPACE, 'boolean_input_style');
}

const BooleanInputStyleType BOOLEAN_INPUT_STYLE_DATATYPE = const BooleanInputStyleType();

class BooleanInputStyle extends Style with BaseImmutable {
  final DataId dataId;
  final BooleanStyle booleanStyle;

  BooleanInputStyle(this.dataId, this.booleanStyle);

  BooleanInputStyleType get dataType => BOOLEAN_INPUT_STYLE_DATATYPE;
}
