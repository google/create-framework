// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import '../../elements.dart';
import '../../views.dart';

import 'hackernews.dart';

typedef bool RawQuery<R>(R data);

// TODO: move to elementsruntime.
abstract class NamedRecord extends BaseCompositeData implements Named {
  ReadRef<String> get recordName;

  String get name => recordName.value;
  String toString() => name != null ? name : '<unnamed>';
}

const Namespace CREATE_NAMESPACE = const Namespace('Create', 'create');

/// Name of the view that Launch mode will display
const String MAIN_NAME = 'main';

const String NORMAL_STYLE_NAME = 'normal_style';

class DataRecordType extends CompositeDataType {
  const DataRecordType(String name) : super(CREATE_NAMESPACE, name);

  DataRecord newInstance(DataId dataId) => DataRecord(this, dataId, null, null, null);
}

const DataRecordType APP_STATE_DATATYPE = const DataRecordType('app_state');
const DataRecordType PARAMETER_DATATYPE = const DataRecordType('parameter');
const DataRecordType OPERATION_DATATYPE = const DataRecordType('operation');

const String RECORD_NAME_FIELD = 'record_name';
const String TYPE_ID_FIELD = 'type_id';
const String STATE_FIELD = 'state';

class DataRecord extends NamedRecord {
  final CompositeDataType dataType;
  final DataId dataId;
  final Ref<String> recordName;
  final Ref<DataType> typeId;
  final Ref<String> state;

  DataRecord(this.dataType, this.dataId, String recordName, DataType typeId, String state)
      : recordName = Boxed<String>(recordName),
        typeId = Boxed<DataType>(typeId),
        state = Boxed<String>(state);

  void visit(FieldVisitor visitor) {
    visitor.stringField(RECORD_NAME_FIELD, recordName);
    visitor.dataField(TYPE_ID_FIELD, typeId, TYPE_ID_DATATYPE);
    visitor.stringField(STATE_FIELD, state);
  }
}

const DataType VIEW_DATATYPE = const BuiltinDataType('view');

const String ARGUMENTS_FIELD = 'arguments';
const String OUTPUT_TYPE_FIELD = 'output_type';
const String BODY_FIELD = 'body';

class ProcedureRecordType extends CompositeDataType {
  const ProcedureRecordType() : super(CREATE_NAMESPACE, 'procedure');

  ProcedureRecord newInstance(DataId dataId) => ProcedureRecord(dataId, null, null, null);
}

const ProcedureRecordType PROCEDURE_DATATYPE = const ProcedureRecordType();

class ProcedureRecord extends NamedRecord {
  final DataId dataId;
  final Ref<String> recordName;
  final MutableList<ArgumentRecord> arguments;
  final Ref<DataType> outputType;
  final MutableList<ExpressionRecord> body;

  ProcedureRecord(
      this.dataId, String recordName, List<ArgumentRecord> arguments, DataType outputType)
      : recordName = Boxed<String>(recordName),
        arguments =
            BaseMutableList<ArgumentRecord>(arguments != null ? arguments : <ArgumentRecord>[]),
        outputType = Boxed<DataType>(outputType),
        body = BaseMutableList<ExpressionRecord>();

  ProcedureRecordType get dataType => PROCEDURE_DATATYPE;

  bool get isNative => body.size.value == 0;

  bool get hasNoArguments =>
      arguments.size.value == 0 ||
      (arguments.size.value == 1 && arguments.elements[0].typeId.value == VOID_DATATYPE);

  void visit(FieldVisitor visitor) {
    visitor.stringField(RECORD_NAME_FIELD, recordName);
    visitor.listField(ARGUMENTS_FIELD, arguments, ARGUMENT_DATATYPE);
    visitor.dataField(OUTPUT_TYPE_FIELD, outputType, TYPE_ID_DATATYPE);
    visitor.listField(BODY_FIELD, body, EXPRESSION_DATATYPE);
  }
}

const String DEFAULT_VALUE_FIELD = 'default_value';

class ArgumentRecordType extends CompositeDataType {
  const ArgumentRecordType() : super(CREATE_NAMESPACE, 'argument');

  ArgumentRecord newInstance(DataId dataId) => ArgumentRecord(dataId, null, null, null);
}

const ArgumentRecordType ARGUMENT_DATATYPE = const ArgumentRecordType();

class ArgumentRecord extends NamedRecord {
  final DataId dataId;
  final Ref<String> recordName;
  final Ref<DataType> typeId;
  final Ref<String> defaultValue;

