// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import '../../elements.dart';
import '../../datastore.dart';
import '../../views.dart';

import 'createdata.dart';

abstract class ProcedureEvaluator {
  Zone get zone;
  ReadRef evaluateProcedure(ProcedureRecord proc, List<ReadRef> arguments, Lifespan lifespan);
  void executeAction(String action);
}

typedef ReadRef NativeProcedure(List<ReadRef> arguments, Lifespan lifespan);

class DelayedProcedure {
  final ProcedureRecord procedure;
  final List<ReadRef> arguments;
  final Lifespan lifespan;

  DelayedProcedure(this.procedure, this.arguments, this.lifespan);

  ReadRef call(ProcedureEvaluator evaluator) {
    return evaluator.evaluateProcedure(procedure, arguments, lifespan);
  }
}

const CONSTRUCTOR_PREFIX = 'new_';

class _ArgumentMaker implements FieldVisitor {
  final DataIdSource ids;
  final List<ArgumentRecord> arguments;

  _ArgumentMaker(this.ids, this.arguments);

  void stringField(String fieldName, Ref<String> field) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, STRING_DATATYPE, ''));

  void boolField(String fieldName, Ref<bool> field) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, BOOLEAN_DATATYPE, 'false'));

  void intField(String fieldName, Ref<int> field) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, INTEGER_DATATYPE, '0'));

  void doubleField(String fieldName, Ref<double> field) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, REAL_DATATYPE, '0.0'));

  void dataField(String fieldName, Ref<Data> field, DataType dataType) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, dataType, null));

  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      arguments.add(ArgumentRecord(ids.nextId(), fieldName, LIST_DATATYPE, null));
}

class _SetFields implements FieldVisitor {
  final List<ReadRef> arguments;
  int index = 0;

  _SetFields(this.arguments);

  void stringField(String fieldName, Ref<String> field) =>
      field.value = arguments[index++].value as String;
  void boolField(String fieldName, Ref<bool> field) =>
      field.value = arguments[index++].value as bool;
  void intField(String fieldName, Ref<int> field) => field.value = arguments[index++].value as int;
  void doubleField(String fieldName, Ref<double> field) =>
      field.value = arguments[index++].value as double;
  void dataField(String fieldName, Ref<Data> field, DataType dataType) =>
      field.value = arguments[index++].value as Data;

  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      field.replaceWith(arguments[index++].value as List<dynamic>);
}

class ProcedureLibrary {
  Map<String, NativeProcedure> nativeProcedures = HashMap<String, NativeProcedure>();
  Datastore datastore;
  ProcedureEvaluator evaluator;
  Zone get zone => evaluator.zone;

  void setDatastore(Datastore datastore) {
    this.datastore = datastore;
  }

  void setEvaluator(ProcedureEvaluator evaluator) {
    this.evaluator = evaluator;
  }

  List<ProcedureRecord> builtinProcedures(DataIdSource ids) {
    return <ProcedureRecord>[
      _procedure(ids, 'identity', executeIdentity, <DataType>[ANY_DATATYPE], ANY_DATATYPE),
      _procedureNamed(ids, 'flip', executeFlip, <DataType>[BOOLEAN_DATATYPE], <String>['bit'],
          BOOLEAN_DATATYPE),
      _procedureNamed(
          ids,
          'if',
          withObserver(executeIf, 'if'),
          <DataType>[BOOLEAN_DATATYPE, ANY_DATATYPE, ANY_DATATYPE],
          <String>['condition', 'then', 'else'],
          ANY_DATATYPE),
      _procedure(ids, 'list', executeList, <DataType>[ANY_DATATYPE], LIST_DATATYPE),
      _procedureNamed(ids, 'call', executeCall, <DataType>[PROCEDURE_DATATYPE, ANY_DATATYPE],
          <String>['function', 'argument'], ANY_DATATYPE),
      _procedureNamed(ids, 'map', executeMap, <DataType>[LIST_DATATYPE, PROCEDURE_DATATYPE],
          <String>['list', 'function'], LIST_DATATYPE),
      _procedure(ids, 'concatenate', executeConcatenate,
          <DataType>[STRING_DATATYPE, STRING_DATATYPE], STRING_DATATYPE),
      _procedureNamed(
          ids, 'all', executeAll, <DataType>[TYPE_ID_DATATYPE], <String>['type'], LIST_DATATYPE),
      _procedureNamed(ids, 'new_label', executeNewLabel,
          <DataType>[STRING_DATATYPE, STYLE_DATATYPE], <String>['text', 'style'], VIEW_DATATYPE),
      // TODO: make this VIEW_DATATYPE or STYLE_DATATYPE or LIST_DATATYPE.
      _procedure(ids, 'new_row', withObserver(executeNewRow, 'new_row'), <DataType>[ANY_DATATYPE],
          VIEW_DATATYPE),
      _procedure(ids, 'new_column', executeNewColumn, <DataType>[ANY_DATATYPE], VIEW_DATATYPE),
      _procedureNamed(
          ids,
          'new_button',
          executeNewButton,
          <DataType>[STRING_DATATYPE, STYLE_DATATYPE, OPERATION_DATATYPE],
          <String>['text', 'style', 'action'],
          VIEW_DATATYPE),
      _procedure(ids, 'new_container', executeNewContainer,
          <DataType>[VIEW_DATATYPE, STYLE_DATATYPE], VIEW_DATATYPE),
      _procedure(ids, 'new_divider', executeNewDivider, <DataType>[REAL_DATATYPE], VIEW_DATATYPE),
      _procedureNamed(ids, 'new_action', withObserver(executeNewAction, 'new_action'),
          <DataType>[VIEW_DATATYPE, OPERATION_DATATYPE], <String>['view', 'action'], VIEW_DATATYPE),
    ];
  }

