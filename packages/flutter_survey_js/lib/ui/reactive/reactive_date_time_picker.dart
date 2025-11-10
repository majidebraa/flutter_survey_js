import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart'
    hide Text, TextInputType;

import 'package:intl/intl.dart' hide TextDirection;
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';

enum ReactiveDatePickerFieldType {
  date,
  time,
  dateTime,
}

typedef GetInitialDate = DateTime Function(
    DateTime? fieldValue, DateTime lastDate);

typedef GetInitialTime = TimeOfDay Function(DateTime? fieldValue);

class ReactiveDateTimePicker extends ReactiveFormField<String, String> {
  ReactiveDateTimePicker({
    Key? key,
    String? formControlName,
    FormControl<String>? formControl,
    ControlValueAccessor<String, String>? valueAccessor,
    Map<String, ValidationMessageFunction>? validationMessages,
    ShowErrorsFunction? showErrors,

    // UI
    TextStyle? style,
    ReactiveDatePickerFieldType type = ReactiveDatePickerFieldType.date,
    InputDecoration? decoration,
    bool showClearIcon = true,
    Widget clearIcon = const Icon(Icons.clear),

    // Picker parameters
    TransitionBuilder? builder,
    bool useRootNavigator = true,
    String? cancelText,
    String? confirmText,
    String? helpText,
    GetInitialDate? getInitialDate,
    GetInitialTime? getInitialTime,
    DateFormat? dateFormat,
    double disabledOpacity = 0.5,
    DateTime? firstDate,
    DateTime? lastDate,
    SelectableDayPredicate? selectableDayPredicate,
  }) : super(
    key: key,
    formControl: formControl,
    formControlName: formControlName,
    validationMessages: validationMessages,
    valueAccessor: valueAccessor,
    showErrors: showErrors,
    builder: (field) {
      Widget? suffixIcon = decoration?.suffixIcon;
      final isEmptyValue =
          field.value == null || field.value?.isEmpty == true;

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

      final InputDecoration effectiveDecoration =
      (decoration ?? const InputDecoration())
          .applyDefaults(Theme.of(field.context).inputDecorationTheme)
          .copyWith(suffixIcon: suffixIcon);
      final effectiveValueAccessor =
      _effectiveValueAccessor(type, dateFormat);
      final effectiveLastDate = lastDate ?? DateTime(2100);

      return IgnorePointer(
        ignoring: !field.control.enabled,
        child: Opacity(
          opacity: field.control.enabled ? 1 : disabledOpacity,
          child: GestureDetector(
            onTap: () async {
              DateTime? date;
              TimeOfDay? time;

              field.control.focus();
              field.control.updateValueAndValidity();

              final fieldDatetimeValue =
              field.control.value.tryCastToDateTime();

              // ---- PERSIAN DATE PICKER ----
              if (type == ReactiveDatePickerFieldType.date ||
                  type == ReactiveDatePickerFieldType.dateTime) {
                final jalaliDate = await showPersianDatePicker(
                  context: field.context,
                  initialDate: Jalali.fromDateTime(
                    (getInitialDate ?? _getInitialDate)(
                      fieldDatetimeValue,
                      effectiveLastDate,
                    ),
                  ),
                  firstDate: Jalali(1300, 1, 1),
                  lastDate: Jalali.fromDateTime(effectiveLastDate),
                  cancelText: cancelText,
                  confirmText: confirmText,
                  helpText: helpText,
                  builder: builder,
                );

                if (jalaliDate != null) {
                  date = jalaliDate.toDateTime();
                }
              }

              // ---- TIME PICKER ----
              if (type == ReactiveDatePickerFieldType.time ||
                  (type == ReactiveDatePickerFieldType.dateTime &&
                      date != null)) {
                time = await showTimePicker(
                  context: field.context,
                  initialTime: (getInitialTime ??
                      _getInitialTime)(fieldDatetimeValue),
                  builder: builder,
                  useRootNavigator: useRootNavigator,
                  cancelText: cancelText,
                  confirmText: confirmText,
                  helpText: helpText,
                );
              }

              // ---- COMBINE & UPDATE FIELD ----
              if ((type == ReactiveDatePickerFieldType.dateTime &&
                  (date != null && time != null)) ||
                  (type == ReactiveDatePickerFieldType.date &&
                      date != null) ||
                  (type == ReactiveDatePickerFieldType.time &&
                      time != null)) {
                final dateTime = _combine(date, time);

                final value = field.control.value.tryCastToDateTime();
                if (value == null || dateTime.compareTo(value) != 0) {
                  field.didChange(
                    effectiveValueAccessor.modelToViewValue(dateTime),
                  );
                }
              }

              field.control.unfocus();
              field.control.updateValueAndValidity();
              field.control.markAsTouched();
            },
            child: InputDecorator(
              decoration: effectiveDecoration.copyWith(
                errorText: field.errorText,
                enabled: field.control.enabled,
              ),
              isFocused: field.control.hasFocus,
              isEmpty: isEmptyValue,
              child: Text(
                field.value ?? '',
                style: Theme.of(field.context)
                    .textTheme
                    .titleMedium
                    ?.merge(style),
              ),
            ),
          ),
        ),
      );
    },
  );

  // --- Helper functions ---

  static DateTimeValueAccessor _effectiveValueAccessor(
      ReactiveDatePickerFieldType fieldType, DateFormat? dateFormat) {
    switch (fieldType) {
      case ReactiveDatePickerFieldType.date:
        return DateTimeValueAccessor(
          dateTimeFormat: dateFormat ?? DateFormat('yyyy-MM-dd'),
        );
      case ReactiveDatePickerFieldType.time:
        return DateTimeValueAccessor(
          dateTimeFormat: dateFormat ?? DateFormat('HH:mm'),
        );
      case ReactiveDatePickerFieldType.dateTime:
        return DateTimeValueAccessor(
          dateTimeFormat: dateFormat ?? DateFormat('yyyy-MM-dd HH:mm'),
        );
    }
  }

  static DateTime _combine(DateTime? date, TimeOfDay? time) {
    DateTime dateTime = DateTime(0);
    if (date != null) dateTime = dateTime.add(date.difference(dateTime));
    if (time != null)
      dateTime = dateTime.add(Duration(hours: time.hour, minutes: time.minute));
    return dateTime;
  }

  static DateTime _getInitialDate(DateTime? fieldValue, DateTime lastDate) {
    if (fieldValue != null) return fieldValue;
    final now = DateTime.now();
    return now.compareTo(lastDate) > 0 ? lastDate : now;
  }

  static TimeOfDay _getInitialTime(dynamic fieldValue) {
    if (fieldValue != null && fieldValue is DateTime) {
      return TimeOfDay(hour: fieldValue.hour, minute: fieldValue.minute);
    }
    return TimeOfDay.now();
  }
}