  ArgumentRecord(this.dataId, String recordName, DataType typeId, String defaultValue)
      : recordName = Boxed<String>(recordName),
        typeId = Boxed<DataType>(typeId),
        defaultValue = Boxed<String>(defaultValue);

  ArgumentRecordType get dataType => ARGUMENT_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.stringField(RECORD_NAME_FIELD, recordName);
    visitor.dataField(TYPE_ID_FIELD, typeId, TYPE_ID_DATATYPE);
    visitor.stringField(DEFAULT_VALUE_FIELD, defaultValue);
  }
}

String argumentName(int index) {
  return 'arg$index';
}

const String PROCEDURE_FIELD = 'procedure';
const String PARAMETERS_FIELD = 'parameters';

class ExpressionRecordType extends CompositeDataType {
  const ExpressionRecordType() : super(CREATE_NAMESPACE, 'expression');

  ExpressionRecord newInstance(DataId dataId) => ExpressionRecord(dataId, null);
}

const ExpressionRecordType EXPRESSION_DATATYPE = const ExpressionRecordType();

class ExpressionRecord extends BaseCompositeData {
  final DataId dataId;
  final Ref<ProcedureRecord> procedure;
  final MutableList<Object> parameters;

  ExpressionRecord(this.dataId, ProcedureRecord procedure)
      : procedure = Boxed<ProcedureRecord>(procedure),
        parameters = BaseMutableList<Object>();

  ExpressionRecordType get dataType => EXPRESSION_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.dataField(PROCEDURE_FIELD, procedure, PROCEDURE_DATATYPE);
    visitor.listField(PARAMETERS_FIELD, parameters, ANY_DATATYPE);
  }
}

class ReferenceRecordType extends CompositeDataType {
  const ReferenceRecordType() : super(CREATE_NAMESPACE, 'reference');

  ReferenceRecord newInstance(DataId dataId) => ReferenceRecord(dataId, null, null);
}

const ReferenceRecordType REFERENCE_DATATYPE = const ReferenceRecordType();

class ReferenceRecord extends NamedRecord {
  final DataId dataId;
  final Ref<String> recordName;
  final Ref<DataType> typeId;

  ReferenceRecord(this.dataId, String recordName, DataType typeId)
      : recordName = Boxed<String>(recordName),
        typeId = Boxed<DataType>(typeId);

  ReferenceRecordType get dataType => REFERENCE_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.stringField(RECORD_NAME_FIELD, recordName);
    visitor.dataField(TYPE_ID_FIELD, typeId, TYPE_ID_DATATYPE);
  }
}

class FieldRecordType extends CompositeDataType {
  const FieldRecordType() : super(CREATE_NAMESPACE, 'field');

  FieldRecord newInstance(DataId dataId) => FieldRecord(dataId, null, null, null);
}

const String DATA_VALUE_FIELD = 'data_value';
const String FIELD_NAME_FIELD = 'field_name';

const FieldRecordType FIELD_RECORD_DATATYPE = const FieldRecordType();

class FieldRecord extends BaseCompositeData implements Named {
  final DataId dataId;
  final Ref<CompositeData> dataValue;
  final Ref<String> fieldName;
  final Ref<DataType> typeId;

  FieldRecord(this.dataId, CompositeData dataValue, String fieldName, DataType typeId)
      : dataValue = Boxed<CompositeData>(dataValue),
        fieldName = Boxed<String>(fieldName),
        typeId = Boxed<DataType>(typeId);

  FieldRecordType get dataType => FIELD_RECORD_DATATYPE;

  void visit(FieldVisitor visitor) {
    visitor.dataField(DATA_VALUE_FIELD, dataValue, ANY_DATATYPE);
    visitor.stringField(FIELD_NAME_FIELD, fieldName);
    visitor.dataField(TYPE_ID_FIELD, typeId, TYPE_ID_DATATYPE);
  }

  String get name => fieldName.value;

  String toString() => '${dataValue.value.toString()}.$name';
}

class CreateDataType extends BaseDataType {
  const CreateDataType(String name) : super(CREATE_NAMESPACE, name);
}

const DataType TEMPLATE_DATATYPE = const CreateDataType('template');
const DataType INLINE_DATATYPE = const CreateDataType('inline');

