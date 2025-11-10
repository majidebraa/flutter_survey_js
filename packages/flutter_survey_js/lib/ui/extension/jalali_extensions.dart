import 'package:shamsi_date/shamsi_date.dart';

extension JalaliFormatting on Jalali {
  String formatCompact() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return "$y/$m/$d";
  }

  String formatFullDate() {
    // weekday name in Persian, starting from Saturday (1)
    const weekDays = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه'
    ];
    // month names in Persian
    const monthNames = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند'
    ];

    final wdIndex = this.weekDay - 1; // Jalali.weekDay is 1-based, Saturday=1
    final wdName =
        (wdIndex >= 0 && wdIndex < weekDays.length) ? weekDays[wdIndex] : '';
    final mName = (month >= 1 && month <= 12) ? monthNames[month - 1] : '';

    return '$wdName، $day $mName $year';
  }

  Jalali safeAddMonths(int monthsToAdd) {
    final base = Jalali(year, month, 1).addMonths(monthsToAdd);
    final maxDay = base.monthLength;
    final adjustedDay = day > maxDay ? maxDay : day;
    return Jalali(base.year, base.month, adjustedDay);
  }
}