  _procedure(DataIdSource ids, String name, NativeProcedure executor, List<DataType> argumentTypes,
      DataType outputType) {
    nativeProcedures[name] = executor;

    List<ArgumentRecord> arguments = List<ArgumentRecord>();
    for (int i = 0; i < argumentTypes.length; ++i) {
      arguments.add(ArgumentRecord(ids.nextId(), argumentName(i), argumentTypes[i], null));
    }

    return ProcedureRecord(ids.nextId(), name, arguments, outputType);
  }

  _procedureNamed(DataIdSource ids, String name, NativeProcedure executor,
      List<DataType> argumentTypes, List<String> argumentNames, DataType outputType) {
    nativeProcedures[name] = executor;

    assert(argumentTypes.length == argumentNames.length);
    List<ArgumentRecord> arguments = List<ArgumentRecord>();
    for (int i = 0; i < argumentTypes.length; ++i) {
      arguments.add(ArgumentRecord(ids.nextId(), argumentNames[i], argumentTypes[i], null));
    }

    return ProcedureRecord(ids.nextId(), name, arguments, outputType);
  }

  ProcedureRecord constructorProcedure(DataIdSource ids, CompositeDataType dataType) {
    String name = CONSTRUCTOR_PREFIX + dataType.name;

    ReadRef executeConstructor(List<ReadRef> arguments, Lifespan lifespan) {
      CompositeData result = dataType.newInstance(null);
      result.visit(_SetFields(arguments));
      return Constant<CompositeData>(result);
    }

    nativeProcedures[name] = executeConstructor;

    _ArgumentMaker argumentMaker = _ArgumentMaker(ids, <ArgumentRecord>[]);
    dataType.newInstance(ids.nextId()).visit(argumentMaker);
    return ProcedureRecord(ids.nextId(), name, argumentMaker.arguments, dataType);
  }

  ReadRef executeNative(ProcedureRecord proc, List<ReadRef> arguments, Lifespan lifespan) {
    NativeProcedure executor = nativeProcedures[proc.name];

    if (executor == null) {
      return newError('Unknown native procedure ${proc.name}');
    }

    return executor(arguments, lifespan);
  }

  NativeProcedure withObserver(NativeProcedure procedure, String name) {
    ReadRef execute(List<ReadRef> arguments, Lifespan lifespan) {
      Ref<Object> result = Boxed<Object>();

      void update() {
        result.value = procedure(arguments, lifespan).value;
        // print('calling $name: ${result.value}');
      }

      update();
      Operation updateOp = zone.makeOperation(update);
      _deepObserveList(arguments, updateOp, lifespan);

      return result;
    }

    return execute;
  }

  _deepObserveList(List<ReadRef> refList, Operation updated, Lifespan lifespan) {
    for (ReadRef ref in refList) {
      ref.observeDeep(updated, lifespan);
    }
  }

  ReadRef newError(String message) {
    print('Error: $message');
    return Constant<String>('Error: $message');
  }