List<DataType> allCreateTypes = [
  APP_STATE_DATATYPE,
  PARAMETER_DATATYPE,
  OPERATION_DATATYPE,
  VIEW_DATATYPE,
  PROCEDURE_DATATYPE,
  ARGUMENT_DATATYPE,
  EXPRESSION_DATATYPE,
  REFERENCE_DATATYPE,
  FIELD_RECORD_DATATYPE,
  THEMED_STYLE_DATATYPE,
  FONT_STYLE_DATATYPE,
  CONTAINER_STYLE_DATATYPE,
  FLEX_STYLE_DATATYPE,
  NAMED_COLOR_DATATYPE,
  itemRecordType,
  // builtin types
  ANY_DATATYPE,
  TYPE_ID_DATATYPE,
  VOID_DATATYPE,
  BOOLEAN_DATATYPE,
  INTEGER_DATATYPE,
  STRING_DATATYPE,
  TEMPLATE_DATATYPE,
  INLINE_DATATYPE,
  LIST_DATATYPE,
  // missing: APP_MODE_DATATYPE
];

class ListFields implements FieldVisitor {
  final DataIdSource ids;
  final ReferenceRecord argument;
  final List<FieldRecord> fields = <FieldRecord>[];

  ListFields(this.ids, this.argument);

  void stringField(String fieldName, Ref<String> field) =>
      fields.add(FieldRecord(ids.nextId(), argument, fieldName, STRING_DATATYPE));

  void boolField(String fieldName, Ref<bool> field) =>
      fields.add(FieldRecord(ids.nextId(), argument, fieldName, BOOLEAN_DATATYPE));

  void intField(String fieldName, Ref<int> field) =>
      fields.add(FieldRecord(ids.nextId(), argument, fieldName, INTEGER_DATATYPE));

  void doubleField(String fieldName, Ref<double> field) =>
      fields.add(FieldRecord(ids.nextId(), argument, fieldName, REAL_DATATYPE));

  void dataField(String fieldName, Ref<Data> field, DataType dataType) =>
      fields.add(FieldRecord(ids.nextId(), argument, fieldName, dataType));

  // TODO: add support for list fields
  void listField(String fieldName, MutableList<Object> field, DataType elementType) => null;
}

class GetFieldRef implements FieldVisitor {
  final String name;
  ReadRef result;

  GetFieldRef(this.name);

  void stringField(String fieldName, Ref<String> field) {
    if (fieldName == name) {
      result = field;
    }
  }

  void boolField(String fieldName, Ref<bool> field) {
    if (fieldName == name) {
      result = field;
    }
  }

  void intField(String fieldName, Ref<int> field) {
    if (fieldName == name) {
      result = field;
    }
  }

  void doubleField(String fieldName, Ref<double> field) {
    if (fieldName == name) {
      result = field;
    }
  }

  void dataField(String fieldName, Ref<Data> field, DataType dataType) {
    if (fieldName == name) {
      result = field;
    }
  }

  // TODO: add support for list fields
  void listField(String fieldName, MutableList<Object> field, DataType elementType) {
    if (fieldName == name) {
      result = Constant<MutableList<Object>>(field);
    }
  }
}

abstract class EvaluationContext {
  CompositeData resolve(String name);
  ImmutableList<CompositeData> where(RawQuery<CompositeData> query);
  ReadRef dereference(ReferenceRecord reference);
}

class LocalContext implements EvaluationContext {
  final EvaluationContext global;
  final String name;
  final Map<String, CompositeData> dataMap = LinkedHashMap<String, CompositeData>();
  final Map<String, ReadRef> values = HashMap<String, ReadRef>();

  LocalContext(this.global, this.name);

  void addReference(ReferenceRecord record) {
    dataMap[record.recordName.value] = record;
  }

  void addField(FieldRecord record) {
    dataMap[record.fieldName.value] = record;
  }

  void addValue(ReferenceRecord reference, ReadRef value) {
    values[reference.recordName.value] = value;
  }

  @override
  CompositeData resolve(String name) {
    CompositeData dereferenced = dataMap[name];
    if (dereferenced != null) {
      return dereferenced;
    }
    return global.resolve(name);
  }

  @override
  ReadRef dereference(ReferenceRecord reference) {
    return values[reference.recordName.value];
  }

  @override
  ImmutableList<CompositeData> where(RawQuery<CompositeData> query) {
    List<CompositeData> matched = dataMap.values.where(query).cast<CompositeData>().toList();
    if (matched.isEmpty) {
      return global.where(query);
    }
    matched.addAll(global.where(query).elements);
    return ImmutableList<CompositeData>(matched);
  }

  @override
  String toString() => '$name ($dataMap)';
}
