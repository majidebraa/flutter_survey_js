// lib/ui/survey_widget.dart
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
  final List<String>? outcomeList;

  const SurveyWidget({
    Key? key,
    required this.survey,
    this.answer,
    this.onErrors,
    this.onChange,
    this.outcomeCallbacks,
    this.onBack,
    this.outcomeList,
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

  /// root node is nullable while initialization occurs
  ElementNode? rootNode;

  /// whether widget is ready to build (runner initialized + form constructed)
  bool _ready = false;

  FormGroup get formGroup {
    assert(_ready && rootNode != null,
        'FormGroup requested before widget is ready. Wait until widget is ready.');
    final group = rootNode!.control;
    if (group == null || group is! FormGroup) {
      throw StateError('rootNode.control is not a FormGroup');
    }
    return group as FormGroup;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);

    // Initialize runner (JS engine) and then build the form tree.
    // We intentionally do this async so the widget can show a loading state
    // while the engine loads.
    (() async {
      try {
        await getRunner().init();
      } catch (e, st) {
        // initialization error - log but continue. UI will still try to build.
        logger.warning('Runner.init() failed: $e\n$st');
      }

      // Build the form tree and start listening to changes.
      rebuildForm();

      // Mark widget ready and trigger build.
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    })();
  }

  static SurveyWidgetState of(BuildContext context) {
    return context.findAncestorStateOfType<SurveyWidgetState>()!;
  }

  void toPage(int newPage) {
    final p = max(0, min(pageCount - 1, newPage));
    if (_currentPage == p) return;
    setState(() {
      _currentPage = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || rootNode == null) {
      // show a simple loading indicator while runner/form initializes
      return Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return SurveyConfiguration.copyAncestor(
      context: context,
      child: ReactiveForm(
        formGroup: formGroup,
        child: StreamBuilder<Map<String, Object?>?>(
          stream: formGroup.valueChanges,
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, Object?>?> snapshot) {
            return SurveyProvider(
              survey: widget.survey,
              formGroup: formGroup,
              rootNode: rootNode!,
              currentPage: currentPage,
              initialPage: initialPage,
              child: Builder(builder: (context) {
                return (widget.builder ?? defaultBuilder)(context);
              }),
            );
          },
        ),
      ),
    );
  }

  /// rerun expression evaluation from root for given values (usually form values).
  void rerunExpression(Map<String, Object?> values) {
    if (rootNode == null) return;
    // pass empty properties for now
    rootNode!.runExpression(values, {});
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

    constructElementNode(context, rootNode!);

    // listen to value changes and re-evaluate expressions
    _listener = (rootNode!.control as FormGroup).valueChanges.listen((event) {
      final values = event ?? <String, Object?>{};
      rerunExpression(values);
      widget.onChange?.call(values.isEmpty ? null : removeEmptyField(values));
    });

    // apply provided answer
    _setAnswer(widget.answer);

    // ensure expressions are evaluated at least once
    try {
      rerunExpression(removeEmptyField((rootNode!.control as FormGroup).value));
    } catch (e) {
      logger.fine('Initial rerunExpression error: $e');
    }

    pageCount = widget.survey.getPageCount();
  }

  /// Submits: when the form is valid we call the SUBMIT outcome callback if present.
  bool submit() {
    if (rootNode == null) return false;
    if (formGroup.valid) {
      final data = widget.removingEmptyFields
          ? removeEmptyField(formGroup.value)
          : formGroup.value;
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
    final data = widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value;
    _callOutcomeCallback(outcomeType, data);
  }

  void _callOutcomeCallback(String outcomeType, dynamic data) {
    if (widget.outcomeCallbacks == null) return;

    // try exact, uppercase, lowercase keys
    FutureOr<void> Function(dynamic)? cb =
        widget.outcomeCallbacks![outcomeType];
    cb ??= widget.outcomeCallbacks![outcomeType.toUpperCase()];
    cb ??= widget.outcomeCallbacks![outcomeType.toLowerCase()];

    if (cb != null) {
      try {
        final res = cb(data);
        if (res is Future) {
          // optional: don't await here to avoid blocking UI
          res.catchError(
              (e, st) => logger.warning('Outcome callback error: $e\n$st'));
        }
      } catch (e, st) {
        logger.warning(
            'Error calling outcome callback for $outcomeType: $e\n$st');
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
    super.didUpdateWidget(oldWidget);
    if (oldWidget.survey != widget.survey) {
      // rebuild full form if survey changes
      rebuildForm();
    } else if (oldWidget.answer != widget.answer) {
      _setAnswer(widget.answer);
    }
  }

  void _setAnswer(Map<String, Object?>? answer) {
    if (answer != null && rootNode != null && rootNode!.control is FormGroup) {
      try {
        (rootNode!.control as FormGroup).patchValue(answer);
      } catch (e) {
        logger.warning('Error patching answer: $e');
      }
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
    // Only bind if not already bound to another state
    assert(_widgetState == null,
        "Don't bind a SurveyController to multiple SurveyWidgets");
    _widgetState = state;
  }

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
