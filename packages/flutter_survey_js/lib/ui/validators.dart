import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:reactive_forms/reactive_forms.dart';

final JavascriptRuntime jsRuntime = getJavascriptRuntime();

/// ------------------------------------------------------------
/// NORMALIZATION UTILITIES
/// ------------------------------------------------------------

Map<String, dynamic> _normalizeMap(Map input) {
  final out = <String, dynamic>{};
  input.forEach((k, v) {
    out[k.toString()] = _normalizeValue(v);
  });
  return out;
}

dynamic _normalizeValue(dynamic v) {
  if (v is String) {
    final s = v.trim();

    if (s.toLowerCase() == 'true') return true;
    if (s.toLowerCase() == 'false') return false;

    final intVal = int.tryParse(s);
    if (intVal != null) return intVal;

    final doubleVal = double.tryParse(s);
    if (doubleVal != null) return doubleVal;

    return v;
  }

  if (v is Map) return _normalizeMap(v);
  if (v is List) return v.map((e) => _normalizeValue(e)).toList();

  return v;
}

/// ------------------------------------------------------------
/// EXPRESSION EVALUATION
/// ------------------------------------------------------------

bool evaluateExpression(String expression, Map<String, dynamic> allValues) {
  try {
    final normalized = _normalizeMap(allValues);
    final surveyJson = jsonEncode(normalized);

    // Inject into JS runtime
    jsRuntime.evaluate('var survey = $surveyJson;');

    // Convert {age} → survey["age"]
    final jsExpr = expression.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (m) => 'survey["${m[1]}"]',
    );

    print('runExpression: $expression values:$surveyJson jsExpr:$jsExpr');

    final result = jsRuntime.evaluate(jsExpr);
    final raw = result.rawResult;

    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      final n = num.tryParse(raw);
      if (n != null) return n != 0;
    }
  } catch (e, st) {
    print('Expression error: $e\n$st');
  }

  return false;
}

/// ------------------------------------------------------------
/// FULL VALIDATOR MAPPER (ADD THIS INSIDE YOUR questionToValidators)
/// ------------------------------------------------------------

List<Validator> questionToValidators(s.Question question) {
  final res = <Validator>[];

  // Required
  if (question.isRequired == true) {
    res.add(Validators.required);
  }

  // Other validators...
  // (your existing numeric, regex, email, etc. validators remain unchanged)

  // -------------------------------
  // EXPRESSION VALIDATOR SUPPORT
  // -------------------------------
  final validators = question.validators?.map((p) => p.realValidator).toList();
  if (validators != null) {
    for (var value in validators) {
      if (value is s.Expressionvalidator &&
          value.expression != null &&
          value.expression!.isNotEmpty) {
        final expr = value.expression!;
        final message =
            (value.text != null) ? value.text! : 'Expression validation failed';

        res.add(Validators.delegate((control) {
          // Parent full form JSON
          final rawParent = control.parent?.value;

          final formValues = rawParent is Map
              ? rawParent.map<String, dynamic>(
                  (k, v) => MapEntry(k.toString(), v),
                )
              : <String, dynamic>{};

          final ok = evaluateExpression(expr, formValues);

          print(
              'ExpressionValidator → field: ${question.title} expr:$expr:$expr result:$ok form:$formValues');

          if (!ok) {
            return {'expression': message};
          }

          return null;
        }));
      }
    }
  }

  return res;
}
