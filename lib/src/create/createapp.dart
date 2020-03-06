// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../config.dart';
import '../../elements.dart';
import '../../datastore.dart';
import '../../views.dart';

import 'createdata.dart';
import 'createinit.dart';
import 'evaluator.dart';
import 'library.dart';

const Namespace DEMOAPP_NAMESPACE = const Namespace('Demo App', 'demoapp');

const Priority DEFAULT_PRIORITY = Priority.NORMAL;

const DataType APP_MODE_DATATYPE = const CreateDataType('app_mode');

class AppMode extends BaseNamed implements Data, DataId {
  final IconId icon;
  const AppMode(String name, this.icon) : super(name);

  DataId get dataId => this;

  DataType get dataType => APP_MODE_DATATYPE;
}

DisplayFunction displayString(String nullName) =>
    (value) => (value != null ? value.toString() : nullName);

const AppMode INITIALIZING_MODE = const AppMode('Initializing', null);
const AppMode MODULES_MODE = const AppMode('Modules', WIDGETS_ICON);
const AppMode SCHEMA_MODE = const AppMode('Schema', SETTINGS_SYSTEM_DAYDREAM_ICON);
const AppMode PARAMETERS_MODE = const AppMode('Parameters', SETTINGS_ICON);
const AppMode OPERATIONS_MODE = const AppMode('Operations', CODE_ICON);
const AppMode PROCEDURES_MODE = const AppMode('Procedures', CODE_ICON);
const AppMode STYLES_MODE = const AppMode('Styles', STYLE_ICON);
const AppMode VIEWS_MODE = const AppMode('Views', VIEW_QUILT_ICON);
const AppMode APP_STATE_MODE = const AppMode('State', CLOUD_ICON);
const AppMode LAUNCH_MODE = const AppMode('Launch', LAUNCH_ICON);

const List<AppMode> DRAWER_MODES = const [
  LAUNCH_MODE,
  MODULES_MODE,
  SCHEMA_MODE,
  PARAMETERS_MODE,
  OPERATIONS_MODE,
  STYLES_MODE,
  VIEWS_MODE,
  PROCEDURES_MODE,
  APP_STATE_MODE,
];

const AppMode STARTUP_MODE = PROCEDURES_MODE; // LAUNCH_MODE;

const List<DataType> PRIMITIVE_TYPES = const [INTEGER_DATATYPE, REAL_DATATYPE, STRING_DATATYPE];

const List<DataType> OPERATION_TYPES = const [TEMPLATE_DATATYPE, INLINE_DATATYPE];

const Constant<String> LEFT_PAREN = const Constant<String>(' (');
const Constant<String> RIGHT_PAREN = const Constant<String>(')');
const Constant<String> COMMA = const Constant<String>(', ');

const Constant<String> LEFT_BRACE = const Constant<String>(' {');
const Constant<String> RIGHT_BRACE = const Constant<String>('}');

const ReadRef<String> RIGHT_ARROW = const Constant<String>(' \u{2192} ');

final GlueView glue12 = GlueView(Constant<double>(12.0));
final GlueView glue24 = GlueView(Constant<double>(24.0));
final GlueView glue48 = GlueView(Constant<double>(48.0));

const List<double> FONT_SIZES = const [
  null,
  12.0,
  14.0,
  16.0,
  20.0,
  24.0,
  32.0,
  40.0,
  48.0,
  56.0,
  112.0,
];

const List<double> REAL_OPTIONS = const [
  null,
  0.0,
  5.0,
  10.0,
  15.0,
  20.0,
  28.0,
  32.0,
  40.0,
  48.0,
  56.0,
  112.0,
  200.0,
  300.0,
  400.0,
];

const List<int> INTEGER_OPTIONS = const [
  null,
  0,
  5,
  10,
  15,
  20,
];

const List<bool> BOOLEAN_OPTIONS = const [null, false, true];

bool isSchemaRecord(Data data) {
  return data.dataType == APP_STATE_DATATYPE;
}

bool isParameterRecord(Data data) {
  return data.dataType == PARAMETER_DATATYPE;
}

bool isOperationRecord(Data data) {
  return data.dataType == OPERATION_DATATYPE;
}

bool isProcedureRecord(Data data) {
  return data.dataType == PROCEDURE_DATATYPE;
}

bool isUserCompositeType(Data data) {
  return data is UserCompositeType;
}

bool isStyleRecord(Data data) {
  DataType dataType = data.dataType;
  if (data.dataType == PROCEDURE_DATATYPE) {
    ProcedureRecord procedure = data as ProcedureRecord;
    if (procedure.arguments.size.value > 0) {
      return false;
    }
    dataType = procedure.outputType.value;
  }

  return dataType == STYLE_DATATYPE ||
      dataType == FONT_STYLE_DATATYPE ||
      dataType == CONTAINER_STYLE_DATATYPE ||
      dataType == FLEX_STYLE_DATATYPE;
}

bool isViewRecord(Data data) {
  return data is ProcedureRecord && data.outputType.value == VIEW_DATATYPE;
}

AppMode pageToMode(Data page) {
  if (page is AppMode) {
    return page;
  } else if (isSchemaRecord(page)) {
    return SCHEMA_MODE;
  } else if (isParameterRecord(page)) {
    return PARAMETERS_MODE;
  } else if (isOperationRecord(page)) {
    return OPERATIONS_MODE;
  } else if (isStyleRecord(page)) {
    return STYLES_MODE;
  } else if (isViewRecord(page)) {
    return VIEWS_MODE;
  } else if (isProcedureRecord(page)) {
    return PROCEDURES_MODE;
  } else if (isUserCompositeType(page)) {
    return SCHEMA_MODE;
  } else {
    return LAUNCH_MODE;
  }
}

class NavigationBar {
  final CreateApp app;
  final DataIdSource idSource;
  ContainerStyle scrollableStyle;
  FlexStyle columnStyle;
  BooleanInputStyle switchStyle;
  ReadRef<Operation> backOperation;
  ReadRef<Operation> forwardOperation;

