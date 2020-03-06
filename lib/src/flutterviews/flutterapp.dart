// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;

import '../../elements.dart';
import '../../views.dart';
import 'flutterwidgets.dart';
import 'flutterstyles.dart';

final ThemeData appTheme = ThemeData(brightness: Brightness.light, primarySwatch: Colors.teal);

const EdgeInsets _MAIN_VIEW_PADDING = const EdgeInsets.all(10.0);
const double _ICON_SIZE_S24 = 24.0;

class FlutterApp {
  final FlutterAppWidget appWidget;

  FlutterApp(ApplicationView appView) : appWidget = FlutterAppWidget(appView);

  void run() {
    // TODO(dynin): there should be a better way to configure Flutter platform,
    // but we are using this for now.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

    // TODO(dynin): update appTitle when it has changed.
    runApp(MaterialApp(
        theme: appTheme,
        title: appWidget.appView.appTitle.value,
        routes: <String, WidgetBuilder>{'/': (BuildContext context) => appWidget}));
  }
}

class FlutterAppWidget extends StatefulWidget {
  final ApplicationView appView;

  FlutterAppWidget(this.appView);

  FlutterWidgetState createState() => FlutterWidgetState();
}

class FlutterWidgetState extends State<FlutterAppWidget> with FlutterWidgets {
  final Zone viewZone = BaseZone(null, 'flutterview');

  void initState() {
    super.initState();

    Operation rebuildOperation = viewZone.makeOperation(rebuildApp);
    widget.appView.appTitle.observeRef(rebuildOperation, viewZone);
    widget.appView.model.observeDeep(rebuildOperation, viewZone);
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  void rebuildApp() {
    // This is Flutter's way of forcing widgets to refresh.
    setState(() {});
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildMainCanvas(),
        drawer: _buildDrawer(context),
        floatingActionButton: _buildFloatingActionButton());
  }

  Widget _buildMainCanvas() {
    Widget mainWidget = viewToWidget(widget.appView.model.value, viewZone);
    return Material(
        type: MaterialType.canvas,
        child: Container(padding: mainViewPadding ? _MAIN_VIEW_PADDING : null, child: mainWidget));
  }

  AppBar _buildAppBar(BuildContext context) {
    Text titleText = Text(widget.appView.appTitle.value);
    if (isNotNull(widget.appView.appVersion)) {
      return AppBar(
          title: Row(children: [
        Expanded(child: titleText),
        Text(widget.appView.appVersion.value, style: TextStyle(fontSize: 14.0))
      ]));
    } else {
      return AppBar(title: titleText);
    }
  }

  Widget _buildFloatingActionButton() {
    if (isNotNull(widget.appView.buttonIcon) && isNotNull(widget.appView.buttonOperation)) {
      Operation buttonOperation = widget.appView.buttonOperation.value;
      return FloatingActionButton(
          child: Icon(toIconData(widget.appView.buttonIcon.value), size: _ICON_SIZE_S24),
          backgroundColor: Colors.redAccent[200],
          onPressed: () => buttonOperation.scheduleAction());
    } else {
      return null;
    }
  }

  Widget _buildDrawer(BuildContext context) {
    if (isNotNull(widget.appView.drawer)) {
      return renderDrawer(widget.appView.drawer.value, viewZone);
    } else {
      return null;
    }
  }

  void dismissDrawer() {
    // This is Flutter's way of making the drawer go away.
    Navigator.pop(context);
  }
}
