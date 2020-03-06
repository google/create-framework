// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

import '../../elements.dart';
import '../../views.dart';
import 'flutterstyles.dart';

abstract class FlutterWidgets {
  void rebuildApp();
  void dismissDrawer();

  Widget viewToWidget(View _view, Lifespan lifespan) {
    BaseView view = _view as BaseView;
    _cleanupView(view);
    view.cachedSubSpan = lifespan.makeSubSpan();
    Operation forceRefreshOp = lifespan.zone.makeOperation(() => forceRefresh(view));

    Widget result = renderView(view, lifespan);

    // TextComponent knows what it's doing, and handles updates itself.
    if (!(result is TextComponent)) {
      if (view.model != null) {
        view.model.observeDeep(forceRefreshOp, view.cachedSubSpan);
      }
      if (view.style != null) {
        view.style.observeDeep(forceRefreshOp, view.cachedSubSpan);
      }
      // TODO: observe icon for ItemView, etc.
    }

    return result;
  }

  // Dispose of cached widget and associated resources
  void _cleanupView(BaseView view) {
    if (view.cachedSubSpan != null) {
      view.cachedSubSpan.dispose();
      view.cachedSubSpan = null;
    }
  }

  void forceRefresh(View view) {
    _cleanupView(view);

    // TODO: implement finer-grained refreshing.
    rebuildApp();
  }

  Widget renderView(View view, Lifespan lifespan) {
    // TODO: use the visitor pattern here?
    if (view is LabelView) {
      return renderLabel(view);
    } else if (view is BooleanInput) {
      return renderBooleanInput(view, lifespan);
    } else if (view is TextInput) {
      return renderTextInput(view, lifespan);
    } else if (view is LinkView) {
      return renderLink(view);
    } else if (view is ButtonView) {
      return renderButton(view);
    } else if (view is IconButtonView) {
      return renderIconButton(view);
    } else if (view is SelectionInput) {
      return renderSelection(view, lifespan);
    } else if (view is HeaderView) {
      return renderHeader(view);
    } else if (view is ItemView) {
      return renderItem(view);
    } else if (view is DividerView) {
      return renderDivider(view);
    } else if (view is RowView) {
      return renderRow(view, lifespan);
    } else if (view is GlueView) {
      return renderGlue(view);
    } else if (view is ColumnView) {
      return renderColumn(view, lifespan);
    } else if (view is ContainerView) {
      return renderContainer(view, lifespan);
    } else if (view is ActionView) {
      return renderAction(view, lifespan);
    } else if (view is DrawerView) {
      return renderDrawer(view, lifespan);
    } else if (view is SliderInput) {
      return renderSliderInput(view, lifespan);
    } else if (view is GestureActionView) {
      return renderGestureAction(view, lifespan);
    } else if (view is CanvasView) {
      return renderCanvas(view, lifespan);
    }

    throw UnimplementedError('Unknown view: ${view.runtimeType}');
  }