  NavigationBar(this.app, this.idSource) {
    scrollableStyle = ContainerStyle.all(idSource.nextId(), 0.0, expanded: SCROLL_AND_FLEX_STYLE);
    columnStyle = FlexStyle(idSource.nextId(), SPACE_BETWEEN_MAIN_AXIS, START_CROSS_AXIS);
    switchStyle = BooleanInputStyle(idSource.nextId(), BooleanStyle.switch_);

    backOperation = Constant<Operation>(app.makeOperation(app.backPressed));
    forwardOperation = Constant<Operation>(app.makeOperation(app.forwardPressed));
  }

  View addChrome(View pageView) {
    View scrollablePage = ContainerView(Constant<View>(pageView), Constant<Style>(scrollableStyle));
    return ColumnView(
        ImmutableList<View>([scrollablePage, _buildNavBar()]), Constant<Style>(columnStyle));
  }

  View _buildNavBar() {
    return RowView(ImmutableList<View>([
      IconButtonView(Constant<IconId>(ARROW_BACK_ICON), null, backOperation),
      IconButtonView(Constant<IconId>(ARROW_FORWARD_ICON), null, forwardOperation),
      IconButtonView(Constant<IconId>(VISIBILITY_ICON), null,
          Constant<Operation>(app.makeOperation(() => app.isEditing.value = false))),
      BooleanInput(app.isEditing, Constant<Style>(switchStyle)),
      IconButtonView(Constant<IconId>(MODE_EDIT_ICON), null,
          Constant<Operation>(app.makeOperation(() => app.isEditing.value = true))),
    ]));
  }
}

class CreateApp extends BaseZone {
  final ReadRef<bool> dataReady;
  final DataIdSource idSource = RandomIdSource(DEMOAPP_NAMESPACE);
  final Ref<Data> page = Boxed<Data>(INITIALIZING_MODE);
  final Ref<Style> normalStyle = Boxed<Style>();
  Evaluator evaluator;
  ReadRef<AppMode> appMode;
  CreateContext global;
  NavigationBar navBar;
  FontStyle defaultNormalStyle;
  MuliplexDatastore<CompositeData> multiplexStore;
  Ref<bool> isEditing = Boxed<bool>(false);
  ReadRef<String> appTitle;
  final ReadRef<String> appVersion = Constant<String>(CREATE_VERSION);
  final Boxed<DrawerView> drawer = Boxed<DrawerView>();
  ReadRef<Operation> buttonOperation;
  ReadRef<IconId> buttonIcon;
  ReactiveFunction2<Data, bool, View> pageView;
  ReadRef<View> mainView;
  ApplicationView view;
  List<Data> pageHistory = List<Data>();
  int currentPage = 0;
  Lifespan viewLifespan;

  CreateApp(Datastore<CompositeData> datastore, this.dataReady, ProcedureLibrary library)
      : super(null, 'createapp') {
    global = CreateContext(datastore);
    evaluator = Evaluator(this, idSource, global, library);
    navBar = NavigationBar(this, idSource);
    defaultNormalStyle = FontStyle(idSource.nextId(), 16.0, BLACK_COLOR);
    multiplexStore = makeMultiplexStore();
    ReadRef<String> titleString = Constant<String>(DEMOAPP_NAMESPACE.name);
    appTitle = ReactiveFunction2<String, Data, String>(titleString, page, _makeTitleLine, this);
    appMode = ReactiveFunction<Data, AppMode>(page, pageToMode, this);
    pageView = ReactiveFunction2<Data, bool, View>(page, isEditing, makePageView, this);
    mainView = ReactiveFunction2<View, bool, View>(pageView, isEditing, makeMainView, this);
    drawer.value = makeDrawer();
    buttonOperation = ReactiveFunction<Data, Operation>(page, makeAppOperation, this);
    buttonIcon = ReactiveFunction<Data, IconId>(page, makeAppOperationIcon, this);
    view = makeAppView();
    // TODO: add explicit padding
    mainViewPadding = true;
    page.observeRef(makeOperation(updateHistory), this);
    if (dataReady.value) {
      page.value = STARTUP_MODE;
    } else {
      dataReady.observeRef(makeOperation(_checkInitDone), this);
    }
  }

  String _makeTitleLine(String appTitle, Data page) {
    String title = '$appTitle \u{2022} ${pageToMode(page).name}';
    if (page is! AppMode && page is Named) {
      title += ' \u{2022} ${(page as Named).name}';
    }
    return title;
  }

  ApplicationView makeAppView() {
    return ApplicationView(mainView, appTitle,
        appVersion: appVersion,
        drawer: drawer,
        buttonIcon: buttonIcon,
        buttonOperation: buttonOperation);
  }

  void updateHistory() {
    if (page.value == null) {
      return;
    }

    if (currentPage > 0 && pageHistory[currentPage - 1] == page.value) {
      return;
    }

    if (currentPage < pageHistory.length) {
      pageHistory.removeRange(currentPage, pageHistory.length);
    }

    pageHistory.add(page.value);
    currentPage = pageHistory.length;
  }

  void backPressed() {
    if (currentPage > 1) {
      --currentPage;
      page.value = pageHistory[currentPage - 1];
    }
  }

  void forwardPressed() {
    if (currentPage < pageHistory.length) {
      ++currentPage;
      page.value = pageHistory[currentPage - 1];
    }
  }

  void _checkInitDone() {
    if (page.value == INITIALIZING_MODE && dataReady.value) {
      page.value = STARTUP_MODE;
    }
  }