  ReadRef executeIdentity(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 1) {
      return newError('identity() expected 1 argument, got ${arguments.length}');
    }

    return arguments[0];
  }

  ReadRef executeFlip(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 1) {
      return newError('flip() expected 1 argument, got ${arguments.length}');
    }

    if (arguments[0].value is! bool) {
      return newError('flip() argument #1 expected to be bool');
    }

    Ref<bool> bit = arguments[0] as Ref<bool>;
    bit.value = !bit.value;

    return bit;
  }

  ReadRef executeIf(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length != 2 && arguments.length != 3) {
      return newError('if expected 2-3 argument, got ${arguments.length}');
    }

    if (arguments[0].value == true) {
      return arguments[1];
    } else {
      return arguments.length == 3 ? arguments[2] : Constant<Object>(null);
    }
  }

  ReadRef executeConcatenate(List<ReadRef> arguments, Lifespan lifespan) {
    StringBuffer buffer = StringBuffer();

    for (ReadRef argument in arguments) {
      if (argument.value is ReadList) {
        for (Object element in argument.value.elements) {
          buffer.write(element);
        }
      } else {
        buffer.write(argument.value);
      }
    }

    return Constant<String>(buffer.toString());
  }

  // TODO: expose in library catalog
  ReadRef executeToday(List<ReadRef> arguments, Lifespan lifespan) {
    DateTime date = DateTime.now().toLocal();

    String today = date.month.toString() + '/' + date.day.toString() + '/' + date.year.toString();

    return Constant<String>(today);
  }

  ReadRef executeList(List<ReadRef> arguments, Lifespan lifespan) {
    MutableList<Object> result = BaseMutableList<Object>();

    for (ReadRef argument in arguments) {
      result.add(argument.value);
    }

    return Constant<ReadList>(result);
  }

  ReadRef executeMap(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length != 2) {
      return newError('map() expected 2 arguments, got ${arguments.length}');
    }

    if (arguments[0].value is! ReadList) {
      return newError('map() argument #1 expected to be list');
    }

    if (arguments[1].value is! ProcedureRecord) {
      return newError('map() argument #2 expected to be procedure');
    }

    MutableList<Object> result = BaseMutableList<Object>();

    void update() {
      result.clear();
      ReadList<dynamic> list = arguments[0].value as ReadList<dynamic>;
      ProcedureRecord procedure = arguments[1].value as ProcedureRecord;

      for (int i = 0; i < list.size.value; ++i) {
        ReadRef element = Constant<dynamic>(list.elements[i]);
        ReadRef mapped = evaluator.evaluateProcedure(procedure, <ReadRef>[element], lifespan);

        result.add(mapped.value);
      }
    }

    update();
    Operation updateOp = zone.makeOperation(update);
    _deepObserveList(arguments, updateOp, lifespan);
    List<dynamic> list = (arguments[0].value as ReadList<dynamic>).elements;
    for (int i = 0; i < list.length; ++i) {
      if (list[i] is Observable) {
        list[i].observe(updateOp, lifespan);
      }
    }

    return Constant<ReadList>(result);
  }

  ReadRef executeCall(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 1) {
      return newError('call() expected with at least 1 argument, got ${arguments.length}');
    }

    if (arguments[0].value is! ProcedureRecord) {
      return newError('call() argument #1 expected to be procedure');
    }

    ProcedureRecord procedure = arguments[0].value as ProcedureRecord;
    List<ReadRef> callArguments = arguments.sublist(1);

    return Constant<DelayedProcedure>(DelayedProcedure(procedure, callArguments, lifespan));
  }

  ReadRef executeAll(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length != 1) {
      return newError('all() expected 1 argument, got ${arguments.length}');
    }

    if (datastore == null) {
      return Constant<ReadList>(ImmutableList<CompositeData>([]));
    }

    DataType dataType = arguments[0].value as DataType;
    bool isDataType(CompositeData data) => data.dataType == dataType;
    ReadList<CompositeData> result = datastore.runQuerySync(BaseQuery<CompositeData>(isDataType));

    return Constant<ReadList>(result);
  }

  ReadRef executeNewLabel(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 2) {
      return newError('newLabel() expected 2 arguments, got ${arguments.length}');
    }

    if (arguments[0].value is! String) {
      return newError('newLabel() argument #1 expected to be string');
    }

    if (arguments[1].value is! Style) {
      return newError('newLabel() argument #2 expected to be style but got ${arguments[1].value}');
    }

    return Constant<View>(LabelView(arguments[0].cast<String>(), arguments[1].cast<Style>()));
  }

  ReadRef executeNewButton(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 3) {
      return newError('newButton() expected 3 arguments, got ${arguments.length}');
    }

    if (arguments[0].value is! String) {
      return newError('newButton() argument #1 expected to be string');
    }

    if (arguments[1].value is! Style) {
      return newError('newButton() argument #2 expected to be style but got ${arguments[1].value}');
    }

    if (arguments[2].value is! String) {
      return newError('newButton() argument #3 expected to be string');
    }

    Operation action = zone.makeOperation(() => evaluator.executeAction(arguments[2].value));

    return Constant<View>(ButtonView(
        arguments[0].cast<String>(), arguments[1].cast<Style>(), Constant<Operation>(action)));
  }

  ReadRef executeNewContainer(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 2) {
      return newError('newContainer() expected 2 arguments, got ${arguments.length}');
    }

    if (arguments[0].value is! View) {
      return newError('newContainer() argument #1 expected to be view');
    }

    if (arguments[1].value is! Style) {
      return newError(
          'newContainer() argument #2 expected to be style but got ${arguments[1].value}');
    }

    return Constant<View>(ContainerView(arguments[0].cast<View>(), arguments[1].cast<Style>()));
  }

  ReadRef executeNewRow(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 1) {
      return newError('newRow() expected 1 argument, got ${arguments.length}');
    }

    MutableList<View> views = BaseMutableList<View>();
    ReadRef<Style> style;

    for (int i = 0; i < arguments.length; ++i) {
      if (arguments[i] == null) {
        continue;
      }
      Object argument = arguments[i].value;
      if (argument is Style) {
        if (style != null) {
          return newError('Duplicate style found');
        }
        style = arguments[i].cast<Style>();
      } else if (argument is View) {
        views.add(argument);
      } else if (argument is ReadList) {
        views.addAll(argument.cast<View>().elements);
      } else if (argument != null) {
        print('Bad new_row argument $argument (${argument.runtimeType})');
      }
    }

    return Constant<View>(RowView(views, style));
  }

  ReadRef<View> executeNewColumn(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 1) {
      return newError('newColumn() expected 1 argument, got ${arguments.length}');
    }

    MutableList<View> views = BaseMutableList<View>();
    ReadRef<Style> style;

    void update() {
      views.clear();
      style = null;
      for (int i = 0; i < arguments.length; ++i) {
        if (arguments[i] == null) {
          continue;
        }
        Object argument = arguments[i].value;
        if (argument is Style) {
          if (style != null) {
            newError('Duplicate style found');
          }
          style = Constant<Style>(argument);
        } else if (argument is View) {
          views.add(argument);
        } else if (argument is ReadList) {
          views.addAll(argument.cast<View>().elements);
        } else if (argument != null) {
          print('Bad new_column argument $argument (${argument.runtimeType})');
        }
      }
    }

    update();
    Operation updateOp = zone.makeOperation(update);
    _deepObserveList(arguments, updateOp, lifespan);

    return Constant<View>(ColumnView(views, style));
  }

  ReadRef executeNewDivider(List<ReadRef> arguments, Lifespan lifespan) {
    double height;

    if (arguments.length < 1 || arguments[0].value == null) {
      height = 0.0;
    } else {
      height = arguments[0].value as double;
    }

    return Constant<View>(DividerView(height));
  }

  bool isAction(Object value) {
    return value is String || value is DelayedProcedure;
  }

  void Function() callAction(Object value) {
    if (value is String) {
      return () => evaluator.executeAction(value);
    } else if (value is DelayedProcedure) {
      return () => value.call(evaluator);
    } else {
      throw StateError('Unrecognized action $value');
    }
  }

  ReadRef executeNewAction(List<ReadRef> arguments, Lifespan lifespan) {
    if (arguments.length < 2) {
      return newError('newAction() expected 2 arguments, got ${arguments.length}');
    }

    if (arguments[0].value is! View) {
      return newError('newAction() argument #1 expected to be view');
    }

    if (!isAction(arguments[1].value)) {
      return newError('newAction() argument #2 expected to be an action');
    }

    Operation action = zone.makeOperation(callAction(arguments[1].value));

    return Constant<View>(ActionView(arguments[0].cast<View>(), Constant<Operation>(action)));
  }
}
