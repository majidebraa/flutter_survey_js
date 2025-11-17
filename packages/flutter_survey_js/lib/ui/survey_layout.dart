import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_survey_js/generated/l10n.dart';
import 'package:flutter_survey_js/ui/survey_page_widget.dart';
import 'package:flutter_survey_js/ui/survey_widget.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;
import 'package:im_stepper/stepper.dart';
import 'package:logging/logging.dart';
import 'package:flutter_survey_js/utils.dart';

Widget defaultSurveyTitleBuilder(BuildContext context, s.Survey survey) {
  if (survey.title?.getLocalizedText(context) != null) {
    return ListTile(
      title: Text(
        survey.title!.getLocalizedText(context)!,
        textDirection: TextDirection.rtl,
      ),
    );
  }
  return Container();
}

Widget defaultStepperBuilder(BuildContext context, int pageCount, int currentPage) {
  if (pageCount > 1) {
    return DotStepper(
      dotCount: pageCount,
      dotRadius: 12,
      activeStep: currentPage,
      shape: Shape.circle,
      spacing: 10,
      indicator: Indicator.shift,
      onDotTapped: (tappedDotIndex) async {
        SurveyWidgetState.of(context).toPage(tappedDotIndex);
      },
      indicatorDecoration: IndicatorDecoration(
        color: Theme.of(context).primaryColor,
        strokeColor: Theme.of(context).primaryColor,
      ),
    );
  }
  return Container();
}

class SurveyLayout extends StatefulWidget {
  final Widget Function(BuildContext context, s.Survey survey)? surveyTitleBuilder;
  final Widget Function(BuildContext context, int pageCount, int currentPage)? stepperBuilder;
  final Widget Function(BuildContext context, s.Page page)? pageBuilder;
  final EdgeInsets? padding;

  final List<String>? outcomeList;

