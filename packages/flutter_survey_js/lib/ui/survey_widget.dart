import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_survey_js/flutter_survey_js.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:logging/logging.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'element_node.dart';

Widget defaultBuilder(BuildContext context) {
  return const SurveyLayout();
}

class SurveyWidget extends StatefulWidget {
  final s.Survey survey;
  final Map<String, Object?>? answer;

  /// Generic error callback (keeps original behavior for form errors)
  final FutureOr<void> Function(dynamic data)? onErrors;

  /// value change callback
  final ValueSetter<Map<String, Object?>?>? onChange;

  /// Universal outcome callbacks: key is the outcome name (e.g. "SUBMIT", "APPROVE")
  /// value is a callback that receives cleaned form data (Map) or any payload you expect.
  final Map<String, FutureOr<void> Function(dynamic data)>? outcomeCallbacks;

  /// optional back action (no payload)
  final FutureOr<void> Function()? onBack;

  final SurveyController? controller;
  final WidgetBuilder? builder;
  final bool removingEmptyFields;

  const SurveyWidget({
    Key? key,
    required this.survey,
    this.answer,
    this.onErrors,
    this.onChange,
    this.outcomeCallbacks,
    this.onBack,
    this.controller,
    this.builder,
    this.removingEmptyFields = true,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => SurveyWidgetState();
}

class SurveyWidgetState extends State<SurveyWidget> {
  final Logger logger = Logger('SurveyWidgetState');

  late int pageCount;

  StreamSubscription<Map<String, Object?>?>? _listener;

  int _currentPage = 0;

  // TODO calculate initial page
  int initialPage = 0;

  int get currentPage => _currentPage;

  late ElementNode rootNode;

  FormGroup get formGroup => rootNode.control as FormGroup;

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);
    rebuildForm();
  }

  static SurveyWidgetState of(BuildContext context) {
    return context.findAncestorStateOfType<SurveyWidgetState>()!;
  }

  void toPage(int newPage) {
    final p = max(0, min(pageCount - 1, newPage));
    setState(() {
      _currentPage = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SurveyConfiguration.copyAncestor(
      context: context,
      child: ReactiveForm(
        formGroup: formGroup,
        child: StreamBuilder(
          stream: formGroup.valueChanges,
          builder:
              (BuildContext context, AsyncSnapshot<Map<String, Object?>?> snapshot) {
            return SurveyProvider(
              survey: widget.survey,
              formGroup: formGroup,
              rootNode: rootNode,
              currentPage: currentPage,
              initialPage: initialPage,
              child: Builder(
                  builder: (context) => (widget.builder ?? defaultBuilder)(context)),
            );
          },
        ),
      ),
    );
  }

  void rerunExpression(Map<String, Object?> values) {
    rootNode.runExpression(values, {});
  }

  void rebuildForm() {
    logger.fine("Rebuild form");
    _listener?.cancel();
    _currentPage = 0;
    rootNode = ElementNode(
      element: null,
      rawElement: null,
      survey: widget.survey,
      isRootSurvey: true,
    );

    constructElementNode(context, rootNode);

    _listener = formGroup.valueChanges.listen((event) {
      rerunExpression(event ?? {});
      widget.onChange?.call(event == null ? null : removeEmptyField(event));
    });
    _setAnswer(widget.answer);
    rerunExpression(removeEmptyField(formGroup.value));
    pageCount = widget.survey.getPageCount();
  }

  /// Submits: when the form is valid we call the SUBMIT outcome callback if present.
  bool submit() {
    if (formGroup.valid) {
      final data =
      widget.removingEmptyFields ? removeEmptyField(formGroup.value) : formGroup.value;
      _callOutcomeCallback('SUBMIT', data);
      return true;
    } else {
      widget.onErrors?.call(formGroup.errors);
      formGroup.markAllAsTouched();
      return false;
    }
  }

  /// Back navigation (no payload)
  void back() {
    if (widget.onBack != null) {
      widget.onBack?.call();
      return;
    }
    // if onBack not provided, default to go to previous page
    if (_currentPage > 0) {
      toPage(_currentPage - 1);
      return;
    }
    // otherwise try to call a BACK/NO outcome if present
    _callOutcomeCallback('NO', null);
  }

  /// Generic "trigger outcome" - looks up callback by key (case-insensitive)
  void triggerOutcome(String outcomeType) {
    final data =
    widget.removingEmptyFields ? removeEmptyField(formGroup.value) : formGroup.value;
    _callOutcomeCallback(outcomeType, data);
  }

  void _callOutcomeCallback(String outcomeType, dynamic data) {
    if (widget.outcomeCallbacks == null) return;

    // try exact, uppercase, lowercase keys
    FutureOr<void> Function(dynamic)? cb = widget.outcomeCallbacks![outcomeType];
    cb ??= widget.outcomeCallbacks![outcomeType.toUpperCase()];
    cb ??= widget.outcomeCallbacks![outcomeType.toLowerCase()];

    if (cb != null) {
      try {
        cb(data);
      } catch (e, st) {
        logger.warning('Error calling outcome callback for $outcomeType: $e\n$st');
      }
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    widget.controller?._detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SurveyWidget oldWidget) {
    if (oldWidget.survey != widget.survey) {
      rebuildForm();
    } else if (oldWidget.answer != widget.answer) {
      _setAnswer(widget.answer);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _setAnswer(Map<String, Object?>? answer) {
    if (widget.answer != null) {
      formGroup.patchValue(widget.answer);
    }
  }

  /// Next page or call "back" (the original code used nextPageOrBack semantics).
  bool nextPageOrBack() {
    final bool finished = _currentPage >= pageCount - 1;
    if (!finished) {
      toPage(_currentPage + 1);
    } else {
      back();
    }
    return finished;
  }
}

class SurveyProvider extends InheritedWidget {
  final s.Survey survey;
  final FormGroup formGroup;

  final int currentPage;
  final int initialPage;

  final ElementNode rootNode;

  const SurveyProvider({
    Key? key,
    required Widget child,
    required this.survey,
    required this.formGroup,
    required this.rootNode,
    required this.currentPage,
    required this.initialPage,
  }) : super(key: key, child: child);

  static SurveyProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SurveyProvider>()!;
  }

  @override
  bool updateShouldNotify(covariant SurveyProvider oldWidget) => true;
}

class SurveyController {
  SurveyWidgetState? _widgetState;

  int get currentPage {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!._currentPage;
  }

  int get pageCount {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.pageCount;
  }

  void _bind(SurveyWidgetState state) {
    assert(_widget_state_null_check(),
    "Don't use one SurveyController to multiple SurveyWidget");
    _widgetState = state;
  }

  // small helper to keep analyzer happy in assert message
  bool _widget_state_null_check() => _widgetState == null;

  void _detach() {
    _widgetState = null;
  }

  /// Trigger SUBMIT (calls outcome callback if present)
  bool submit() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.submit();
  }

  /// Trigger arbitrary outcome by name (e.g. "APPROVE", "REJECT")
  void triggerOutcome(String outcomeType) {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.triggerOutcome(outcomeType);
  }

  /// Back navigation (calls onBack or previous page)
  void back() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.back();
  }

  bool nextPageOrSubmit() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.nextPageOrBack();
  }

  void prePage() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    toPage(currentPage - 1);
  }

  void toPage(int newPage) {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.toPage(newPage);
  }
}

extension SurveyExtension on s.Survey {
  int getPageCount() {
    return (pages?.toList() ?? []).length;
  }
}