  View makePageView(Data page, bool isEditingParameter) {
    if (viewLifespan != null) {
      viewLifespan.dispose();
    }
    viewLifespan = makeSubSpan();

    final styleRecord = global.resolve(NORMAL_STYLE_NAME);
    if (styleRecord != null) {
      ReadRef result = evaluator.evaluateDataOrProcedure(styleRecord, global, viewLifespan);
      if (result.value is Style) {
        normalStyle.value = result.value as Style;
      } else {
        normalStyle.value = defaultNormalStyle;
      }
    } else {
      normalStyle.value = defaultNormalStyle;
    }

    if (page == INITIALIZING_MODE) {
      return initializingView();
    } else if (page == MODULES_MODE) {
      return modulesView(viewLifespan);
    } else if (page == SCHEMA_MODE) {
      return schemaView(viewLifespan);
    } else if (page == PARAMETERS_MODE) {
      return parametersView(viewLifespan);
    } else if (page == OPERATIONS_MODE) {
      return operationsView(viewLifespan);
    } else if (page == PROCEDURES_MODE) {
      return proceduresView(viewLifespan);
    } else if (page == STYLES_MODE) {
      return stylesView(viewLifespan);
    } else if (page == VIEWS_MODE) {
      return viewsView(viewLifespan);
    } else if (page == APP_STATE_MODE) {
      return appStateView(viewLifespan);
    } else if (page == LAUNCH_MODE) {
      return launchView(viewLifespan);
    } else if (isSchemaRecord(page)) {
      return schemaRowView(page as DataRecord);
    } else if (isParameterRecord(page)) {
      return parametersRowView(page as DataRecord);
    } else if (isOperationRecord(page)) {
      return operationsRowView(page as DataRecord);
    } else if (isStyleRecord(page)) {
      return procedureDetailedView(page as ProcedureRecord, viewLifespan);
    } else if (isViewRecord(page)) {
      return procedureDetailedView(page as ProcedureRecord, viewLifespan);
    } else if (isProcedureRecord(page)) {
      return procedureDetailedView(page as ProcedureRecord, viewLifespan);
    } else if (isUserCompositeType(page)) {
      return typeSchemaColumnView(page as UserCompositeType, viewLifespan);
    } else {
      return _showError('Unknown page: $page.');
    }
  }

  View makeMainView(View pageView, bool isEditing) {
    if (page.value == LAUNCH_MODE) {
      return pageView;
    } else {
      return navBar.addChrome(pageView);
    }
  }

  String _newRecordName(String prefix) {
    return global.newRecordName(prefix);
  }

  void _addRecord(CompositeData record) {
    global.addRecord(record);
  }

  Operation makeAppOperation(Data page) {
    if (page is ProcedureRecord) {
      return makeProcedureCopyOperation(page);
    } else if (isUserCompositeType(page)) {
      return makeTypeCopyOperation(page);
    }

    if (page == LAUNCH_MODE) {
      return makeOperation(backPressed);
    }

    if (page is! AppMode) {
      return null;
    }

    return makeAddOperation(page);
  }

  IconId makeAppOperationIcon(Data page) {
    if (page == LAUNCH_MODE) {
      return ARROW_BACK_ICON;
    } else if (page is AppMode) {
      return ADD_ICON;
    } else {
      return CONTENT_COPY_ICON;
    }
  }

  Operation makeAddOperation(AppMode mode) {
    if (mode == SCHEMA_MODE) {
      return makeOperation(() {
        _addRecord(DataRecord(
            APP_STATE_DATATYPE, idSource.nextId(), _newRecordName('data'), STRING_DATATYPE, '?'));
      });
    } else if (mode == PARAMETERS_MODE) {
      return makeOperation(() {
        _addRecord(DataRecord(
            PARAMETER_DATATYPE, idSource.nextId(), _newRecordName('param'), STRING_DATATYPE, '?'));
      });
    } else if (mode == OPERATIONS_MODE) {
      return makeOperation(() {
        _addRecord(DataRecord(
            OPERATION_DATATYPE, idSource.nextId(), _newRecordName('op'), TEMPLATE_DATATYPE, 'foo'));
      });
    } else if (mode == PROCEDURES_MODE) {
      return makeOperation(() {
        ProcedureRecord procedure = ProcedureRecord(
            idSource.nextId(), _newRecordName('proc'), <ArgumentRecord>[], STRING_DATATYPE);
        ExpressionRecord expr = ExpressionRecord(idSource.nextId(), global.resolve('identity'));
        expr.parameters.add(global.resolve('greeting'));
        procedure.body.add(expr);
        _addRecord(procedure);
      });
    } else if (mode == STYLES_MODE) {
      return makeOperation(() {
        ProcedureRecord procedure = ProcedureRecord(
            idSource.nextId(), _newRecordName('style'), <ArgumentRecord>[], STYLE_DATATYPE);
        ExpressionRecord expr =
            ExpressionRecord(idSource.nextId(), global.resolve('new_font_style'));
        expr.parameters.add(16.0);
        expr.parameters.add(BLACK_COLOR);
        procedure.body.add(expr);
        _addRecord(procedure);
      });
    } else if (mode == VIEWS_MODE) {
      return makeOperation(() {
        ProcedureRecord procedure = ProcedureRecord(
            idSource.nextId(), _newRecordName('view'), <ArgumentRecord>[], VIEW_DATATYPE);
        ExpressionRecord expr = ExpressionRecord(idSource.nextId(), global.resolve('new_label'));
        expr.parameters.add(global.resolve('greeting'));
        expr.parameters.add(BODY2_STYLE);
        procedure.body.add(expr);
        _addRecord(procedure);
      });
    } else {
      return null;
    }
  }

  Operation makeProcedureCopyOperation(ProcedureRecord procedure) {
    if (procedure.isNative) {
      return null;
    }

    return makeOperation(() {
      ExpressionRecord copyExpression(ExpressionRecord expression) {
        ExpressionRecord newExpression =
            ExpressionRecord(idSource.nextId(), expression.procedure.value);
        for (Object parameter in expression.parameters.elements) {
          if (parameter is ExpressionRecord) {
            newExpression.parameters.add(copyExpression(parameter));
          } else {
            newExpression.parameters.add(parameter);
          }
        }
        return newExpression;
      }

      String name = _newRecordName(procedure.name);
      List<ArgumentRecord> arguments = <ArgumentRecord>[];
      for (ArgumentRecord argument in procedure.arguments.elements) {
        arguments.add(ArgumentRecord(idSource.nextId(), argument.recordName.value,
            argument.typeId.value, argument.defaultValue.value));
      }
      ProcedureRecord newProcedure =
          ProcedureRecord(idSource.nextId(), name, arguments, procedure.outputType.value);
      assert(procedure.body.size.value == 1);
      ExpressionRecord body = procedure.body.elements[0];
      newProcedure.body.add(copyExpression(body));
      _addRecord(newProcedure);
      page.value = newProcedure;
    });
  }

