// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'base.dart';
import 'runtime.dart';
import 'types.dart';

class FieldInfo {
  final Ref<String> name;
  final Ref<DataType> type;

  FieldInfo(String name, DataType type)
      : name = Boxed<String>(name),
        type = Boxed<DataType>(type);
}

class UserCompositeType extends CompositeDataType {
  MutableList<FieldInfo> fields;

  UserCompositeType(Namespace namespace, String name) : super(namespace, name) {
    fields = BaseMutableList<FieldInfo>();
  }

  UserCompositeValue newInstance(DataId dataId) {
    return UserCompositeValue(this, dataId);
  }
}

class UserCompositeValue extends CompositeData {
  final UserCompositeType dataType;
  final DataId dataId;
  final Map<FieldInfo, Ref> fields = HashMap<FieldInfo, Ref>();

  UserCompositeValue(this.dataType, this.dataId) : super(VERSION_ZERO);

  Ref fieldRef(FieldInfo fieldInfo) {
    Ref field = fields[fieldInfo];

    if (field == null) {
      field = Boxed();
      fields[fieldInfo] = field;
    }

    return field;
  }

  Ref field(String name) {
    for (FieldInfo fieldInfo in dataType.fields.elements) {
      if (fieldInfo.name.value == name) {
        return fieldRef(fieldInfo);
      }
    }

    return null;
  }

  void observe(Operation observer, Lifespan lifespan) {
    for (FieldInfo fieldInfo in dataType.fields.elements) {
      fieldRef(fieldInfo).observeRef(observer, lifespan);
    }
  }

  void visit(FieldVisitor visitor) {
    for (FieldInfo fieldInfo in dataType.fields.elements) {
      Ref field = fieldRef(fieldInfo);
      String name = fieldInfo.name.value;
      DataType type = fieldInfo.type.value;

      if (type == STRING_DATATYPE) {
        visitor.stringField(name, field.cast<String>());
      } else if (type == BOOLEAN_DATATYPE) {
        visitor.boolField(name, field.cast<bool>());
      } else if (type == INTEGER_DATATYPE) {
        visitor.intField(name, field.cast<int>());
      } else if (type == REAL_DATATYPE) {
        visitor.doubleField(name, field.cast<double>());
      } else if (type == LIST_DATATYPE) {
        // TODO(dynin): add element type to FieldInfo
        print('Unsupported list field $name');
      } else {
        visitor.dataField(name, field.cast<Data>(), type);
      }
    }
  }
}

class _CompositeTypeVisitor extends FieldVisitor {
  MutableList<FieldInfo> fields = BaseMutableList<FieldInfo>();

  void _add(String name, DataType type) {
    fields.add(FieldInfo(name, type));
  }

  void stringField(String fieldName, Ref<String> field) => _add(fieldName, STRING_DATATYPE);
  void boolField(String fieldName, Ref<bool> field) => _add(fieldName, BOOLEAN_DATATYPE);
  void intField(String fieldName, Ref<int> field) => _add(fieldName, INTEGER_DATATYPE);
  void doubleField(String fieldName, Ref<double> field) => _add(fieldName, REAL_DATATYPE);
  void dataField(String fieldName, Ref<Data> field, DataType dataType) => _add(fieldName, dataType);
  void listField(String fieldName, MutableList<Object> field, DataType elementType) =>
      _add(fieldName, LIST_DATATYPE);
}

ReadList<FieldInfo> getFields(UserCompositeType dataType) {
  _CompositeTypeVisitor visitor = _CompositeTypeVisitor();
  dataType.newInstance(null).visit(visitor);
  return visitor.fields;
}
