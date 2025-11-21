import 'package:flutter_survey_js/flutter_survey_js.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:reactive_forms/reactive_forms.dart';

/// Validator that requires the control have a non-empty value.
class NonEmptyValidator extends Validator<dynamic> {
  @override
  Map<String, dynamic>? validate(AbstractControl<dynamic> control) {
    final error = <String, dynamic>{ValidationMessage.required: true};
    final v = control.value;
    if (v == null) {
      return error;
    } else if (v is String) {
      return v.trim().isEmpty ? error : null;
    } else if (v is List) {
      return v.isEmpty ? error : null;
    } else if (v is Map<String, Object?>) {
      return removeEmptyField(v).isEmpty ? error : null;
    } else if (v is Map) {
      return v.isEmpty ? error : null;
    }
    return null;
  }
}

List<Validator> questionToValidators(s.Question question) {
  final res = <Validator>[];

  // 1️⃣ Required field
  if (question.isRequired == true) {
    res.add(NonEmptyValidator());
  }

  // 2️⃣ Text min/max values
  if (question is s.Text) {
    if (question.min?.oneOf.value.tryCastToNum() != null) {
      res.add(Validators.min(question.min!.oneOf.value.tryCastToNum()));
    }
    if (question.max?.oneOf.value.tryCastToNum() != null) {
      res.add(Validators.max(question.max!.oneOf.value.tryCastToNum()));
    }
  }

  // 3️⃣ SurveyJS validators
  final validators = question.validators?.map((p) => p.realValidator).toList();
  if (validators != null) {
    for (var value in validators) {
      // Numeric validator
      if (value is s.Numericvalidator) {
        res.add(Validators.number());
        if (value.maxValue != null) {
          res.add(Validators.max(value.maxValue));
        }
        if (value.minValue != null) {
          res.add(Validators.min(value.minValue));
        }
      }

      // Text validator
      if (value is s.Textvalidator) {
        if (value.maxLength != null) {
          res.add(Validators.maxLength(value.maxLength!.toInt()));
        }
        if (value.minLength != null) {
          res.add(Validators.minLength(value.minLength!.toInt()));
        }
        if (value.allowDigits != null) {
          res.add(Validators.delegate((control) {
            if (control.value is String) {
              if (!value.allowDigits! &&
                  (control.value as String).contains(RegExp(r'\d'))) {
                return {'allowDigits': value.allowDigits};
              }
            }
            return null;
          }));
        }
      }

      // Answer count validator (for arrays)
      if (value is s.Answercountvalidator) {
        if (value.maxCount != null) {
          res.add(Validators.maxLength(value.maxCount!.toInt()));
        }
        if (value.minCount != null) {
          res.add(Validators.minLength(value.minCount!.toInt()));
        }
      }

      // Regex validator
      if (value is s.Regexvalidator && value.regex != null) {
        res.add(Validators.pattern(value.regex!));
      }

      // Email validator
      if (value is s.Emailvalidator) {
        res.add(Validators.email);
      }

      // Expression validator
      if (value is s.Expressionvalidator && value.expression != null) {
        res.add(Validators.delegate((control) {
          final v = control.value;
          final contextValues = <String, Object?>{"value": v};

          try {
            final valid = getRunner().runCondition(
                value.expression!, contextValues); // Returns true/false
            if (valid == false) {
              return {"expression": true};
            }
          } catch (e) {
            return {"expression": true};
          }

          return null;
        }));
      }
    }
  }

  return res;
}