  Operation makeTypeCopyOperation(UserCompositeType userType) {
    return makeOperation(() {
      String name = global.newTypeName(userType.name);
      UserCompositeType newType = UserCompositeType(CREATE_NAMESPACE, name);
      for (FieldInfo field in userType.fields.elements) {
        newType.fields.add(FieldInfo(field.name.value, field.type.value));
      }
      global.dataTypes.add(newType);
      page.value = newType;
    });
  }

  View initializingView() {
    return LabelView(Constant<String>("Initial sync in progress..."), normalStyle);
  }

  View modulesView(Lifespan lifespan) {
    return ColumnView(MappedList<SubDatastore<CompositeData>, View>(
        multiplexStore.substores, modulesRowView, lifespan));
  }

  View modulesRowView(SubDatastore<CompositeData> substore) {
    return RowView(ImmutableList<View>(
        [BooleanInput(substore.active), LabelView(substore.name, normalStyle)]));
  }

  View schemaView(Lifespan lifespan) {
    JoinedList<View> rows = JoinedList<View>(lifespan);

    rows.addList(
        MappedList<DataRecord, View>(global.getAppState(lifespan), schemaRowView, lifespan));

    List<UserCompositeType> types = List<UserCompositeType>.of(
        global.dataTypes.where(isUserCompositeType).cast<UserCompositeType>());
    ReadList<UserCompositeType> dataTypes = BaseMutableList<UserCompositeType>(types);
    rows.addList(MappedList<UserCompositeType, View>(dataTypes, typeSchemaRowView, lifespan));

    return ColumnView(rows);
  }

  View makeSelectionInput<T>(
      Ref<T> current, ReadList<T> options, SelectDisplayFunction<T> display, bool sort) {
    if (isEditing.value) {
      // TODO: use deep equals comparison instead of comparing string represetantions
      String currentName = display(current.value);
      bool hasSameName(T value) => display(value) == currentName && value != current.value;

      List<T> optionsElements = options.elements.cast<T>();
      if (optionsElements.any(hasSameName)) {
        options =
            ImmutableList<T>(optionsElements.where((T value) => !hasSameName(value)).toList());
      }

      return SelectionInput<T>(current, options, display, sort, normalStyle);
    } else {
      T value = current.value;
      if (value is NamedRecord) {
        return linkView(Constant<String>(display(value)), value);
      } else {
        return LabelView(Constant<String>(display(value)), normalStyle);
      }
    }
  }

  View makeTextInput(Ref<String> value) {
    if (isEditing.value) {
      return TextInput(value, normalStyle);
    } else {
      return LabelView(value, normalStyle);
    }
  }

  View makePrimitiveTypeInput(Ref<DataType> typeId) {
    return makeSelectionInput<DataType>(typeId, ImmutableList<DataType>(PRIMITIVE_TYPES),
        displayName('<no primitive type>'), false);
  }

  View nameInput(Ref<String> recordName, CompositeData data) {
    if (isEditing.value) {
      return makeTextInput(recordName);
    } else if (data != page.value) {
      return linkView(recordName, data);
    } else {
      return LabelView(recordName, normalStyle);
    }
  }

  View linkView(ReadRef<String> recordName, Data data) {
    return LinkView(
        recordName, Constant<Operation>(makeOperation(() => page.value = data)), normalStyle);
  }

  View schemaRowView(DataRecord record) {
    return RowView(ImmutableList<View>([
      nameInput(record.recordName, record),
      LabelView(RIGHT_ARROW, normalStyle),
      makePrimitiveTypeInput(record.typeId)
    ]));
  }

  View typeSchemaRowView(UserCompositeType dataType) {
    MutableList<View> columns = BaseMutableList<View>();
    columns.add(linkView(Constant<String>(dataType.name), dataType));
    columns.add(LabelView(RIGHT_ARROW, normalStyle));
    columns.add(LabelView(LEFT_BRACE, normalStyle));

    List<FieldInfo> fields = dataType.fields.elements;
    for (int i = 0; i < fields.length; ++i) {
      if (i > 0) {
        columns.add(LabelView(COMMA, normalStyle));
      }
      columns.add(LabelView(fields[i].name, normalStyle));
    }

    columns.add(LabelView(RIGHT_BRACE, normalStyle));

    return RowView(columns);
  }

  View typeSchemaColumnView(UserCompositeType dataType, Lifespan lifespan) {
    JoinedList<View> rows = JoinedList<View>(lifespan);
    View typeName = LabelView(Constant<String>(dataType.name), normalStyle);
    ImmutableList<View> topLine =
        ImmutableList<View>([typeName, LabelView(LEFT_BRACE, normalStyle)]);
    rows.addConstant(RowView(topLine));

    View makeFieldRow(FieldInfo fieldInfo) {
      ImmutableList<View> fieldLine = ImmutableList<View>([
        glue24,
        makeTextInput(fieldInfo.name),
        LabelView(RIGHT_ARROW, normalStyle),
        makeDataTypeInput(fieldInfo.type, !isEditing.value, '<no field type>')
      ]);
      return RowView(fieldLine);
    }

    ReadList<View> fieldsView =
        MappedList<FieldInfo, View>(dataType.fields, makeFieldRow, lifespan);
    rows.addList(fieldsView);

    if (isEditing.value) {
      JoinedList<View> iconsLine = JoinedList<View>(lifespan);
      iconsLine.addConstant(glue24);
      iconsLine.addList(listIcons<FieldInfo>(
          dataType.fields, 1, () => FieldInfo('name', STRING_DATATYPE), lifespan));
      rows.addConstant(RowView(iconsLine));
    }

    rows.addConstant(LabelView(RIGHT_BRACE, normalStyle));

    return ColumnView(rows);
  }

