// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `صفحه بعدی`
  String get nextPage {
    return Intl.message('صفحه بعدی', name: 'nextPage', desc: '', args: []);
  }

  /// `صفحه قبلی`
  String get previousPage {
    return Intl.message('صفحه قبلی', name: 'previousPage', desc: '', args: []);
  }

  /// `تایید`
  String get submitSurvey {
    return Intl.message('تایید', name: 'submitSurvey', desc: '', args: []);
  }

  /// `اضافه کردن`
  String get add {
    return Intl.message('اضافه کردن', name: 'add', desc: '', args: []);
  }

  /// `پاک کردن`
  String get remove {
    return Intl.message('پاک کردن', name: 'remove', desc: '', args: []);
  }

  /// `انتخاب کنید`
  String get placeholder {
    return Intl.message('انتخاب کنید', name: 'placeholder', desc: '', args: []);
  }

  /// `دیگر(توضیح دهید)`
  String get otherItemText {
    return Intl.message(
      'دیگر(توضیح دهید)',
      name: 'otherItemText',
      desc: '',
      args: [],
    );
  }

  /// `هیچکدام`
  String get noneItemText {
    return Intl.message('هیچکدام', name: 'noneItemText', desc: '', args: []);
  }

  /// `انتخاب همه`
  String get selectAllText {
    return Intl.message(
      'انتخاب همه',
      name: 'selectAllText',
      desc: '',
      args: [],
    );
  }

  /// `رد`
  String get reject {
    return Intl.message('رد', name: 'reject', desc: '', args: []);
  }

  /// `لغو`
  String get cancel {
    return Intl.message('لغو', name: 'cancel', desc: '', args: []);
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'fa'),
      Locale.fromSubtags(languageCode: 'fr'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
