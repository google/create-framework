// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../elements.dart';

import 'createdata.dart';

Construct parseTemplate(String template) {
  final List<Construct> result = [];
  final int length = template.length;
  int startIndex = 0;
  int index = 0;
  while (index + 1 < length) {
    if (template[index] == '\$' && isLetter(template.codeUnitAt(index + 1))) {
      if (startIndex < index) {
        result.add(ConstantConstruct(template.substring(startIndex, index)));
      }
      int startTemplate = index + 1;
      index = startTemplate + 1;
      while (index < length && isLetterOrDigit(template.codeUnitAt(index))) {
        ++index;
      }
      result.add(IdentifierConstruct(template.substring(startTemplate, index)));
      startIndex = index;
    } else {
      ++index;
    }
  }
  if (startIndex < length) {
    result.add(ConstantConstruct(template.substring(startIndex)));
  }
  return ConcatenateConstruct(result);
}

Construct parseCode(String code) {
  int index = code.indexOf('+=');
  if (index >= 0) {
    return _parseAssignment(
        code.substring(0, index), code.substring(index + 2), AssignmentType.PLUS);
  }

  index = code.indexOf('=');
  if (index >= 0) {
    return _parseAssignment(
        code.substring(0, index), code.substring(index + 1), AssignmentType.SET);
  }

  String term = code.trim();
  if (term.length > 0 && isLetter(term.codeUnitAt(0))) {
    return IdentifierConstruct(term);
  } else {
    return ConstantConstruct(term);
  }
}

Construct _parseAssignment(String lhs, String rhs, AssignmentType type) {
  Construct lhsConstruct = parseCode(lhs);
  Construct rhsConstruct = parseCode(rhs);

  if (!(lhsConstruct is IdentifierConstruct)) {
    return ConstantConstruct(renderError(lhs));
  }

  return AssignmentConstruct(lhsConstruct as IdentifierConstruct, rhsConstruct, type);
}

abstract class Construct {
  void observe(EvaluationContext context, Operation operation, Lifespan lifespan);

  String evaluate(EvaluationContext datastore);
}

class ConstantConstruct implements Construct {
  final String value;

  ConstantConstruct(this.value);

  void observe(EvaluationContext context, Operation operation, Lifespan lifespan) => null;

  String evaluate(EvaluationContext context) => value;
}

String renderError(String symbol) => symbol + '???';

class IdentifierConstruct implements Construct {
  final String identifier;

  IdentifierConstruct(this.identifier);

  void observe(EvaluationContext context, Operation operation, Lifespan lifespan) {
    CompositeData record = context.resolve(identifier);
    // TODO: handle non-DataRecord records
    if (record != null && record is DataRecord) {
      record.state.observeDeep(operation, lifespan);
    }
  }

  String evaluate(EvaluationContext context) {
    CompositeData record = context.resolve(identifier);
    // TODO: handle non-DataRecord records
    if (record != null && record is DataRecord) {
      return record.state.value;
    } else {
      return error;
    }
  }

  Ref<String> getRef(EvaluationContext context) {
    CompositeData record = context.resolve(identifier);
    if (record != null && record is DataRecord) {
      return record.state;
    } else {
      return null;
    }
  }

  String get error => renderError(identifier);
}

class ConcatenateConstruct implements Construct {
  final List<Construct> parameters;

  ConcatenateConstruct(this.parameters);

  void observe(EvaluationContext context, Operation operation, Lifespan lifespan) {
    parameters.forEach((c) => c.observe(context, operation, lifespan));
  }

  String evaluate(EvaluationContext context) {
    StringBuffer result = StringBuffer();
    parameters.forEach((c) => result.write(c.evaluate(context)));
    return result.toString();
  }
}

enum AssignmentType { SET, PLUS }

class AssignmentConstruct implements Construct {
  final IdentifierConstruct lhs;
  final Construct rhs;
  final AssignmentType type;

  AssignmentConstruct(this.lhs, this.rhs, this.type);

  void observe(EvaluationContext context, Operation operation, Lifespan lifespan) {
    lhs.observe(context, operation, lifespan);
    rhs.observe(context, operation, lifespan);
  }

  String evaluate(EvaluationContext context) {
    Ref<String> lhsRef = lhs.getRef(context);
    if (lhsRef == null) {
      return lhs.error;
    }
    String rhsValue = rhs.evaluate(context);

    switch (type) {
      case AssignmentType.SET:
        lhsRef.value = rhsValue;
        break;
      case AssignmentType.PLUS:
        lhsRef.value = (parseInt(lhsRef.value) + parseInt(rhsValue)).toString();
        break;
    }

    return lhsRef.value;
  }

  static int parseInt(String s) {
    int result = int.tryParse(s);
    return result != null ? result : 0;
  }
}
