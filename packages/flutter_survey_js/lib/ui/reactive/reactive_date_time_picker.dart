import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart' hide Text, TextInputType;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:reactive_forms/reactive_forms.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum ReactiveDatePickerFieldType { date, time, dateTime }

typedef GetInitialDate = DateTime Function(DateTime? fieldValue, DateTime lastDate);
typedef GetInitialTime = TimeOfDay Function(DateTime? fieldValue);

class ReactiveDateTimePicker extends ReactiveFormField<String, String> {
  ReactiveDateTimePicker({
    Key? key,
    String? formControlName,
    FormControl<String>? formControl,
    ControlValueAccessor<String, String>? valueAccessor,
    Map<String, ValidationMessageFunction>? validationMessages,
    ShowErrorsFunction? showErrors,

    // UI params
    TextStyle? style,
    ReactiveDatePickerFieldType type = ReactiveDatePickerFieldType.date,
    InputDecoration? decoration,
    bool showClearIcon = true,

    // Date picker params
    DateTime? firstDate,
    DateTime? lastDate,
    Locale? locale,
    TransitionBuilder? builder,
    bool useRootNavigator = true,
    String? cancelText,
    String? confirmText,
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
          child: const Icon(Icons.clear),
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
          DateTime? date;
          TimeOfDay? time;

          final fieldDateTime = field.control.value.tryCastToDateTime();

          if (type == ReactiveDatePickerFieldType.date ||
              type == ReactiveDatePickerFieldType.dateTime) {
            final jalaliInitial = fieldDateTime != null
                ? Jalali.fromDateTime(fieldDateTime)
                : Jalali.now();
            final jalaliFirst =
            firstDate != null ? Jalali.fromDateTime(firstDate) : Jalali(1300, 1);
            final jalaliLast = lastDate != null
                ? Jalali.fromDateTime(lastDate)
                : Jalali(1500, 12);

            date = await showDialog<DateTime>(
              context: field.context,
              builder: (_) => _PersianCalendarDialog(
                initial: jalaliInitial,
                first: jalaliFirst,
                last: jalaliLast,
              ),
            );
          }

          if (type == ReactiveDatePickerFieldType.time ||
              (type == ReactiveDatePickerFieldType.dateTime && date != null)) {
            time = await showTimePicker(
              context: field.context,
              initialTime: _getInitialTime(fieldDateTime),
              builder: builder,
              useRootNavigator: useRootNavigator,
              cancelText: cancelText,
              confirmText: confirmText,
            );
          }

          if ((type == ReactiveDatePickerFieldType.dateTime &&
              date != null &&
              time != null) ||
              (type == ReactiveDatePickerFieldType.date && date != null) ||
              (type == ReactiveDatePickerFieldType.time && time != null)) {
            final dateTime = _combine(date, time);
            field.didChange(dateTime.toIso8601String());
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
            _formatPersianDate(field.value),
            style: Theme.of(field.context).textTheme.titleMedium?.merge(style),
          ),
        ),
      );
    },
  );

  static DateTime _combine(DateTime? date, TimeOfDay? time) {
    if (date == null) return DateTime.now();
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static TimeOfDay _getInitialTime(DateTime? date) =>
      date != null ? TimeOfDay(hour: date.hour, minute: date.minute) : TimeOfDay.now();

  static String _formatPersianDate(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value);
      final jalali = Jalali.fromDateTime(dt);
      return '${jalali.year}/${jalali.month}/${jalali.day}';
    } catch (_) {
      return value;
    }
  }
}

extension _CastToDateTime on String {
  DateTime? tryCastToDateTime() {
    try {
      return DateTime.parse(this);
    } catch (_) {
      return null;
    }
  }
}

class _PersianCalendarDialog extends StatefulWidget {
  final Jalali initial;
  final Jalali first;
  final Jalali last;

  const _PersianCalendarDialog({
    Key? key,
    required this.initial,
    required this.first,
    required this.last,
  }) : super(key: key);

  @override
  State<_PersianCalendarDialog> createState() => _PersianCalendarDialogState();
}

class _PersianCalendarDialogState extends State<_PersianCalendarDialog> {
  late Jalali _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        height: 350,
        width: 320,
        child: Column(
          children: [
            Expanded(
              child: CalendarDatePicker(
                initialDate: _selected.toDateTime(),
                firstDate: widget.first.toDateTime(),
                lastDate: widget.last.toDateTime(),
                onDateChanged: (val) => setState(() => _selected = Jalali.fromDateTime(val)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _selected.toDateTime()),
              child: const Text('تایید'),
            )
          ],
        ),
      ),
    );
  }
}
