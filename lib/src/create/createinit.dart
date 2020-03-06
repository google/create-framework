// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../datastore.dart';
import '../../views.dart';

import 'createdata.dart';
import 'library.dart';

MuliplexDatastore<CompositeData> makeMultiplexStore() {
  SubDatastore<CompositeData> builtins =
      SubDatastore<CompositeData>(InMemoryDatastore<CompositeData>(allCreateTypes), 'Built-ins');
  SubDatastore<CompositeData> application =
      SubDatastore<CompositeData>(InMemoryDatastore<CompositeData>(allCreateTypes), 'Application');

  return MuliplexDatastore<CompositeData>(<SubDatastore<CompositeData>>[builtins, application], 1);
}

Object _field = '#field';
Object _arg0 = '#arg0';

class CreateDataset extends ProcedureLibrary {
  DataIdSource ids;

  CreateDataset(Namespace namespace) {
    ids = SequentialIdSource(namespace);
  }

  List<CompositeData> makeInitialData() {
    DataRecord greeting =
        DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'greeting', STRING_DATATYPE, 'Hello, world! ');
    DataRecord greeting2 =
        DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'greeting2', STRING_DATATYPE, 'Hi there!');
    DataRecord from =
        DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'from', STRING_DATATYPE, 'Jane Hacker');
    DataRecord title =
        DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'title', STRING_DATATYPE, 'Important subject');

    DataType itemRecordDataType =
        (datastore as InMemoryDatastore).dataTypes.firstWhere((type) => type.name == 'item_record');

    List<ProcedureRecord> procedures = builtinProcedures(ids);
    ProcedureRecord ifProc = procedures.firstWhere((proc) => proc.name == 'if');
    ProcedureRecord callProc = procedures.firstWhere((proc) => proc.name == 'call');
    ProcedureRecord flipProc = procedures.firstWhere((proc) => proc.name == 'flip');
    ProcedureRecord mapProc = procedures.firstWhere((proc) => proc.name == 'map');
    ProcedureRecord allProc = procedures.firstWhere((proc) => proc.name == 'all');
    ProcedureRecord newLabel = procedures.firstWhere((proc) => proc.name == 'new_label');
    ProcedureRecord newButton = procedures.firstWhere((proc) => proc.name == 'new_button');
    ProcedureRecord newRow = procedures.firstWhere((proc) => proc.name == 'new_row');
    ProcedureRecord newColumn = procedures.firstWhere((proc) => proc.name == 'new_column');
    ProcedureRecord newContainer = procedures.firstWhere((proc) => proc.name == 'new_container');
    ProcedureRecord newDivider = procedures.firstWhere((proc) => proc.name == 'new_divider');
    ProcedureRecord newAction = procedures.firstWhere((proc) => proc.name == 'new_action');
    ProcedureRecord concatFun = procedures.firstWhere((proc) => proc.name == 'concatenate');

    ProcedureRecord fun = _proc0('fun', newLabel, [greeting2, BODY2_STYLE]);

    ProcedureRecord doubleProc =
        _proc1('double', 's', STRING_DATATYPE, STRING_DATATYPE, [concatFun, _arg0, _arg0]);

    ProcedureRecord doubleGreeting = _proc0('double_greeting', doubleProc, [greeting]);

    ProcedureRecord fontStyleCtor = constructorProcedure(ids, FONT_STYLE_DATATYPE);
    ProcedureRecord containerStyleCtor = constructorProcedure(ids, CONTAINER_STYLE_DATATYPE);
    ProcedureRecord flexStyleCtor = constructorProcedure(ids, FLEX_STYLE_DATATYPE);
    ProcedureRecord itemRecordCtor = constructorProcedure(ids, itemRecordDataType);

    ProcedureRecord normalStyle = _proc0(NORMAL_STYLE_NAME, fontStyleCtor, [16.0, BLACK_COLOR]);

    // Styles

    ProcedureRecord fromStyle =
        _proc0('from_style', containerStyleCtor, [0.0, 0.0, 0.0, 0.0, 120.0, null, null]);

    ProcedureRecord titleStyle =
        _proc0('title_style', containerStyleCtor, [0.0, 0.0, 0.0, 0.0, null, null, EXPANDED_STYLE]);

    ProcedureRecord itemRowStyle = _proc0('item_row_style', flexStyleCtor,
        [SPACE_BETWEEN_MAIN_AXIS, CENTER_CROSS_AXIS, 28.0, null, null]);

    // Rendered item

    DataRecord url =
        DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'url', STRING_DATATYPE, 'https://fuchsia.dev');

    ProcedureRecord itemLabelStyle =
        _proc1('item_label_style', 'item', itemRecordDataType, STYLE_DATATYPE, [
      ifProc,
      [_field, _arg0, 'unread', BOOLEAN_DATATYPE],
      BODY1_STYLE,
      BODY2_STYLE
    ]);

    ProcedureRecord itemFromLabel =
        _proc1('item_from_label', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newLabel,
      [_field, _arg0, 'from', STRING_DATATYPE],
      [itemLabelStyle, _arg0]
    ]);

    ProcedureRecord itemFromContainer =
        _proc1('item_from_container', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newContainer,
      [itemFromLabel, _arg0],
      [fromStyle]
    ]);

    ProcedureRecord itemTitleLabel =
        _proc1('item_title_label', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newLabel,
      [_field, _arg0, 'title', STRING_DATATYPE],
      [itemLabelStyle, _arg0]
    ]);

    ProcedureRecord itemTitleContainer =
        _proc1('item_title_container', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newContainer,
      [itemTitleLabel, _arg0],
      [titleStyle]
    ]);

    ProcedureRecord itemRow = _proc1('item_row', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newRow,
      [itemFromContainer, _arg0],
      [itemTitleContainer, _arg0],
      [itemRowStyle]
    ]);

    ProcedureRecord itemAction = _proc1('item_action', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newAction,
      [itemRow, _arg0],
      [
        callProc,
        flipProc,
        [_field, _arg0, 'unread', BOOLEAN_DATATYPE]
      ],
    ]);

    ProcedureRecord greyBackground =
        _proc0('grey_background', flexStyleCtor, [null, null, null, LIGHT_GREY_COLOR, null]);

    ProcedureRecord itemColumnStyle =
        _proc1('item_column_style', 'item', itemRecordDataType, STYLE_DATATYPE, [
      ifProc,
      [_field, _arg0, 'unread', BOOLEAN_DATATYPE],
      null,
      [greyBackground]
    ]);

    ProcedureRecord itemColumn = _proc1('item_column', 'item', itemRecordDataType, VIEW_DATATYPE, [
      newColumn,
      [itemAction, _arg0],
      [newDivider],
      [itemColumnStyle, _arg0]
    ]);

    // All items

    ProcedureRecord allItems = _proc0('all_items', allProc, [itemRecordDataType]);

    ProcedureRecord itemsViews = _proc0('items_views', mapProc, [
      [allItems],
      itemColumn
    ]);

    ProcedureRecord mainColumnStyle = _proc0(
        'main_column_style', flexStyleCtor, [null, null, null, null, EXPANDED_LIST_VIEW_STYLE]);

    ProcedureRecord briefingMain = _proc0('briefing_main', newColumn, [
      [itemsViews],
      [mainColumnStyle]
    ]);

    ProcedureRecord main = _proc0(MAIN_NAME, briefingMain, []);

    List<CompositeData> result = <CompositeData>[
      greeting,
      greeting2,
      from,
      title,
      url,
      main,
      briefingMain,
      allItems,
      itemsViews,
      fun,
      normalStyle,
      fromStyle,
      titleStyle,
      itemRowStyle,
      itemLabelStyle,
      itemFromLabel,
      itemFromContainer,
      itemTitleLabel,
      itemTitleContainer,
      itemRow,
      itemAction,
      greyBackground,
      itemColumnStyle,
      itemColumn,
      mainColumnStyle,
      // renderItem,
      doubleProc,
      doubleGreeting,
      containerStyleCtor,
      flexStyleCtor,
      itemRecordCtor,
      fontStyleCtor,
    ];
    result.addAll(procedures);

    DataRecord buttontext = DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'buttontext',
        STRING_DATATYPE, 'Increase the counter value');
    DataRecord describestate = DataRecord(OPERATION_DATATYPE, ids.nextId(), 'describestate',
        TEMPLATE_DATATYPE, 'The counter value is \$counter');
    DataRecord increase = DataRecord(
        OPERATION_DATATYPE, ids.nextId(), 'increase', INLINE_DATATYPE, 'counter += increaseby');

    CompositeData counterlabel = _proc0('counterlabel', newLabel, [describestate, BODY2_STYLE]);
    CompositeData counterbutton =
        _proc0('counterbutton', newButton, [buttontext, BUTTON_STYLE, increase]);
    ProcedureRecord counterMain = _proc0('counter_main', newColumn, [
      [counterlabel],
      [counterbutton]
    ]);

    ProcedureRecord bigred = _proc0('bigred', fontStyleCtor, [32.0, RED_COLOR]);
    ProcedureRecord largefont = _proc0('largefont', fontStyleCtor, [24.0, BLACK_COLOR]);

    List<CompositeData> common = <CompositeData>[
      DataRecord(APP_STATE_DATATYPE, ids.nextId(), 'counter', INTEGER_DATATYPE, '68'),
      buttontext,
      DataRecord(PARAMETER_DATATYPE, ids.nextId(), 'increaseby', INTEGER_DATATYPE, '1'),
      describestate,
      increase,
      counterlabel,
      counterbutton,
      counterMain,
      bigred,
      largefont
    ];
    result.addAll(common);

    return result;
  }

  ProcedureRecord _proc0(String procName, ProcedureRecord call, List<dynamic> arguments) {
    ProcedureRecord procedureCall =
        ProcedureRecord(ids.nextId(), procName, <ArgumentRecord>[], call.outputType.value);
    List expression = [call];
    expression.addAll(arguments);
    procedureCall.body.add(_makeExpression(expression, null, null));
    return procedureCall;
  }

  Object _makeExpression(List expression, String argName, DataType argType) {
    if (expression.isEmpty) {
      return [];
    }

    Object main = expression[0];
    List<Object> parameters = [];
    for (int i = 1; i < expression.length; ++i) {
      Object param = expression[i];
      if (param is List) {
        parameters.add(_makeExpression(param, argName, argType));
      } else if (param == _arg0) {
        parameters.add(ReferenceRecord(ids.nextId(), argName, argType));
      } else {
        parameters.add(param);
      }
    }

    if (main == _field) {
      Object value = parameters[0];
      String name = parameters[1];
      DataType type = parameters[2];
      return FieldRecord(ids.nextId(), value, name, type);
    } else if (main is ProcedureRecord) {
      ExpressionRecord result = ExpressionRecord(ids.nextId(), main);
      result.parameters.addAll(parameters);
      return result;
    } else {
      throw StateError('Unrecognized name $main');
    }
  }

  ProcedureRecord _proc1(
      String procName, String argName, DataType argType, DataType returnType, List expression) {
    ArgumentRecord arg = ArgumentRecord(ids.nextId(), argName, argType, null);
    ProcedureRecord procedureCall =
        ProcedureRecord(ids.nextId(), procName, <ArgumentRecord>[arg], returnType);

    procedureCall.body.add(_makeExpression(expression, argName, argType));
    return procedureCall;
  }
}

