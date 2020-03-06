// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';
import '../../views.dart';

import 'createdata.dart';
import 'createeval.dart';
import 'library.dart';

class Evaluator implements ProcedureEvaluator {
  final Zone zone;
  final DataIdSource idSource;
  final EvaluationContext global;
  final ProcedureLibrary library;

  Evaluator(this.zone, this.idSource, this.global, this.library) {
    library.setEvaluator(this);
  }

  ReadRef evaluateDataOrProcedure(Object data, EvaluationContext context, Lifespan lifespan) {
    if (data is ProcedureRecord && data.arguments.size.value == 0) {
      return _executeProcedure(data, [], context, lifespan);
    } else {
      return _evaluateData(data, context, lifespan);
    }
  }

  ReadRef _evaluateData(Object data, EvaluationContext context, Lifespan lifespan) {
    String error;

    if (data is ExpressionRecord) {
      return _executeExpression(data, context, lifespan);
    } else if (data is DataRecord) {
      return evaluateRecord(data, lifespan);
    } else if (data is FieldRecord) {
      ReadRef<Data> dataValue = _evaluateData(data.dataValue.value, context, lifespan).cast<Data>();
      GetFieldRef getField = GetFieldRef(data.fieldName.value);
      (dataValue.value as CompositeData).visit(getField);
      return getField.result;
    } else if (data is ReferenceRecord) {
      ReadRef result = context.dereference(data);
      if (result == null) {
        error = 'Can\'t dereference: $data (${data.runtimeType}) in $context';
      } else {
        return result;
      }
    } else if (data == null ||
        data is EnumData ||
        data is ProcedureRecord ||
        data is Style ||
        data is View ||
        data is DataType ||
        data is double ||
        data is int ||
        data is bool ||
        data is List<dynamic>) {
      return Constant<Object>(data);
    } else {
      error = 'evaluateData() fails for $data (${data.runtimeType}) in $context';
    }

    throw StateError(error);
    // return Constant<String>(error);
  }

  ReadRef evaluateProcedure(
      ProcedureRecord procedure, List<ReadRef> parameters, Lifespan lifespan) {
    LocalContext bodyContext = LocalContext(global, procedure.name);

    for (int i = 0; i < parameters.length; ++i) {
      Object parameter = parameters[i];
      if (i < procedure.arguments.size.value) {
        ArgumentRecord argument = procedure.arguments.at(i).value;
        DataType type = argument.typeId.value;
        if (type == VOID_DATATYPE) {
          continue;
        }
        ReferenceRecord ref = ReferenceRecord(idSource.nextId(), argument.name, type);
        bodyContext.addReference(ref);
        bodyContext.addValue(ref, parameter);
      }
    }

    return _executeProcedure(procedure, parameters, bodyContext, lifespan);
  }

  ReadRef _executeProcedure(
      ProcedureRecord proc, List<ReadRef> arguments, EvaluationContext context, Lifespan lifespan) {
    if (proc.isNative) {
      return library.executeNative(proc, arguments, lifespan);
    }

    if (proc.body.size.value > 1) {
      throw Exception('More than 1 expression in body');
    }

    return _executeExpression(proc.body.at(0).value, context, lifespan);
  }

  ReadRef _executeExpression(ExpressionRecord expr, EvaluationContext context, Lifespan lifespan) {
    ProcedureRecord procedure = expr.procedure.value;

    List<ReadRef> newArguments = List<ReadRef>();
    LocalContext bodyContext = LocalContext(global, procedure.name);

    for (int i = 0; i < expr.parameters.size.value; ++i) {
      Object parameter = expr.parameters.elements[i];
      bool doEvaluate = true;

      if (parameter is ProcedureRecord && i < procedure.arguments.size.value) {
        ArgumentRecord argument = procedure.arguments.at(i).value;
        DataType type = argument.typeId.value;
        if (type == PROCEDURE_DATATYPE) {
          doEvaluate = false;
        }
      }

      ReadRef evaluatedParam = doEvaluate
          ? evaluateDataOrProcedure(parameter, context, lifespan)
          : Constant<ProcedureRecord>(parameter as ProcedureRecord);
      if (evaluatedParam == null) {
        throw Exception('Can\'t evaluate parameter: $parameter (${parameter.runtimeType})');
      }

      newArguments.add(evaluatedParam);
      if (i < procedure.arguments.size.value) {
        ArgumentRecord argument = procedure.arguments.at(i).value;
        DataType type = argument.typeId.value;
        if (type == VOID_DATATYPE) {
          continue;
        }
        ReferenceRecord ref = ReferenceRecord(idSource.nextId(), argument.name, type);
        bodyContext.addReference(ref);
        bodyContext.addValue(ref, evaluatedParam);
      }
    }

    return _executeProcedure(procedure, newArguments, bodyContext, lifespan);
  }

  ReadRef<String> evaluateRecord(DataRecord record, Lifespan lifespan) {
    if (record == null) {
      return Constant<String>('<null record>');
    }

    if (record.dataType == OPERATION_DATATYPE && record.typeId.value == TEMPLATE_DATATYPE) {
      return evaluateTemplate(record.state, lifespan);
    }

    return record.state;
  }

  ReadRef<String> evaluateTemplate(ReadRef<String> template, Lifespan lifespan) {
    ReadRef<Construct> code =
        ReactiveFunction<String, Construct>(template, parseTemplate, lifespan);
    // TODO: make a reactive function out of evaluation
    Ref<String> result = Boxed<String>(code.value.evaluate(global));
    Operation reevaluate = zone.makeOperation(() => result.value = code.value.evaluate(global));
    code.observeDeep(reevaluate, lifespan);
    code.value.observe(global, reevaluate, lifespan);
    return result;
  }

  void executeAction(String action) {
    if (action == null) {
      return;
    }

    print('Executing $action');
    Construct code = parseCode(action);
    code.evaluate(global);
  }
}