  Widget renderLabel(LabelView label) {
    return Text(
      label.model.value != null ? label.model.value : '<null>',
      style: textStyleOf(label),
      // TODO: make it a style option
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget renderGlue(GlueView label) {
    return SizedBox(width: label.model.value);
  }

  Widget renderBooleanInput(BooleanInput input, Lifespan lifespan) {
    BooleanStyle style;
    if (isNotNull(input.style)) {
      if (input.style.value is BooleanInputStyle) {
        style = (input.style.value as BooleanInputStyle).booleanStyle;
      }
    }

    void changeState(bool newValue) => input.model.value = newValue;
    Widget widget;

    switch (style) {
      case BooleanStyle.switch_:
        widget = Switch(value: input.model.value, onChanged: changeState);
        break;

      case BooleanStyle.checkbox:
      default:
        widget = Checkbox(value: input.model.value, onChanged: changeState);
        break;
    }

    return widget;
  }

  Widget renderSliderInput(SliderInput input, Lifespan lifespan) {
    void changeState(double newValue) => input.model.value = newValue;
    return Slider(value: input.model.value, onChanged: changeState);
  }

  Widget renderTextInput(TextInput input, Lifespan lifespan) {
    return TextComponent(input, lifespan);
  }

  Widget renderSelection(SelectionInput selection, Lifespan lifespan) {
    return DropdownComponent(selection, lifespan);
  }

  Widget renderLink(LinkView link) {
    TextStyle style = textStyleOf(link);
    style = style.apply(color: const Color(0xFF0000FF), decoration: TextDecoration.underline);
    Widget child = Text(link.model.value, style: style);
    return InkWell(child: child, onTap: _scheduleAction(link.action));
  }

  Widget renderButton(ButtonView button) {
    return RaisedButton(
        child: Text(button.model.value, style: textStyleOf(button)),
        onPressed: _scheduleAction(button.action));
  }

  IconButton renderIconButton(IconButtonView button) {
    return IconButton(
        icon: Icon(toIconData(button.model.value)), onPressed: _scheduleAction(button.action));
  }

  DrawerHeader renderHeader(HeaderView header) {
    return DrawerHeader(child: Text(header.model.value, style: textStyleOf(header)));
  }

  Widget renderItem(ItemView item) {
    return ListTile(
        leading: item.icon.value != null ? Icon(toIconData(item.icon.value)) : null,
        title: Text(item.model.value, style: textStyleOf(item)),
        selected: item.selected.value,
        onTap: () {
          dismissDrawer();
          if (isNotNull(item.action)) {
            // We dismiss the drawer as a side effect of an item selection.
            item.action.value.scheduleAction();
          }
        });
  }

  Divider renderDivider(DividerView divider) {
    if (divider.height != null) {
      return Divider(height: divider.height);
    } else {
      return Divider();
    }
  }

  Widget _expand(Widget widget, ExpandedStyle expanded) {
    switch (expanded) {
      case EXPANDED_STYLE:
        return Expanded(child: widget);

      case FLEXIBLE_STYLE:
        return Flexible(child: widget);

      case SCROLL_AND_FLEX_STYLE:
        return Flexible(
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: widget)));

      case NONE_STYLE:
      default:
        return widget;
    }
  }

  Widget renderRow(RowView row, Lifespan lifespan) {
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start;
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center;
    double height;
    Color color;
    ExpandedStyle expanded;

    if (isNotNull(row.style)) {
      Style style = row.style.value;
      if (style is FlexStyle) {
        if (style.mainAxisAlignment.value != null) {
          mainAxisAlignment = toMainAxisAlignment(style.mainAxisAlignment.value);
        }
        if (style.crossAxisAlignment.value != null) {
          crossAxisAlignment = toCrossAxisAlignment(style.crossAxisAlignment.value);
        }
        if (style.height.value != null) {
          height = style.height.value;
        }
        if (style.color.value != null) {
          color = toColor(style.color.value);
        }
        expanded = style.expanded.value;
      }
    }

    Widget result = Row(
        children: _buildWidgetList(row.model, lifespan),
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment);
    if (height != null || color != null) {
      result = Container(child: result, height: height, color: color);
    }
    return _expand(result, expanded);
  }

  Widget renderColumn(ColumnView column, Lifespan lifespan) {
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start;
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start;
    List<Widget> children = _buildWidgetList(column.model, lifespan);
    // TODO: use this property from FlexStyle.
    Color color;
    ExpandedStyle expanded;
    bool useListView = false;

    if (isNotNull(column.style)) {
      Style style = column.style.value;
      if (style is FlexStyle) {
        if (style.mainAxisAlignment.value != null) {
          mainAxisAlignment = toMainAxisAlignment(style.mainAxisAlignment.value);
        }
        if (style.crossAxisAlignment.value != null) {
          crossAxisAlignment = toCrossAxisAlignment(style.crossAxisAlignment.value);
        }
        if (style.color.value != null) {
          color = toColor(style.color.value);
        }
        expanded = style.expanded.value;
        if (expanded == EXPANDED_LIST_VIEW_STYLE) {
          useListView = true;
          expanded = null;
        } else if (expanded == DOUBLE_EXPANDED_LIST_VIEW_STYLE) {
          useListView = true;
          expanded = EXPANDED_STYLE;
        }
      }
    }

    if (useListView) {
      Widget listView = ListView(children: children, padding: const EdgeInsets.all(8.0));
      children = <Widget>[Expanded(child: listView)];
    }

    Widget result = Column(
        children: children,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment);
    result = _expand(result, expanded);

    if (color != null) {
      result = Container(child: result, color: color);
    }

    return result;
  }