  View parametersView(Lifespan lifespan) {
    return ColumnView(
        MappedList<DataRecord, View>(global.getParameters(lifespan), parametersRowView, lifespan));
  }

  View parametersRowView(DataRecord record) {
    return RowView(ImmutableList<View>([
      nameInput(record.recordName, record),
      LabelView(RIGHT_ARROW, normalStyle),
      makePrimitiveTypeInput(record.typeId),
      glue12,
      makeTextInput(record.state)
    ]));
  }

  View operationsView(Lifespan lifespan) {
    return ColumnView(
        MappedList<DataRecord, View>(global.getOperations(lifespan), operationsRowView, lifespan));
  }

  View operationsRowView(DataRecord record) {
    return RowView(ImmutableList<View>([
      nameInput(record.recordName, record),
      LabelView(RIGHT_ARROW, normalStyle),
      makeSelectionInput<DataType>(record.typeId, ImmutableList<DataType>(OPERATION_TYPES),
          displayName('<no operation type>'), false),
      glue12,
      makeTextInput(record.state)
    ]));
  }

  View proceduresView(Lifespan lifespan) {
    return ColumnView(MappedList<ProcedureRecord, View>(global.getProcedureRecords(lifespan),
        (proc) => proceduresRowView(proc, lifespan), lifespan));
  }

  View makeDataTypeLabel(Ref<DataType> dataType, String nullName) {
    String name = dataType.value != null ? dataType.value.toString() : nullName;
    return LabelView(Constant<String>(name), normalStyle);
  }

  View makeDataTypeInput(Ref<DataType> dataType, bool isLabel, String nullName) {
    if (isLabel) {
      // TODO(dynin): merge with makeSelectionInput code
      ReadRef<String> name = Constant<String>(displayName(nullName)(dataType.value));
      if (isUserCompositeType(dataType.value)) {
        return linkView(name, dataType.value);
      } else {
        return LabelView(name, normalStyle);
      }
    } else {
      return makeSelectionInput<DataType>(
          dataType, ImmutableList<DataType>(allCreateTypes), displayName(nullName), true);
    }
  }

  View proceduresRowView(ProcedureRecord procedure, Lifespan lifespan) {
    MutableList<View> columns = BaseMutableList<View>();
    columns.add(linkView(procedure.recordName, procedure));

    final MutableList<ArgumentRecord> arguments = procedure.arguments;

    columns.add(LabelView(LEFT_PAREN, normalStyle));

    for (int i = 0; i < arguments.size.value; ++i) {
      if (i > 0) {
        columns.add(LabelView(COMMA, normalStyle));
      }
      columns.add(makeDataTypeLabel(arguments.at(i).value.typeId, '<no input type>'));
    }

    columns.add(LabelView(RIGHT_PAREN, normalStyle));

    columns.add(LabelView(RIGHT_ARROW, normalStyle));
    columns.add(makeDataTypeLabel(procedure.outputType, '<no output type>'));

    return RowView(columns);
  }

  View procedureDetailedView(ProcedureRecord procedure, Lifespan lifespan) {
    if (procedure.isNative) {
      View procedureRow = proceduresRowView(procedure, lifespan);
      View callersRow = renderCallersRow(procedure);
      if (callersRow != null) {
        return ColumnView(ImmutableList<View>(<View>[procedureRow, callersRow]));
      } else {
        return procedureRow;
      }
    }

    MutableList<View> rows = BaseMutableList<View>();

    Operation updateOp;

    void updateResult() {
      rows.clear();
      populateProcedureView(procedure, rows, updateOp, lifespan);
    }

    updateOp = makeOperation(updateResult);

    populateProcedureView(procedure, rows, updateOp, lifespan);

    return ColumnView(rows);
  }

  void populateProcedureView(
      ProcedureRecord procedure, MutableList<View> rows, Operation updateOp, Lifespan lifespan) {
    View procName = makeTextInput(procedure.recordName);
    ImmutableList<View> topLine =
        ImmutableList<View>([procName, LabelView(LEFT_PAREN, normalStyle)]);
    rows.add(RowView(topLine));

    final MutableList<ArgumentRecord> arguments = procedure.arguments;
    arguments.observe(updateOp, lifespan);

    ArgumentRecord newArgument() =>
        ArgumentRecord(idSource.nextId(), argumentName(arguments.size.value), VOID_DATATYPE, null);

    ReadList<View> renderArguments(MutableList<ArgumentRecord> arguments) {
      MutableList<View> views = BaseMutableList<View>();

      for (int i = 0; i < arguments.size.value; ++i) {
        ArgumentRecord argument = arguments.at(i).value;
        ImmutableList<View> argumentLine = ImmutableList<View>([
          glue24,
          makeTextInput(argument.recordName),
          LabelView(RIGHT_ARROW, normalStyle),
          makeDataTypeInput(argument.typeId, !isEditing.value, '<no input type>')
        ]);
        views.add(RowView(argumentLine));
      }

      if (isEditing.value) {
        JoinedList<View> iconsLine = JoinedList<View>(lifespan);
        iconsLine.addConstant(GlueView(Constant<double>(32.0)));
        iconsLine.addList(listIcons<ArgumentRecord>(arguments, 0, newArgument, lifespan));
        views.add(RowView(iconsLine));
      }

      return views;
    }

    ReadList<View> argumentsView =
        ReactiveListFunction<ArgumentRecord, View>(arguments, renderArguments, lifespan);
    rows.add(ColumnView(argumentsView));

    ImmutableList<View> outputLine = ImmutableList<View>([
      LabelView(RIGHT_PAREN, normalStyle),
      LabelView(RIGHT_ARROW, normalStyle),
      makeDataTypeInput(procedure.outputType, !isEditing.value, '<no output type>')
    ]);
    rows.add(RowView(outputLine));
    procedure.outputType.observeRef(updateOp, lifespan);

    LocalContext bodyContext = LocalContext(global, procedure.name);
    for (int i = 0; i < arguments.size.value; ++i) {
      ArgumentRecord argument = arguments.at(i).value;
      String name = argument.recordName.value;
      DataType type = argument.typeId.value;
      if (type == VOID_DATATYPE) {
        continue;
      }
      ReferenceRecord argumentReference = ReferenceRecord(idSource.nextId(), name, type);
      bodyContext.addReference(argumentReference);
      if (type is CompositeDataType) {
        ListFields listFields = ListFields(idSource, argumentReference);
        type.newInstance(idSource.nextId()).visit(listFields);
        // TODO: use foreach
        for (FieldRecord field in listFields.fields) {
          bodyContext.addField(field);
        }
      }
    }

    rows.add(LabelView(Constant<String>('{'), normalStyle));
    for (ExpressionRecord expr in procedure.body.elements) {
      rows.add(expressionView(expr, bodyContext, updateOp, lifespan));
    }
    procedure.body.observe(updateOp, lifespan);
    rows.add(LabelView(Constant<String>('}'), normalStyle));

    View callersRow = renderCallersRow(procedure);
    if (callersRow != null) {
      rows.add(callersRow);
    }
  }

