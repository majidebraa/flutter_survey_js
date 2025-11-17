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
  final FutureOr<void> Function(dynamic data)? onSubmit;
  final FutureOr<void> Function(dynamic data)? onErrors;
  final ValueSetter<Map<String, Object?>?>? onChange;

  /// cancel/reject kept as no-arg callbacks (existing behavior)
  final FutureOr<void> Function()? onCancel;
  final FutureOr<void> Function()? onReject;

  /// Workflow callbacks that accept payload (cleaned form data)
  final FutureOr<void> Function(dynamic data)? onApprove;
  final FutureOr<void> Function(dynamic data)? onNo;
  final FutureOr<void> Function(dynamic data)? onOK;
  final FutureOr<void> Function(dynamic data)? onCompleted;
  final FutureOr<void> Function(dynamic data)? onAccept;
  final FutureOr<void> Function(dynamic data)? onDefer;
  final FutureOr<void> Function(dynamic data)? onSendToExpert;
  final FutureOr<void> Function()? onBack;

  final SurveyController? controller;
  final WidgetBuilder? builder;
  final bool removingEmptyFields;

  const SurveyWidget({
    Key? key,
    required this.survey,
    this.answer,
    this.onSubmit,
    this.onErrors,
    this.onChange,
    this.onCancel,
    this.onReject,
    this.onApprove,
    this.onNo,
    this.onOK,
    this.onCompleted,
    this.onAccept,
    this.onDefer,
    this.onSendToExpert,
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
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, Object?>?> snapshot) {
            return SurveyProvider(
              survey: widget.survey,
              formGroup: formGroup,
              rootNode: rootNode,
              currentPage: currentPage,
              initialPage: initialPage,
              child: Builder(
                  builder: (context) =>
                      (widget.builder ?? defaultBuilder)(context)),
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
        isRootSurvey: true);

    constructElementNode(context, rootNode);

    _listener = formGroup.valueChanges.listen((event) {
      rerunExpression(event ?? {});
      widget.onChange?.call(event == null ? null : removeEmptyField(event));
    });
    _setAnswer(widget.answer);
    rerunExpression(removeEmptyField(formGroup.value));
    pageCount = widget.survey.getPageCount();
  }

  bool submit() {
    if (formGroup.valid) {
      widget.onSubmit?.call(widget.removingEmptyFields
          ? removeEmptyField(formGroup.value)
          : formGroup.value);
      return true;
    } else {
      widget.onErrors?.call(formGroup.errors);
      formGroup.markAllAsTouched();
      return false;
    }
  }

  void cancel() {
    widget.onCancel?.call();
  }

  void reject() {
    widget.onReject?.call();
  }

  // --- NEW workflow actions (send cleaned form data) ---
  void approve() {
    widget.onApprove?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void no() {
    widget.onNo?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void ok() {
    widget.onOK?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void completed() {
    widget.onCompleted?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void accept() {
    widget.onAccept?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void defer() {
    widget.onDefer?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void sendToExpert() {
    widget.onSendToExpert?.call(widget.removingEmptyFields
        ? removeEmptyField(formGroup.value)
        : formGroup.value);
  }

  void back() {
    widget.onBack?.call();
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
    assert(_widget_state_null_check(), // defensive assert helper below
    "Don't use one SurveyController to multiple SurveyWidget");
    _widgetState = state;
  }

  // small helper to keep analyzer happy in assert message
  bool _widget_state_null_check() => _widgetState == null;

  void _detach() {
    _widgetState = null;
  }

  bool submit() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.submit();
  }

  void cancel() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.cancel();
  }

  void reject() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.reject();
  }

  // --- NEW controller helpers for workflow actions ---
  void approve() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.approve();
  }

  void no() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.no();
  }

  void ok() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.ok();
  }

  void completed() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.completed();
  }

  void accept() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.accept();
  }

  void defer() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.defer();
  }

  void sendToExpert() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.sendToExpert();
  }

  void back(){
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.sendToExpert();
  }

  bool nextPageOrBack() {
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