  Widget renderContainer(ContainerView container, Lifespan lifespan) {
    Widget child = viewToWidget(container.model.value, lifespan);
    EdgeInsets padding;
    double width;
    Color color;
    ExpandedStyle expanded;

    if (isNotNull(container.style)) {
      Style style = container.style.value;
      if (style is ContainerStyle) {
        padding = toEdgeInsets(style);
        width = style.width.value;
        if (style.color.value != null) {
          color = toColor(style.color.value);
        }
        expanded = style.expanded.value;
      }
    }

    Widget result = Container(child: child, padding: padding, width: width, color: color);
    return _expand(result, expanded);
  }

  Widget renderAction(ActionView view, Lifespan lifespan) {
    Widget child = viewToWidget(view.model.value, lifespan);
    return InkWell(child: child, onTap: _scheduleAction(view.action));
  }

  Widget renderGestureAction(GestureActionView view, Lifespan lifespan) {
    Widget child = Container(
        alignment: Alignment.topLeft,
        color: Colors.white,
        child: viewToWidget(view.model.value, lifespan));

    return GestureActionComponent(view, child);
  }

  Widget renderCanvas(CanvasView view, Lifespan lifespan) {
    return CustomPaint(painter: LinePainter(view));
  }

  Drawer renderDrawer(DrawerView drawer, Lifespan lifespan) {
    return Drawer(child: Column(children: _buildWidgetList(drawer.model, lifespan)));
  }

  Function _scheduleAction(ReadRef<Operation> action) => () {
        if (isNotNull(action)) {
          action.value.scheduleAction();
        }
      };

  List<Widget> _buildWidgetList(ReadRef<ReadList<View>> views, Lifespan lifespan) {
    return MappedList<View, Widget>(views.value, (view) => viewToWidget(view, lifespan), lifespan)
        .elements;
  }
}

class LinePainter extends CustomPainter {
  final CanvasView canvasView;
  final Paint defaultPaint;

  LinePainter(this.canvasView) : defaultPaint = Paint() {
    // TODO(dynin): specify using style.
    defaultPaint.color = Colors.black;
    defaultPaint.strokeWidth = 3.0;
    defaultPaint.strokeCap = StrokeCap.round;
  }

  bool shouldRepaint(LinePainter oldDelegate) => true;

  void paint(Canvas canvas, Size size) {
    Offset pointToOffset(Point point) => Offset(point.x.value, point.y.value);

    List<Point> points = canvasView.model.value.elements;

    for (int i = 0; i < points.length - 1; ++i) {
      if (points[i] != null && points[i + 1] != null) {
        Offset start = pointToOffset(points[i]);
        Offset end = pointToOffset(points[i + 1]);
        canvas.drawLine(start, end, defaultPaint);
      }
    }
  }
}

TextStyle textStyleOf(View view) {
  if (isNotNull(view.style)) {
    Style style = view.style.value;
    if (style is ThemedStyle || style is FontColorStyle) {
      return toTextStyle(style);
    }
  }

  return null;
}

// TODO: Make better use of Flutter widgets
class TextComponent extends StatefulWidget {
  final TextInput input;
  final Lifespan lifespan;

  TextComponent(this.input, this.lifespan);

  TextComponentState createState() => TextComponentState();
}