  View renderCallersRow(ProcedureRecord procedure) {
    ReadList<ProcedureRecord> callers = _getCallers(procedure);
    if (callers.size.value == 0) {
      return null;
    }

    List<View> callersLine = <View>[];
    callersLine.add(LabelView(Constant<String>('\u{2B90}'), normalStyle));
    for (ProcedureRecord caller in callers.elements) {
      callersLine.add(glue12);
      callersLine.add(linkView(caller.recordName, caller));
    }
    return RowView(ImmutableList<View>(callersLine));
  }

  ReadList<ProcedureRecord> _getCallers(ProcedureRecord procedure) {
    bool matchesExpression(ExpressionRecord expression) {
      if (expression.procedure.value == procedure) {
        return true;
      }

      for (Object parameter in expression.parameters.elements) {
        if (parameter == procedure) {
          return true;
        }
        if (parameter is ExpressionRecord && matchesExpression(parameter)) {
          return true;
        }
      }

      return false;
    }

    bool doesCall(CompositeData data) {
      if (data is ProcedureRecord) {
        ReadList<ExpressionRecord> body = data.body;
        for (ExpressionRecord expression in body.elements) {
          if (matchesExpression(expression)) {
            return true;
          }
        }
      }

      return false;
    }

    return global._runQuery(doesCall, null).cast<ProcedureRecord>();
  }

  ReadList<View> listIcons<T>(MutableList<T> list, int minSize, T newValue(), Lifespan lifespan) {
    JoinedList<View> result = JoinedList<View>(lifespan);

    void add() {
      list.add(newValue());
    }

    result.addConstant(IconButtonView(
        Constant<IconId>(ADD_CIRCLE_ICON), null, Constant<Operation>(makeOperation(add))));

    void remove() {
      if (list.size.value > 0) {
        list.removeAt(list.size.value - 1);
      }
    }

    View removeIconView(int size) {
      if (size > minSize) {
        return IconButtonView(
            Constant<IconId>(REMOVE_CIRCLE_ICON), null, Constant<Operation>(makeOperation(remove)));
      } else {
        return null;
      }
    }

    ReadRef<View> removeIconOrNull =
        ReactiveFunction<int, View>(list.size, removeIconView, lifespan);
    result.add(removeIconOrNull);

    return result;
  }

  View expressionView(ExpressionRecord expression, EvaluationContext context, Operation updateOp,
      Lifespan lifespan) {
    JoinedList<View> topLine = JoinedList<View>(lifespan);
    topLine.addConstant(glue24);
    topLine.addConstant(makeProcedureSelect(expression.procedure, lifespan));
    topLine.addConstant(LabelView(LEFT_PAREN, normalStyle));

    JoinedList<View> rows = JoinedList<View>(lifespan);
    rows.addConstant(RowView(topLine));

    ReadList<ArgumentRecord> arguments = expression.procedure.value.arguments;
    MutableList<Object> parameters = expression.parameters;

    expression.procedure.observeRef(updateOp, lifespan);
    expression.parameters.observe(updateOp, lifespan);

    if (parameters.size.value < arguments.size.value) {
      for (int index = parameters.size.value; index < arguments.size.value; ++index) {
        parameters.add(null);
      }
    }

    View toParameterView(Ref<Object> data, int index) {
      ArgumentRecord argument;
      if (index < arguments.size.value) {
        argument = arguments.elements[index];
      }

      View nameView = LabelView(
          argument != null ? argument.recordName : Constant<String>(argumentName(index)),
          normalStyle);

      View valueView;
      if (isEditing.value) {
        valueView = makeTypedInput(data, argument != null ? argument.typeId.value : null,
            argument != null ? argument.recordName.value : null, context, lifespan);
      } else {
        valueView = makeDataView(data.value);
      }

      return RowView(ImmutableList<View>(
          [glue48, nameView, LabelView(Constant<String>(' : '), normalStyle), valueView]));
    }

    ReadList<View> parametersView =
        MappedWithIndexList<Object, View>(parameters, toParameterView, lifespan);
    rows.addList(parametersView);

    if (isEditing.value) {
      JoinedList<View> icons = JoinedList<View>(lifespan);
      icons.addConstant(glue48);
      icons.addList(listIcons<Object>(parameters, arguments.size.value, () => null, lifespan));
      rows.addConstant(RowView(icons));
    }

    rows.addConstant(RowView(ImmutableList<View>([glue24, LabelView(RIGHT_PAREN, normalStyle)])));
    return ColumnView(rows);
  }

  View expressionLineView(
      ExpressionRecord expression, EvaluationContext context, Lifespan lifespan) {
    MutableList<View> columns = BaseMutableList<View>();
    columns.add(makeProcedureSelect(expression.procedure, lifespan));
    columns.add(LabelView(LEFT_PAREN, normalStyle));

    ReadList<ArgumentRecord> arguments = expression.procedure.value.arguments;
    MutableList<Object> parameters = expression.parameters;

    for (int index = 0; index < parameters.size.value; ++index) {
      ArgumentRecord argument;
      if (index < arguments.size.value) {
        argument = arguments.elements[index];
      }

      View valueView = makeTypedInput(
          parameters.at(index),
          argument != null ? argument.typeId.value : null,
          argument != null ? argument.recordName.value : null,
          context,
          lifespan);

      if (index > 0) {
        columns.add(LabelView(COMMA, normalStyle));
      }
      columns.add(valueView);
    }
    columns.add(LabelView(RIGHT_PAREN, normalStyle));

    return RowView(columns);
  }

