import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart';
import 'package:flutter_survey_js/ui/element_node.dart';
import 'package:flutter_survey_js/ui/elements/boolean.dart';
import 'package:flutter_survey_js/ui/elements/comment.dart';
import 'package:flutter_survey_js/ui/elements/condition_widget.dart';
import 'package:flutter_survey_js/ui/reactive/reactive.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:logging/logging.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'elements/checkbox.dart';
import 'elements/dropdown.dart';
import 'elements/matrix.dart';
import 'elements/rating.dart';
import 'elements/text.dart';

class SurveyElementFactory {
  final logger = Logger('SurveyElementFactory');

  final Map<String, SurveyElementBuilder> _map =
      <String, SurveyElementBuilder>{};
  final Map<String, SurveyFormControlBuilder> _formControlMap =
      <String, SurveyFormControlBuilder>{};

  SurveyElementFactory() {
    // Example: register elements
    register<s.Matrix>(matrixBuilder,
        control: (context, element, {validators = const [], value}) {
      return surveyfb.group(
          Map.fromEntries(((element as s.Matrix)
                      .rows
                      ?.map((p) => p.castToItemvalue()) ??
                  [])
              .map((e) => MapEntry(
                  e.value.toString(),
                  fb.control<Object?>(tryGetValue(
                      e.value.toString(), getDefaultValue(element, value)))))),
          validators);
    });

    register<s.Checkbox>(checkBoxBuilder,
        control: (context, element, {validators = const [], value}) {
      return surveyfb.array(
          (element as s.Checkbox).defaultValue.tryCastToListObj() ??
              value.tryCastToList() ??
              [],
          validators);
    });

    register<s.Boolean>(booleanBuilder,
        control: (context, element, {validators = const [], value}) {
      return FormControl<bool>(
          value: (element as s.Boolean).defaultValue.tryCastToBool() ??
              value.tryCastToBool(),
          validators: validators);
    });

    register<s.Rating>(ratingBuilder,
        control: (context, element, {validators = const [], value}) {
      return FormControl<int>(
          value: (element as s.Rating).defaultValue.tryCastToInt() ??
              value.tryCastToInt(),
          validators: validators);
    });

    register<s.Text>(textBuilder, control: textControlBuilder);
    register<s.Comment>(commentBuilder);
    register<s.Dropdown>(dropdownBuilder,
        control: (context, element, {validators = const [], value}) =>
            FormControl<Object>(
                value: (element as s.Dropdown).defaultValue?.value ?? value,
                validators: validators));

    register<s.Empty>(
        (context, element, {ElementConfiguration? configuration}) =>
            const SizedBox(),
        control: (context, element, {validators = const [], value}) => null);

    // Register other elements...
  }

  void register<T>(SurveyElementBuilder builder,
      {SurveyFormControlBuilder? control}) {
    final name = s.questionTypeName[T];
    if (name == null) {
      throw UnsupportedError("Element type $T not supported");
    }
    _map[name] = builder;
    if (control != null) _formControlMap[name] = control;
  }

  /// Resolves widget safely
  Widget resolve(BuildContext context, s.Elementbase element,
      {ElementConfiguration? configuration}) {
    var builder = _map[element.type];
    if (builder == null) {
      final unsupported = SurveyConfiguration.of(context)?.unsupportedBuilder;
      if (unsupported == null) {
        throw UnsupportedError('Unsupported element type: ${element.type}');
      }
      builder = unsupported;
    }

    final builtWidget = builder(context, element, configuration: configuration);

    final node =
        SurveyWidgetState.of(context).rootNode.findByElement(element: element);

    if (node != null) {
      return ConditionWidget(node: node, child: builtWidget);
    } else {
      // Node missing, return widget without condition wrapper
      logger.warning('Survey node not found for element: ${element.name}');
      return builtWidget;
    }
  }

  /// Resolves FormControl safely
  AbstractControl? resolveFormControl(
      BuildContext context, s.Elementbase element,
      {Object? value, List<Validator> validators = const []}) {
    if (_formControlMap.containsKey(element.type)) {
      final controlBuilder = _formControlMap[element.type];
      try {
        return controlBuilder?.call(context, element,
            validators: validators, value: value);
      } catch (e, st) {
        logger.warning(
            'Error building form control for ${element.name}: $e\n$st');
        return FormControl<Object>(
            value: getDefaultValue(element, value), validators: validators);
      }
    }

    // fallback: generic FormControl
    return FormControl<Object>(
        value: getDefaultValue(element, value), validators: validators);
  }
}