const String INITIAL_STATE = r'''{
  "#version": 0,
  "records": [
    {
      "#type": "create.parameter",
      "#id": "demoapp:0",
      "#version": 0,
      "#dependency": false,
      "record_name": "greeting",
      "type_id": "elements.type_id:elements.string",
      "state": "Hello, world!"
    },
    {
      "#type": "create.parameter",
      "#id": "demoapp:1",
      "#version": 0,
      "#dependency": false,
      "record_name": "greeting2",
      "type_id": "elements.type_id:elements.string",
      "state": "Hi there!"
    },
    {
      "#type": "create.style",
      "#id": "demoapp:2",
      "#version": 0,
      "#dependency": false,
      "record_name": "normalstyle",
      "font_size": 16.0,
      "color": "styles.named_color:black"
    },
    {
      "#type": "create.style",
      "#id": "demoapp:25",
      "#version": 0,
      "#dependency": false,
      "record_name": "largefont",
      "font_size": 24.0,
      "color": "styles.named_color:black"
    },
    {
      "#type": "create.style",
      "#id": "demoapp:22",
      "#version": 0,
      "#dependency": false,
      "record_name": "bigred",
      "font_size": 32.0,
      "color": "styles.named_color:red"
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:20",
      "#version": 0,
      "#dependency": false,
      "record_name": "main",
      "arguments": [],
      "output_type": "elements.type_id:create.view",
      "body": [
        "create.expression:demoapp:21"
      ]
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:23",
      "#version": 0,
      "#dependency": false,
      "record_name": "fun",
      "arguments": [],
      "output_type": "elements.type_id:create.view",
      "body": [
        "create.expression:demoapp:24"
      ]
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:4",
      "#version": 0,
      "#dependency": false,
      "record_name": "identity",
      "arguments": [
        "create.argument:demoapp:3//arg0"
      ],
      "output_type": "elements.type_id:elements.any",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:6",
      "#version": 0,
      "#dependency": false,
      "record_name": "list",
      "arguments": [
        "create.argument:demoapp:5//arg0"
      ],
      "output_type": "elements.type_id:elements.list",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:9",
      "#version": 0,
      "#dependency": false,
      "record_name": "concatenate",
      "arguments": [
        "create.argument:demoapp:7//arg0",
        "create.argument:demoapp:8//arg1"
      ],
      "output_type": "elements.type_id:elements.string",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:12",
      "#version": 0,
      "#dependency": false,
      "record_name": "new_label",
      "arguments": [
        "create.argument:demoapp:10//arg0",
        "create.argument:demoapp:11//arg1"
      ],
      "output_type": "elements.type_id:create.view",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:15",
      "#version": 0,
      "#dependency": false,
      "record_name": "new_button",
      "arguments": [
        "create.argument:demoapp:13//arg0",
        "create.argument:demoapp:14//arg1"
      ],
      "output_type": "elements.type_id:create.view",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:17",
      "#version": 0,
      "#dependency": false,
      "record_name": "new_row",
      "arguments": [
        "create.argument:demoapp:16//arg0"
      ],
      "output_type": "elements.type_id:create.view",
      "body": []
    },
    {
      "#type": "create.procedure",
      "#id": "demoapp:19",
      "#version": 0,
      "#dependency": false,
      "record_name": "new_column",
      "arguments": [
        "create.argument:demoapp:18//arg0"
      ],
      "output_type": "elements.type_id:create.view",
      "body": []
    },
    {
      "#type": "create.app_state",
      "#id": "demoapp:31",
      "#version": 0,
      "#dependency": false,
      "record_name": "counter",
      "type_id": "elements.type_id:elements.integer",
      "state": "68"
    },
    {
      "#type": "create.parameter",
      "#id": "demoapp:26",
      "#version": 0,
      "#dependency": false,
      "record_name": "buttontext",
      "type_id": "elements.type_id:elements.string",
      "state": "Increase the counter value"
    },
    {
      "#type": "create.parameter",
      "#id": "demoapp:32",
      "#version": 0,
      "#dependency": false,
      "record_name": "increaseby",
      "type_id": "elements.type_id:elements.integer",
      "state": "1"
    },
    {
      "#type": "create.operation",
      "#id": "demoapp:27",
      "#version": 0,
      "#dependency": false,
      "record_name": "describestate",
      "type_id": "elements.type_id:create.template",
      "state": "The counter value is $counter"
    },
    {
      "#type": "create.operation",
      "#id": "demoapp:28",
      "#version": 0,
      "#dependency": false,
      "record_name": "increase",
      "type_id": "elements.type_id:create.inline",
      "state": "counter += increaseby"
    },
    {
      "#type": "create.view",
      "#id": "demoapp:29",
      "#version": 0,
      "#dependency": false,
      "record_name": "counterlabel",
      "view_id": "create.view_id:label",
      "style": "styles.themed_style:body1",
      "content": "create.operation:demoapp:27//describestate",
      "action": null,
      "subviews": []
    },
    {
      "#type": "create.view",
      "#id": "demoapp:30",
      "#version": 0,
      "#dependency": false,
      "record_name": "counterbutton",
      "view_id": "create.view_id:button",
      "style": "styles.themed_style:button",
      "content": "create.parameter:demoapp:26//buttontext",
      "action": "create.operation:demoapp:28//increase",
      "subviews": []
    },
    {
      "#type": "create.view",
      "#id": "demoapp:33",
      "#version": 0,
      "#dependency": false,
      "record_name": "main2",
      "view_id": "create.view_id:column",
      "style": null,
      "content": null,
      "action": null,
      "subviews": [
        "create.view:demoapp:29//counterlabel",
        "create.view:demoapp:30//counterbutton"
      ]
    },
    {
      "#type": "create.expression",
      "#id": "demoapp:21",
      "#version": 0,
      "#dependency": true,
      "procedure": "create.procedure:demoapp:12//new_label",
      "parameters": [
        "create.parameter:demoapp:0//greeting",
        "create.style:demoapp:2//normalstyle"
      ]
    },
    {
      "#type": "create.expression",
      "#id": "demoapp:24",
      "#version": 0,
      "#dependency": true,
      "procedure": "create.procedure:demoapp:12//new_label",
      "parameters": [
        "create.parameter:demoapp:1//greeting2",
        "create.style:demoapp:22//bigred"
      ]
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:3",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.any",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:5",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.any",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:7",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.string",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:8",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg1",
      "type_id": "elements.type_id:elements.string",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:10",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.string",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:11",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg1",
      "type_id": "elements.type_id:create.style",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:13",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.string",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:14",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg1",
      "type_id": "elements.type_id:create.style",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:16",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.list",
      "default_value": null
    },
    {
      "#type": "create.argument",
      "#id": "demoapp:18",
      "#version": 0,
      "#dependency": true,
      "record_name": "arg0",
      "type_id": "elements.type_id:elements.list",
      "default_value": null
    }
  ]
}
''';