  View makeProcedureSelect(Ref<ProcedureRecord> procedure, Lifespan lifespan) {
    ReadList<ProcedureRecord> procedures = global.getProcedureRecords(null);
    return makeSelectionInput<ProcedureRecord>(
        procedure, procedures, displayName('<no procedure>'), true);
  }

  bool _isOfType(CompositeData data, DataType type) {
    if (data is DataRecord) {
      return data.typeId.value == type;
    } else if (data is ReferenceRecord) {
      return data.typeId.value == type;
    } else if (data is FieldRecord) {
      return data.typeId.value == type;
    } else if (data is ProcedureRecord) {
      return data.hasNoArguments && data.outputType.value == type;
    } else {
      return false;
    }
  }

  bool _isStringType(CompositeData data) {
    return _isOfType(data, STRING_DATATYPE);
  }

  bool _isListType(CompositeData data) {
    return _isOfType(data, LIST_DATATYPE);
  }

  View makeTypedInput(Ref<Object> dataRef, DataType type, String name, EvaluationContext context,
      Lifespan lifespan) {
    if (dataRef.value is ExpressionRecord) {
      return expressionLineView(dataRef.value, context, lifespan);
    } else if (type is EnumDataType) {
      List<Data> enumOptions = [null];
      enumOptions.addAll(type.values);
      return makeSelectionInput<Data>(dataRef.cast<Data>(), ImmutableList<Data>(enumOptions),
          displayString('<no data>'), false);
    } else if (type == REAL_DATATYPE) {
      return makeSelectionInput<Object>(
          dataRef,
          ImmutableList<Object>(name == FONT_SIZE_FIELD ? FONT_SIZES : REAL_OPTIONS),
          displayString('<no real>'),
          false);
    } else if (type == INTEGER_DATATYPE) {
      return makeSelectionInput<Object>(
          dataRef, ImmutableList<Object>(INTEGER_OPTIONS), displayString('<no integer>'), false);
    } else if (type == BOOLEAN_DATATYPE) {
      return makeSelectionInput<Object>(
          dataRef, ImmutableList<Object>(BOOLEAN_OPTIONS), displayString('<no boolean>'), false);
    } else if (type == STRING_DATATYPE) {
      if (name == RECORD_NAME_FIELD) {
        if (dataRef.value is! String) {
          dataRef.value = '';
        }
        return TextInput(dataRef.cast<String>(), normalStyle);
      } else {
        ReadList<Data> records = context.where(_isStringType).cast<Data>();
        return makeSelectionInput<Data>(
            dataRef.cast<Data>(), records, displayString('<no string>'), true);
      }
    } else if (type == STYLE_DATATYPE) {
      return makeStyleInput(dataRef.cast<Data>(), context, lifespan);
    } else if (type == LIST_DATATYPE) {
      ReadList<Data> records = context.where(_isListType).cast<Data>();
      return makeSelectionInput<Data>(
          dataRef.cast<Data>(), records, displayString('<no list>'), true);
    } else {
      ReadList<Object> records = context.where((record) => record is Named).cast<Object>();
      return makeSelectionInput<Object>(dataRef, records, displayString('<no data>'), true);
    }
  }

  View makeExpressionView(ExpressionRecord expr) {
    List<View> columns = <View>[];
    columns.add(makeDataView(expr.procedure.value));
    columns.add(LabelView(LEFT_PAREN, normalStyle));

    for (int i = 0; i < expr.parameters.size.value; ++i) {
      if (i > 0) {
        columns.add(LabelView(COMMA, normalStyle));
      }
      columns.add(makeDataView(expr.parameters.at(i).value));
    }
    columns.add(LabelView(RIGHT_PAREN, normalStyle));

    return RowView(ImmutableList<View>(columns));
  }

  View makeDataView(Object data) {
    if (data is ReferenceRecord) {
      return LabelView(data.recordName, normalStyle);
    } else if (data is NamedRecord) {
      return linkView(data.recordName, data);
    } else if (data is Named) {
      return LabelView(Constant<String>(data.toString()), normalStyle);
    } else if (data is double || data is int || data is bool) {
      return LabelView(Constant<String>(data.toString()), normalStyle);
    } else if (data is ExpressionRecord) {
      return makeExpressionView(data);
    } else if (data is List) {
      return LabelView(Constant<String>('[...]'), normalStyle);
    } else if (data == null) {
      return LabelView(Constant<String>('<null data>'), normalStyle);
    } else {
      return LabelView(Constant<String>('$data?'), normalStyle);
    }
  }

  View stylesView(Lifespan lifespan) {
    return ColumnView(MappedList<ProcedureRecord, View>(
        global.getStyles(lifespan), (proc) => proceduresRowView(proc, lifespan), lifespan));
  }

  View viewsView(Lifespan lifespan) {
    return ColumnView(MappedList<ProcedureRecord, View>(
        global.getViews(lifespan), (proc) => proceduresRowView(proc, lifespan), lifespan));
  }

  View makeStyleInput(Ref<Data> style, EvaluationContext context, Lifespan lifespan) {
    // TODO: add generic displayer with a specified null string
    String displayStyle(dynamic s) {
      if (s == null) {
        return '<no style>';
      } else if (s is Named) {
        return s.toString();
      } else {
        return '<other style>';
      }
    }

    List<Data> styleOptions = [null];
    styleOptions.addAll(context.where(isStyleRecord).elements);
    styleOptions.addAll(THEMED_STYLE_DATATYPE.values);
    return makeSelectionInput<Data>(style, ImmutableList<Data>(styleOptions), displayStyle, true);
  }