class TextComponentState extends State<TextComponent> {
  GlobalKey inputKey = GlobalKey();
  final TextEditingController _controller = TextEditingController();
  bool observing = false;

  TextStyle get textStyle => textStyleOf(widget.input);

  Widget build(BuildContext context) {
    registerObserverIfNeeded();
    _controller.text = widget.input.model.value;
    return Container(
        width: 300.0,
        child: TextField(
            key: inputKey, style: textStyle, controller: _controller, onChanged: _widgetChanged));
    /*
    Row(children: [
      IconButton(icon: Icon(toIconData(MODE_EDIT_ICON), onPressed: _editPressed),
      Flexible(
              ? TextField(key: inputKey, controller: _controller, onChanged: _widgetChanged)
              : Text(widget.input.model.value, style: textStyle))
    */
  }

  void registerObserverIfNeeded() {
    if (!observing) {
      Operation inputChanged = widget.lifespan.zone.makeOperation(_inputChanged);
      widget.input.model.observeRef(inputChanged, widget.lifespan);
      observing = true;
    }
  }

  void _inputChanged() {
    if (widget.input.model.value != _controller.text) {
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  void _widgetChanged(String newValue) {
    widget.input.model.value = newValue;
  }
}

const _DIVIDER_LINE = const Object();

class DropdownComponent extends StatefulWidget {
  final SelectionInput selection;
  final Lifespan lifespan;

  DropdownComponent(this.selection, this.lifespan);

  @override
  DropdownState createState() => DropdownState();
}

class DropdownState<T> extends State<DropdownComponent> {
  List<Object> _options;
  TextStyle _textStyle;

  void initState() {
    super.initState();
    _textStyle = textStyleOf(widget.selection);
  }

  Widget build(BuildContext context) {
    _options = makeOptions(widget.selection.options.elements, widget.selection.model.value);

    List<DropdownMenuItem<int>> items = [];
    for (int index = 0; index < _options.length; ++index) {
      items.add(makeMenuItem(index));
    }

    return DropdownButton<int>(items: items, value: 0, onChanged: selected);
  }

  String display(Object item) => widget.selection.display(item as T);

  List<Object> makeOptions(List<T> selectionOptions, T value) {
    List<Object> optionsList = List<Object>();
    for (T option in selectionOptions) {
      if (option == value) {
        continue;
      }
      optionsList.add(option);
    }
    if (widget.selection.sort) {
      optionsList.sort((a, b) => display(a).compareTo(display(b)));
    }
    optionsList.insertAll(0, [value, _DIVIDER_LINE]);
    return optionsList;
  }

  DropdownMenuItem<int> makeMenuItem(int index) {
    Object item = _options[index];
    Widget menuItem;
    if (item == _DIVIDER_LINE) {
      menuItem = Divider();
    } else {
      menuItem = Text(display(item), style: _textStyle);
    }
    return DropdownMenuItem<int>(child: menuItem, value: index);
  }

  void selected(int index) {
    if (index < _options.length) {
      Object value = _options[index];
      if (value == _DIVIDER_LINE) {
        return;
      }
      widget.selection.model.value = value as T;
    }
  }
}

class GestureActionComponent extends StatelessWidget {
  final GestureActionView view;
  final Widget child;

  GestureActionComponent(this.view, this.child);

  Widget build(BuildContext context) {
    Point localPoint(Offset globalPosition) {
      RenderBox box = context.findRenderObject();
      Offset point = box.globalToLocal(globalPosition);
      return Point(point.dx, point.dy);
    }

    return GestureDetector(
        onPanStart: (DragStartDetails details) {
          view.action(GestureActionType.dragStart, localPoint(details.globalPosition));
        },
        onPanUpdate: (DragUpdateDetails details) {
          view.action(GestureActionType.dragUpdate, localPoint(details.globalPosition));
        },
        onPanEnd: (DragEndDetails details) {
          view.action(GestureActionType.dragEnd, null);
        },
        child: child);
  }
}
