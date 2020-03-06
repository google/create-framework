// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutterstyles;

import 'dart:ui' show Color;
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart';

import '../../views.dart';

TextTheme flutterTheme = Typography.englishLike2014.merge(Typography.blackMountainView);

// Using Material 2018 style names as they are more consistent,
// see https://api.flutter.dev/flutter/material/TextTheme-class.html
Map<ThemedStyle, TextStyle> _themedStyleMap = <ThemedStyle, TextStyle>{
  HEADLINE6_STYLE: flutterTheme.title,
  SUBTITLE1_STYLE: flutterTheme.subhead,
  BODY1_STYLE: flutterTheme.body2, // Yes, this is not a typo
  BODY2_STYLE: flutterTheme.body1, // Yes, this is not a typo
  CAPTION_STYLE: flutterTheme.caption,
  BUTTON_STYLE: flutterTheme.button
};

Map<NamedColor, Color> _namedColorMap = <NamedColor, Color>{
  BLACK_COLOR: Colors.black,
  WHITE_COLOR: Colors.white,
  RED_COLOR: Colors.red[500],
  GREEN_COLOR: Colors.green[500],
  BLUE_COLOR: Colors.blue[500],
  LIGHT_TEAL_COLOR: Colors.teal[100],
  LIGHT_GREY_COLOR: Colors.grey[200],
  LIGHT_BLUE_COLOR: Colors.blue[200],
};

Map<IconId, IconData> _iconMap = <IconId, IconData>{
  ADD_CIRCLE_ICON: Icons.add_circle,
  ADD_ICON: Icons.add,
  ARROW_BACK_ICON: Icons.arrow_back,
  ARROW_DROP_DOWN_ICON: Icons.arrow_drop_down,
  ARROW_FORWARD_ICON: Icons.arrow_forward,
  CLEAR_ICON: Icons.clear,
  CLOUD_ICON: Icons.cloud,
  CODE_ICON: Icons.code,
  CONTENT_COPY_ICON: Icons.content_copy,
  EXPOSURE_PLUS_1_ICON: Icons.exposure_plus_1,
  EXPOSURE_PLUS_2_ICON: Icons.exposure_plus_2,
  EXTENSION_ICON: Icons.extension,
  HELP_ICON: Icons.help,
  LAUNCH_ICON: Icons.launch,
  MENU_ICON: Icons.menu,
  MODE_EDIT_ICON: Icons.mode_edit,
  MORE_VERT_ICON: Icons.more_vert,
  RADIO_BUTTON_CHECKED_ICON: Icons.radio_button_checked,
  RADIO_BUTTON_UNCHECKED_ICON: Icons.radio_button_unchecked,
  REMOVE_CIRCLE_ICON: Icons.remove_circle,
  SEARCH_ICON: Icons.search,
  SETTINGS_ICON: Icons.settings,
  SETTINGS_SYSTEM_DAYDREAM_ICON: Icons.settings_system_daydream,
  STYLE_ICON: Icons.style,
  VIEW_QUILT_ICON: Icons.view_quilt,
  VISIBILITY_ICON: Icons.visibility,
  WIDGETS_ICON: Icons.widgets,
};

Map<MainAxis, MainAxisAlignment> _mainAxisAlignmentMap = <MainAxis, MainAxisAlignment>{
  START_MAIN_AXIS: MainAxisAlignment.start,
  END_MAIN_AXIS: MainAxisAlignment.end,
  SPACE_BETWEEN_MAIN_AXIS: MainAxisAlignment.spaceBetween,
  SPACE_AROUND_MAIN_AXIS: MainAxisAlignment.spaceAround,
  SPACE_EVENLY_MAIN_AXIS: MainAxisAlignment.spaceEvenly,
};

Map<CrossAxis, CrossAxisAlignment> _crossAxisAlignmentMap = <CrossAxis, CrossAxisAlignment>{
  START_CROSS_AXIS: CrossAxisAlignment.start,
  END_CROSS_AXIS: CrossAxisAlignment.end,
  CENTER_CROSS_AXIS: CrossAxisAlignment.center,
  STRETCH_CROSS_AXIS: CrossAxisAlignment.stretch,
  BASELINE_CROSS_AXIS: CrossAxisAlignment.baseline,
};

TextStyle toTextStyle(Style style) {
  if (style is ThemedStyle) {
    TextStyle result = _themedStyleMap[style];
    assert(result != null);
    return result;
  } else if (style is FontColorStyle) {
    Color colorValue = toColor(style.styleColor);
    return TextStyle(fontSize: style.styleFontSize, color: colorValue);
  } else {
    throw 'Unrecognized style';
  }
}

Color toColor(NamedColor namedColor) {
  Color colorValue = _namedColorMap[namedColor];
  assert(colorValue != null);
  return colorValue;
}

IconData toIconData(IconId iconId) {
  IconData result = _iconMap[iconId];
  assert(result != null);
  return result;
}

MainAxisAlignment toMainAxisAlignment(MainAxis style) {
  MainAxisAlignment result = _mainAxisAlignmentMap[style];
  assert(result != null);
  return result;
}

CrossAxisAlignment toCrossAxisAlignment(CrossAxis style) {
  CrossAxisAlignment result = _crossAxisAlignmentMap[style];
  assert(result != null);
  return result;
}

EdgeInsets toEdgeInsets(ContainerStyle style) {
  return EdgeInsets.fromLTRB(
      style.left.value, style.top.value, style.right.value, style.bottom.value);
}