  const SurveyLayout({
    Key? key,
    this.surveyTitleBuilder,
    this.stepperBuilder,
    this.pageBuilder,
    this.padding,
    this.outcomeList,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => SurveyLayoutState();
}

class SurveyLayoutState extends State<SurveyLayout> {
  final Logger logger = Logger('SurveyLayoutState');
  late PageController? pageController;

  s.Survey get survey => SurveyProvider.of(context).survey;

  int get pageCount => survey.getPageCount();
  int get currentPage => SurveyProvider.of(context).currentPage;

  @override
  void initState() {
    pageController = PageController(keepPage: true);
    pageController!.addListener(() {
      SurveyWidgetState.of(context).toPage(pageController!.page!.toInt());
    });
    super.initState();
  }

  Future<void> toPage(int newPage) async {
    SurveyWidgetState.of(context).toPage(newPage);
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SurveyProvider.of(context).initialPage != pageController?.initialPage) {
        pageController?.jumpToPage(SurveyProvider.of(context).initialPage);
      }
      if (SurveyProvider.of(context).currentPage != pageController?.page?.toInt()) {
        pageController?.jumpToPage(SurveyProvider.of(context).currentPage);
      }
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final surveyWidgetState = SurveyWidgetState.of(context);
    final currentPage = surveyWidgetState.currentPage;
    final pages = reCalculatePages(survey);

    final latestUnfinished = SurveyProvider.of(context)
        .rootNode
        .findByCondition((node) => node.isLatestUnfinishedQuestion == true);

    return Column(
      children: [
        widget.surveyTitleBuilder != null
            ? widget.surveyTitleBuilder!(context, survey)
            : defaultSurveyTitleBuilder(context, survey),
        Expanded(
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(8.0),
            child: Column(
              children: [
                (widget.stepperBuilder ?? defaultStepperBuilder)(
                    context, pageCount, currentPage),
                Expanded(
                  child: buildPages(pages,
                      intialPageIndex: latestUnfinished?.pageIndex,
                      intialQuestionIndexInPage:
                      latestUnfinished?.indexInPage ?? 0),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // dynamically build outcome buttons
                    ..._buildOutcomeButtons(context),

                    if (currentPage != 0) previousButton(),
                    nextButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOutcomeButtons(BuildContext context) {
    final widgetSurvey = SurveyWidgetState.of(context).widget;
    final Map<String, FutureOr<void> Function(dynamic)>? callbacks =
        widgetSurvey.outcomeCallbacks;



    // fallback: nothing
    if (widget.outcomeList == null || widget.outcomeList!.isEmpty) return [];

    // map each outcome to a button if callback exists (case-insensitive lookup)
    final List<Widget> buttons = [];
    for (final raw in widget.outcomeList!) {
      final String type = raw.toString();
      final String upper = type.toUpperCase();

      // find callback (accept upper/lower/exact)
      final cb = callbacks == null
          ? null
          : (callbacks[type] ?? callbacks[upper] ?? callbacks[type.toLowerCase()]);

      if (cb == null) {
        // do not show button if no callback
        continue;
      }

      final label = _labelForOutcome(upper);
      final icon = _iconForOutcome(upper);
      final color = _colorForOutcome(upper);

      buttons.add(
        actionButton(
          label: label,
          icon: icon,
          color: color,
          onPressed: () {
            // call the widget state to ensure form cleaning is consistent
            SurveyWidgetState.of(context).triggerOutcome(type);
          },
        ),
      );
    }

    return buttons;
  }

  Widget buildPages(List<s.Page> pages,
      {int? intialPageIndex, int intialQuestionIndexInPage = 0}) {
    Widget itemBuilder(BuildContext context, int index) {
      final currentPage = pages[index];
      return widget.pageBuilder != null
          ? widget.pageBuilder!(context, currentPage)
          : SurveyPageWidget(
        page: currentPage,
        initIndex:
        (intialPageIndex == index) ? intialQuestionIndexInPage : 0,
        key: ObjectKey(index),
      );
    }

    return PageView.builder(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: itemBuilder,
      itemCount: pages.length,
    );
  }

  Widget nextButton() {
    final bool finished = currentPage >= pageCount - 1;

    return actionButton(
      label: finished ? "بازگشت" : S.of(context).nextPage,
      icon: Icons.exit_to_app,
      color: Colors.blueGrey,
      onPressed: () => SurveyWidgetState.of(context).nextPageOrBack(),
    );
  }

  Widget previousButton() {
    return actionButton(
      label: S.of(context).previousPage,
      icon: Icons.skip_previous,
      color: Colors.blueGrey,
      onPressed: () => toPage(currentPage - 1),
    );
  }

  // Helper to render action buttons consistently
  Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  // outcome -> Persian label map
  String _labelForOutcome(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUBMIT':
        return 'ثبت و ارسال';
      case 'NO':
        return 'انصراف از درخواست';
      case 'ACCEPT':
        return 'قبول';
      case 'COMPLETED':
        return 'تکمیل فرآیند';
      case 'OK':
        return 'مشاهده شد';
      case 'REJECT':
        return 'عدم تایید';
      case 'APPROVE':
        return 'تایید';
      case 'DEFER':
        return 'بازگشت جهت اصلاح';
      case 'SENDTOEXPERT':
        return 'ارسال جهت کارشناسی';
      default:
        return outcome;
    }
  }

  // outcome -> icon map
  IconData _iconForOutcome(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUBMIT':
        return Icons.send;
      case 'NO':
        return Icons.close;
      case 'ACCEPT':
        return Icons.thumb_up_alt;
      case 'COMPLETED':
        return Icons.done_all;
      case 'OK':
        return Icons.visibility;
      case 'REJECT':
        return Icons.cancel;
      case 'APPROVE':
        return Icons.check_circle;
      case 'DEFER':
        return Icons.undo;
      case 'SENDTOEXPERT':
        return Icons.engineering;
      default:
        return Icons.help_outline;
    }
  }

  // outcome -> color map
  Color _colorForOutcome(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'SUBMIT':
        return Colors.green;
      case 'NO':
        return Colors.deepOrange;
      case 'ACCEPT':
        return Colors.green.shade700;
      case 'COMPLETED':
        return Colors.teal;
      case 'OK':
        return Colors.indigo;
      case 'REJECT':
        return Colors.red.shade700;
      case 'APPROVE':
        return Colors.blue;
      case 'DEFER':
        return Colors.amber.shade800;
      case 'SENDTOEXPORT':
      case 'SENDTOEXPERT':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  void dispose() {
    pageController?.dispose();
    super.dispose();
  }
}
