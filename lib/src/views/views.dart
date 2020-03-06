// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

import 'point.dart';
import 'styles.dart';

/// An interface for the view of a given model.
abstract class View<ModelType> {
  ReadRef<ModelType> get model;
  ReadRef<Style> get style;
}

/// An interface for the editor of a given model.
abstract class Editor<ModelType> extends View<ModelType> {
  Ref<ModelType> get model;
}

/// A base class for the view of a given model.
class BaseView<ModelType> implements View<ModelType> {
  final ReadRef<ModelType> _model;
  final ReadRef<Style> style;

  // Fields for internal use by the toolkit implementation
  Lifespan cachedSubSpan;

  ReadRef<ModelType> get model => _model;

  BaseView(this._model, this.style);
}

/// A base class for the view of a given model.
class BaseEditor<ModelType> extends BaseView<ModelType> implements Editor<ModelType> {
  Ref<ModelType> get model => _model as Ref<ModelType>;

  BaseEditor(Ref<ModelType> model, ReadRef<Style> style) : super(model, style);
}

/// A text view of a String model
class LabelView extends BaseView<String> {
  LabelView(ReadRef<String> labelText, ReadRef<Style> style) : super(labelText, style);
}

/// A transparent glue (empty view).
class GlueView extends BaseView<double> {
  GlueView(ReadRef<double> glueWidth, [ReadRef<Style> style]) : super(glueWidth, style);
}

/// An editable text view
class TextInput extends BaseEditor<String> {
  TextInput(Ref<String> text, ReadRef<Style> style) : super(text, style);
}

/// A boolean input, a checkbox or a switch depending on style
class BooleanInput extends BaseEditor<bool> {
  BooleanInput(Ref<bool> state, [ReadRef<Style> style]) : super(state, style);
}

/// A slider, with values from 0.0 to 1.0
class SliderInput extends BaseEditor<double> {
  SliderInput(Ref<double> state, [ReadRef<Style> style]) : super(state, style);
}

/// A link (underlined text) view
class LinkView extends BaseView<String> {
  final ReadRef<Operation> action;

  LinkView(ReadRef<String> buttonText, this.action, [ReadRef<Style> style])
      : super(buttonText, style);
}

/// A button view
class ButtonView extends BaseView<String> {
  final ReadRef<Operation> action;

  ButtonView(ReadRef<String> buttonText, ReadRef<Style> style, this.action)
      : super(buttonText, style);
}

/// An icon button view
class IconButtonView extends BaseView<IconId> {
  final ReadRef<Operation> action;

  IconButtonView(ReadRef<IconId> icon, ReadRef<Style> style, this.action) : super(icon, style);
}

typedef String SelectDisplayFunction<T>(T value);

/// A selection view (a.k.a. dropdown buttons)
class SelectionInput<T> extends BaseEditor<T> {
  final ReadList<T> options;
  final SelectDisplayFunction<T> display;
  final bool sort;

  SelectionInput(Ref<T> current, this.options, this.display, this.sort, [ReadRef<Style> style])
      : super(current, style);
}

/// A flex container view that has subviews
abstract class FlexView extends BaseView<ReadList<View>> {
  FlexView(ReadList<View> subviews, [ReadRef<Style> style])
      : super(new Constant<ReadList<View>>(subviews), style);
}

/// A row view
class RowView extends FlexView {
  RowView(ReadList<View> columns, [ReadRef<Style> style]) : super(columns, style);
}

/// A column view
class ColumnView extends FlexView {
  ColumnView(ReadList<View> rows, [ReadRef<Style> style]) : super(rows, style);
}

/// A container wrapper
class ContainerView extends BaseView<View> {
  ContainerView(ReadRef<View> child, ReadRef<Style> style) : super(child, style);
}

/// An action view (rendered using InkWell)
class ActionView extends BaseView<View> {
  final ReadRef<Operation> action;

  ActionView(ReadRef<View> child, this.action, [ReadRef<Style> style]) : super(child, style);
}

enum GestureActionType { dragStart, dragUpdate, dragEnd }

typedef GestureActionCallback = void Function(GestureActionType type, Point point);

/// A gesture detector/action view (rendered using GestureDetector)
class GestureActionView extends BaseView<View> {
  final GestureActionCallback action;

  GestureActionView(ReadRef<View> child, this.action, [ReadRef<Style> style]) : super(child, style);
}

/// A canvas with lines drawn on it
class CanvasView extends BaseView<ReadList<Point>> {
  CanvasView(ReadRef<ReadList<Point>> points, [ReadRef<Style> style]) : super(points, style);
}

/// A header item (which can be rendered as a DrawerHeader)
class HeaderView extends BaseView<String> {
  HeaderView(ReadRef<String> headerText) : super(headerText, null);
}

/// An item (which can be rendered as a DrawerItem)
class ItemView extends BaseView<String> {
  final ReadRef<IconId> icon;
  final ReadRef<bool> selected;
  final ReadRef<Operation> action;

  // Do not specify the style here.
  ItemView(ReadRef<String> itemText, this.icon, this.selected, this.action) : super(itemText, null);
}

/// A divider
class DividerView extends BaseView<void> {
  // TODO: move to style
  double height;
  DividerView([this.height]) : super(null, null);
}

/// A drawer
class DrawerView extends FlexView {
  DrawerView(ReadList<View> items) : super(items);
}

/// Application view
class ApplicationView extends BaseView<View> {
  ReadRef<String> appTitle;
  ReadRef<String> appVersion;
  ReadRef<DrawerView> drawer;
  ReadRef<IconId> buttonIcon;
  ReadRef<Operation> buttonOperation;

  ApplicationView(ReadRef<View> mainView, this.appTitle,
      {this.appVersion, this.drawer, this.buttonIcon, this.buttonOperation})
      : super(mainView, null);
}
