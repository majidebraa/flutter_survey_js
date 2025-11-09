import 'package:built_value/json_object.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_survey_js/ui/elements/selectbase.dart';
import 'package:flutter_survey_js/ui/survey_configuration.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:reactive_forms/reactive_forms.dart';
import 'package:flutter_survey_js/utils.dart';
import '../../generated/l10n.dart';

Widget dropdownBuilder(BuildContext context, s.Elementbase element,
    {ElementConfiguration? configuration}) {
  final e = (element as s.Dropdown);

  return _DropdownWidget(
    dropdown: e,
  ).wrapQuestionTitle(context, e, configuration: configuration);
}

class _DropdownWidget<T> extends StatefulWidget {
  const _DropdownWidget({
    Key? key,
    required this.dropdown,
  }) : super(key: key);

  final s.Dropdown dropdown;

  @override
  State<_DropdownWidget> createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<_DropdownWidget> {
  AbstractControl getCurrentControl() {
    return ((ReactiveForm.of(context, listen: false) as FormControlCollection)
        .control(widget.dropdown.name!));
  }

  late SelectbaseController selectbaseController;
  @override
  void initState() {
    super.initState();
    selectbaseController = SelectbaseController(element: widget.dropdown);
    Future.microtask(() {
      final control = getCurrentControl();
      final value = control.value;
      if (selectbaseController.storeOtherAsComment) {
        selectbaseController.setShowOther(value == otherValue);
      }

      if (isOtherValue(value)) {
        //current value outside of choices
        if (selectbaseController.storeOtherAsComment) {
          control.value = otherValue;
          if (value?.toString() != otherValue) {
            selectbaseController.setOtherValue(value?.toString() ?? "");
          }
        } else {
          selectbaseController.setOtherValue(value?.toString() ?? "");
        }
      }
    });
  }

  List<s.Itemvalue> get choices {
    if (widget.dropdown.choicesMin != null &&
        widget.dropdown.choicesMax != null) {
      return List.generate(
          widget.dropdown.choicesMax!.toInt() -
              widget.dropdown.choicesMin!.toInt() +
              1, (index) {
        final v = widget.dropdown.choicesMin!.toInt() + index;
        final b = s.$ItemvalueBuilder()..value = JsonObject(v);
        return b.build();
      });
    } else {
      return widget.dropdown.choices
              ?.map((p0) => p0.castToItemvalue())
              .toList() ??
          [];
    }
  }

  bool isOtherValue(Object? value) {
    if (widget.dropdown.showNoneItem ?? false) {
      return value != null &&
          ![...choices.map((element) => element.value?.value), noneValue]
              .any((v) => v == value);
    } else {
      return value != null &&
          !choices
              .map((element) => element.value?.value)
              .any((v) => v == value);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final e = widget.dropdown;
    final control = getCurrentControl(); // reactive_forms control

    // Build items as strings and widgets
    final items = choices.map((choice) {
      final label = choice.text?.getLocalizedText(context) ??
          choice.value?.toString() ??
          '';
      return DropdownMenuItem<dynamic>(
        value: choice.value?.value,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }).toList();

    // None and Other items
    if (widget.dropdown.showNoneItem == true) {
      items.add(DropdownMenuItem<dynamic>(
        value: noneValue,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              e.noneText?.getLocalizedText(context) ?? S.of(context).noneItemText,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ));
    }
    if (widget.dropdown.showOtherItem == true) {
      items.add(DropdownMenuItem<dynamic>(
        value: selectbaseController.storeOtherAsComment ? otherValue : selectbaseController.otherValue,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              e.otherText?.getLocalizedText(context) ?? S.of(context).otherItemText,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ));
    }

    // Wrap in Directionality so hint & selected value appear RTL too
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SelectbaseWidget(
        controller: selectbaseController,
        otherValueChanged: (value) {
          if (!selectbaseController.storeOtherAsComment) {
            control.value = value;
          } else {
            control.value = otherValue;
          }
        },
        child: DropdownButtonHideUnderline(
          child: StreamBuilder<Object?>(
            // listen to control.value changes so UI updates when value changes
            stream: control.valueChanges,
            initialData: control.value,
            builder: (context, snapshot) {
              final currentValue = snapshot.data;

              return DropdownButton2<dynamic>(
                isExpanded: true,
                items: items,
                value: currentValue,
                onChanged: (val) {
                  // update reactive_forms control
                  control.value = val;
                  // handle showOther logic
                  if (widget.dropdown.showOtherItem ?? false) {
                    if (selectbaseController.storeOtherAsComment) {
                      selectbaseController.setShowOther(val == otherValue);
                    } else {
                      selectbaseController.setShowOther(isOtherValue(val));
                    }
                  } else {
                    selectbaseController.setShowOther(false);
                  }
                  if (widget.dropdown.showNoneItem ?? false && val == noneValue) {
                    selectbaseController.setShowOther(false);
                  }
                },

                // BUTTON appearance (selected value)
                buttonHeight: 48,
                buttonPadding: const EdgeInsets.symmetric(horizontal: 12),
                // show arrow on left for RTL
                icon: const Icon(Icons.arrow_drop_down),
                iconSize: 24,
                // Align button content (selected text) to the right
                buttonDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent),
                ),

                // DROPDOWN (overlay) appearance
                dropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Theme.of(context).cardColor,
                ),
                // Force alignment of the menu to the right side of the button
                alignment: Alignment.centerRight,
                // Optional: control dropdown width if needed:
                // dropdownWidth: MediaQuery.of(context).size.width * 0.8,
                // Optional: item height if items are taller
                itemHeight: 48,
                // Optional: max height
                dropdownMaxHeight: 300,
                // match the menu direction visually
                // (dropdown_button2 does not expose "direction", but alignment + iconOnLeft + Directionality works)
              );
            },
          ),
        ),
      ),
    );
  }

}
