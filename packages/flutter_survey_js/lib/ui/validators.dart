import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:reactive_forms/reactive_forms.dart';

/// Singleton JS runtime for evaluating expressions
final JavascriptRuntime jsRuntime = getJavascriptRuntime();

/// Validator that requires the control have a non-empty value.
class NonEmptyValidator extends Validator<dynamic> {
  @override
  Map<String, dynamic>? validate(AbstractControl<dynamic> control) {
    final error = <String, dynamic>{ValidationMessage.required: true};
    final v = control.value;
    if (v == null) return error;
    if (v is String) return v.trim().isEmpty ? error : null;
    if (v is List) return v.isEmpty ? error : null;
    if (v is Map<String, Object?>)
      return removeEmptyField(v).isEmpty ? error : null;
    if (v is Map) return v.isEmpty ? error : null;
    return null;
  }
}

/// Evaluates a SurveyJS expression using flutter_js
bool evaluateExpression(String expression, Map<String, dynamic> allValues) {
  try {
    jsRuntime.evaluate('var survey = ${jsonEncode(allValues)};');

    // Converts SurveyJS syntax:  {q1} -> survey["q1"]
    final jsExpr = expression.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (m) => 'survey["${m[1]}"]',
    );

    final result = jsRuntime.evaluate(jsExpr);

    final r = result.rawResult;
    if (r is bool) return r;
    if (r is num) return r != 0;
    if (r is String) return r.toLowerCase() == 'true';
  } catch (e) {
    print('Expression error: $e');
  }
  return false;
}

/// Converts a SurveyJS question into ReactiveForms validators
List<Validator> questionToValidators(s.Question question) {
  final res = <Validator>[];

  // Required field
  if (question.isRequired == true) res.add(NonEmptyValidator());

  // Text question constraints
  if (question is s.Text) {
    final minValue = question.min?.oneOf.value.tryCastToNum();
    final maxValue = question.max?.oneOf.value.tryCastToNum();
    if (minValue != null) res.add(Validators.min(minValue));
    if (maxValue != null) res.add(Validators.max(maxValue));
  }

  // SurveyJS validators
  final validators = question.validators?.map((v) => v.realValidator).toList();
  if (validators != null) {
    for (var value in validators) {
      if (value is s.Numericvalidator) {
        res.add(Validators.number());
        if (value.maxValue != null) res.add(Validators.max(value.maxValue));
        if (value.minValue != null) res.add(Validators.min(value.minValue));
      }

      if (value is s.Textvalidator) {
        if (value.maxLength != null)
          res.add(Validators.maxLength(value.maxLength!.toInt()));
        if (value.minLength != null)
          res.add(Validators.minLength(value.minLength!.toInt()));
        if (value.allowDigits != null) {
          res.add(Validators.delegate((control) {
            if (control.value is String &&
                !value.allowDigits! &&
                (control.value as String).contains('.')) {
              return {'allowDigits': value.allowDigits};
            }
            return null;
          }));
        }
      }

      if (value is s.Answercountvalidator) {
        if (value.maxCount != null)
          res.add(Validators.maxLength(value.maxCount!.toInt()));
        if (value.minCount != null)
          res.add(Validators.minLength(value.minCount!.toInt()));
      }

      if (value is s.Regexvalidator && value.regex != null) {
        res.add(Validators.pattern(value.regex!));
      }

      if (value is s.Emailvalidator) {
        res.add(Validators.email);
      }

      // Expression validator
      if (value is s.Expressionvalidator) {
        final expr = value.expression;

        if (expr != null && expr.isNotEmpty) {
          res.add(Validators.delegate((control) {
            // Safe conversion of parent form values
            final raw = control.parent?.value;

            final formValues = raw is Map
                ? raw.map<String, dynamic>((k, v) => MapEntry(k.toString(), v))
                : <String, dynamic>{};

            final valid = evaluateExpression(expr, formValues);

            if (!valid) {
              return {
                'expression': value.text ?? 'Expression validation failed'
              };
            }

            return null;
          }));
        }
      }
    }
  }

  return res;
}