  View makeContentInput(Ref<DataRecord> content, Lifespan lifespan) {
    return makeSelectionInput<DataRecord>(
        content, global.getContentOptions(null), displayString('<no content>'), true);
  }

  View makeActionInput(Ref<DataRecord> action, Lifespan lifespan) {
    return makeSelectionInput<DataRecord>(
        action, global.getActionOptions(null), displayString('<no action>'), true);
  }

  View appStateView(Lifespan lifespan) {
    return ColumnView(
        MappedList<DataRecord, View>(global.getAppState(lifespan), appStateRowView, lifespan));
  }

  View appStateRowView(DataRecord record) {
    return RowView(ImmutableList<View>([
      nameInput(record.recordName, record),
      LabelView(RIGHT_ARROW, normalStyle),
      LabelView(Constant<String>(record.typeId.value.name), normalStyle),
      glue12,
      // TODO: switch to the number keyboard
      makeTextInput(record.state)
    ]));
  }

  View _showError(String message) {
    return LabelView(Constant<String>(message), normalStyle);
  }

  View launchView(Lifespan lifespan) {
    CompositeData mainRecord = global.resolve(MAIN_NAME);

    if (mainRecord == null) {
      return _showError('Main view not found.');
    }

    ReadRef mainRef = evaluator.evaluateDataOrProcedure(mainRecord, global, lifespan);
    if (mainRef == null) {
      return _showError('Main evaluates to null.');
    }

    global.observeState(zone.makeOperation(pageView.recompute), lifespan);

    if (mainRef.value is View) {
      return mainRef.value as View;
    }

    if (mainRef.value is String) {
      return LabelView(mainRef, normalStyle);
    }

    return _showError('Main evaluates to ${mainRef.value}');
  }

  DrawerView makeDrawer() {
    bool detailedDrawer = false;

    List<View> items = [];
    if (detailedDrawer) {
      items.add(HeaderView(Constant<String>('Create! v' + CREATE_VERSION)));
    }
    items.addAll(DRAWER_MODES.map(_modeItem));
    if (detailedDrawer) {
      items.add(DividerView());
      items.add(ItemView(Constant<String>('Help & Feedback'), Constant<IconId>(HELP_ICON),
          Constant<bool>(false), null));
    }

    return DrawerView(ImmutableList<View>(items));
  }

  ItemView _modeItem(AppMode mode) {
    return ItemView(Constant<String>(mode.name), Constant<IconId>(mode.icon),
        Constant<bool>(appMode.value == mode), Constant<Operation>(makeOperation(() {
      page.value = mode;
    })));
  }
}

class CreateContext implements EvaluationContext {
  final Datastore<CompositeData> _datastore;

  CreateContext(this._datastore);

  Set<DataType> get dataTypes => _datastore.dataTypes;

  @override
  CompositeData resolve(String name) {
    ImmutableList<CompositeData> results = _datastore.runQuerySync(NamedQuery<CompositeData>(name));
    if (results.size.value == 0) {
      return null;
    }

    if (results.size.value > 1) {
      // TODO: throw an exception?
      print('Duplicate element in resolve() for $name');
    }

    return results.elements.first;
  }

  @override
  ImmutableList<CompositeData> where(RawQuery<CompositeData> query) {
    return _datastore.runQuerySync(BaseQuery<CompositeData>(query));
  }

  @override
  ReadRef dereference(ReferenceRecord reference) => null;

  void observeState(Operation observer, Lifespan lifespan) {
    (_datastore as InMemoryDatastore).observeState(observer, lifespan);
  }

  void addRecord(CompositeData record) {
    return _datastore.add(record);
  }

  ReadList<CompositeData> _runQuery(RawQuery<CompositeData> query, Lifespan lifespan) {
    return _datastore.runQuery(BaseQuery<CompositeData>(query), lifespan, DEFAULT_PRIORITY);
  }

  ReadList<DataRecord> getDataRecords(CompositeDataType dataType, Lifespan lifespan) =>
      _runQuery((CompositeData record) => record.dataType == dataType, lifespan).cast<DataRecord>();

  ReadList<DataRecord> getAppState(Lifespan lifespan) =>
      getDataRecords(APP_STATE_DATATYPE, lifespan);

  ReadList<DataRecord> getParameters(Lifespan lifespan) =>
      getDataRecords(PARAMETER_DATATYPE, lifespan);

  ReadList<DataRecord> getOperations(Lifespan lifespan) =>
      getDataRecords(OPERATION_DATATYPE, lifespan);

  ReadList<ProcedureRecord> getProcedureRecords(Lifespan lifespan) =>
      _runQuery((record) => record is ProcedureRecord, lifespan).cast<ProcedureRecord>();

  ReadList<ProcedureRecord> getStyles(Lifespan lifespan) =>
      _runQuery(isStyleRecord, lifespan).cast<ProcedureRecord>();

  ReadList<ProcedureRecord> getViews(Lifespan lifespan) =>
      _runQuery(isViewRecord, lifespan).cast<ProcedureRecord>();

  ReadList<DataRecord> getContentOptions(Lifespan lifespan) => _runQuery(
          (record) =>
              record is DataRecord &&
              (record.typeId.value == STRING_DATATYPE || record.typeId.value == TEMPLATE_DATATYPE),
          lifespan)
      .cast<DataRecord>();

  ReadList<DataRecord> getActionOptions(Lifespan lifespan) => _runQuery(
          (record) => record is DataRecord && record.typeId.value == INLINE_DATATYPE, lifespan)
      .cast<DataRecord>();

  String newRecordName(String prefix) {
    if (resolve(prefix) == null) {
      return prefix;
    }

    int index = 2;
    while (resolve(prefix + index.toString()) != null) {
      ++index;
    }
    return prefix + index.toString();
  }

  String newTypeName(String prefix) {
    bool _hasType(name) => dataTypes.any((type) => type.name == name);

    if (!_hasType(prefix)) {
      return prefix;
    }

    int index = 2;
    while (_hasType(prefix + index.toString())) {
      ++index;
    }
    return prefix + index.toString();
  }

  @override
  toString() => '[global context]';
}
