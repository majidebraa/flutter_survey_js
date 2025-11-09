import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart' hide Text, TextInputType;
import 'package:reactive_forms/reactive_forms.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum ReactiveDatePickerFieldType { date, time, dateTime }

typedef GetInitialDate = DateTime Function(DateTime? fieldValue, DateTime lastDate);
typedef GetInitialTime = TimeOfDay Function(DateTime? fieldValue);

class ReactivePersianDateTimePicker extends ReactiveFormField<String, String> {
  ReactivePersianDateTimePicker({
    Key? key,
    String? formControlName,
    FormControl<String>? formControl,
    ControlValueAccessor<String, String>? valueAccessor,
    Map<String, ValidationMessageFunction>? validationMessages,
    ShowErrorsFunction? showErrors,

    TextStyle? style,
    ReactiveDatePickerFieldType type = ReactiveDatePickerFieldType.date,
    InputDecoration? decoration,
    bool showClearIcon = true,
    Widget clearIcon = const Icon(Icons.clear),
  }) : super(
    key: key,
    formControl: formControl,
    formControlName: formControlName,
    validationMessages: validationMessages,
    valueAccessor: valueAccessor,
    showErrors: showErrors,
    builder: (field) {
      Widget? suffixIcon = decoration?.suffixIcon;
      final isEmptyValue = field.value == null || field.value?.isEmpty == true;

      if (showClearIcon && !isEmptyValue) {
        suffixIcon = InkWell(
          borderRadius: BorderRadius.circular(25),
          child: clearIcon,
          onTap: () {
            field.control.markAsTouched();
            field.didChange(null);
          },
        );
      }

      final effectiveDecoration = (decoration ?? const InputDecoration())
          .applyDefaults(Theme.of(field.context).inputDecorationTheme)
          .copyWith(suffixIcon: suffixIcon);

      return GestureDetector(
        onTap: () async {
          field.control.focus();
          final picked = await showDialog<Jalali>(
            context: field.context,
            builder: (context) => _PersianDatePickerDialog(
              initialDate: field.value != null && field.value!.isNotEmpty
                  ? Jalali.fromDateTime(DateTime.parse(field.value!))
                  : Jalali.now(),
            ),
          );

          if (picked != null) {
            field.didChange(picked.toDateTime().toIso8601String());
          }
        },
        child: InputDecorator(
          decoration: effectiveDecoration.copyWith(
            errorText: field.errorText,
            enabled: field.control.enabled,
          ),
          isFocused: field.control.hasFocus,
          isEmpty: isEmptyValue,
          child: Text(
            field.value != null && field.value!.isNotEmpty
                ? _formatPersianDate(field.value!)
                : '',
            style: Theme.of(field.context).textTheme.titleMedium?.merge(style),
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    },
  );

  static String _formatPersianDate(String value) {
    try {
      final date = DateTime.parse(value);
      final jalali = Jalali.fromDateTime(date);
      return '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return value;
    }
  }
}

/// Simple Persian DatePicker dialog
class _PersianDatePickerDialog extends StatefulWidget {
  final Jalali initialDate;

  const _PersianDatePickerDialog({Key? key, required this.initialDate}) : super(key: key);

  @override
  State<_PersianDatePickerDialog> createState() => _PersianDatePickerDialogState();
}

class _PersianDatePickerDialogState extends State<_PersianDatePickerDialog> {
  late Jalali _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('انتخاب تاریخ', textAlign: TextAlign.center),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: CalendarDatePicker(
                  initialDate: _selectedDate.toDateTime(),
                  firstDate: Jalali(1300, 1, 1).toDateTime(),
                  lastDate: Jalali(1500, 12, 29).toDateTime(),
                  onDateChanged: (DateTime value) {
                    setState(() {
                      _selectedDate = Jalali.fromDateTime(value);
                    });
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_selectedDate),
                child: Text('تایید', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
