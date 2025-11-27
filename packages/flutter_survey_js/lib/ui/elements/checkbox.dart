import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart' hide Text;
import 'package:flutter_survey_js/ui/elements/selectbase.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:reactive_forms/reactive_forms.dart';

import '../../generated/l10n.dart';

Widget checkBoxBuilder(BuildContext context, s.Elementbase element,
    {ElementConfiguration? configuration}) {
  return CheckBoxElement(
    formControlName: element.name!,
    element: element as s.Checkbox,
  ).wrapQuestionTitle(context, element, configuration: configuration);
}

class CheckBoxElement extends StatefulWidget {
  final String formControlName;
  final s.Checkbox element;

  const CheckBoxElement({
    Key? key,
    required this.formControlName,
    required this.element,
  }) : super(key: key);

  static bool allChecked(
      List<s.Itemvalue> choices, List<AbstractControl<Object?>> selected) {
    for (var choice in choices) {
      if (!selected.any((c) => c.value == choice.value?.value)) {
        return false;
      }
    }
    return true;
  }

  static void excludeFrom(FormArray<Object?> formArray, Object obj) {
    final rs = formArray.controls.where((c) => c.value == obj).toList();
    for (var r in rs) {
      formArray.remove(r);
    }
  }

  @override
  State<CheckBoxElement> createState() => _CheckBoxElementState();
}

class _CheckBoxElementState extends State<CheckBoxElement> {
  late SelectbaseController otherController;

  List<Itemvalue> get choices =>
      widget.element.choices?.map((p0) => p0.castToItemvalue()).toList() ?? [];

  bool get isReadOnly => widget.element.readOnly == true;

  FormArray<Object?> getFormArray() =>
      (ReactiveForm.of(context, listen: false) as FormControlCollection)
          .control(widget.formControlName) as FormArray<Object?>;

  @override
  void initState() {
    super.initState();
    otherController = SelectbaseController(element: widget.element);
  }

  @override
  Widget build(BuildContext context) {
    final formArray = getFormArray();

    final List<Widget> list = <Widget>[];

    //
    // ---- SELECT ALL ----
    //
    if ((widget.element.showSelectAllItem ?? false)) {
      String? text = widget.element.selectAllText?.getLocalizedText(context) ??
          S.of(context).selectAllText;

      list.add(
        CheckboxListTile(
          value: CheckBoxElement.allChecked(choices, formArray.controls),
          title: Text(text),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: isReadOnly
              ? null
              : (v) {
                  formArray.clear();
                  otherController.setShowOther(false);
                  if (v == true) {
                    formArray.addAll(choices
                        .map((choice) => FormControl<Object>(
                              value: choice.value?.value,
                            ))
                        .toList());
                  }
                  formArray.markAsTouched();
                },
        ),
      );
    }

    //
    // ---- NORMAL CHOICES ----
    //
    for (s.Itemvalue item in choices) {
      list.add(
        CheckboxListTile(
          value: formArray.controls.any((c) => c.value == item.value?.value),
          title: Text(item.text?.getLocalizedText(context) ??
              item.value?.toString() ??
              ''),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v == true) {
                    CheckBoxElement.excludeFrom(formArray, noneValue);
                    formArray
                        .add(FormControl<Object>(value: item.value?.value));
                  } else {
                    final rs = formArray.controls
                        .where((c) => c.value == item.value?.value)
                        .toList();
                    for (var r in rs) {
                      formArray.remove(r);
                    }
                  }
                  formArray.markAsTouched();
                },
        ),
      );
    }

    //
    // ---- NONE ITEM ----
    //
    if (otherController.showNone) {
      String? text = widget.element.noneText?.getLocalizedText(context) ??
          S.of(context).noneItemText;

      list.add(
        CheckboxListTile(
          value: formArray.controls.any((c) => c.value == noneValue),
          title: Text(text),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v == true) {
                    formArray.clear();
                    formArray.add(FormControl<Object>(value: noneValue));
                  } else {
                    CheckBoxElement.excludeFrom(formArray, noneValue);
                  }
                  formArray.markAsTouched();
                },
        ),
      );
    }

    //
    // ---- OTHER ITEM ----
    //
    if (widget.element.showOtherItem ?? false) {
      String? text = otherController.getOtherLocaledText(context);

      list.add(
        CheckboxListTile(
          key: const Key('other-checkbox-list-tile'),
          value: otherController.showOther,
          title: Text(text),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: isReadOnly
              ? null
              : (v) {
                  setState(() {
                    if (v != null) {
                      otherController.setShowOther(v);
                      if (!v) {
                        final otherControl = formArray.controls.firstWhere(
                            (c) => c.value == otherValue,
                            orElse: () => fb.control(null));
                        if (otherControl != null) {
                          formArray.remove(otherControl);
                        }
                      } else {
                        if (!formArray.controls
                            .any((c) => c.value == otherValue)) {
                          formArray.add(FormControl<Object>(value: otherValue));
                        }
                      }
                    }
                  });
                },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list,
    );
  }
}
