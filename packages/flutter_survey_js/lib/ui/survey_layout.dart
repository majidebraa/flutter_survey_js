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

Widget defaultStepperBuilder(
    BuildContext context, int pageCount, int currentPage) {
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
  final Widget Function(BuildContext context, s.Survey survey)?
  surveyTitleBuilder;
  final Widget Function(BuildContext context, int pageCount, int currentPage)?
  stepperBuilder;
  final Widget Function(BuildContext context, s.Page page)? pageBuilder;
  final EdgeInsets? padding;

  const SurveyLayout({
    Key? key,
    this.surveyTitleBuilder,
    this.stepperBuilder,
    this.pageBuilder,
    this.padding,
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
      if (SurveyProvider.of(context).initialPage !=
          pageController?.initialPage) {
        pageController?.jumpToPage(SurveyProvider.of(context).initialPage);
      }
      if (SurveyProvider.of(context).currentPage !=
          pageController?.page?.toInt()) {
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
                    // Cancel / Reject keep existing behavior (no payload)
                    if (SurveyWidgetState.of(context).widget.onCancel != null)
                      cancelButton(),

                    if (SurveyWidgetState.of(context).widget.onReject != null)
                      rejectButton(),

                    // Workflow buttons (preset A) — each appears only if callback provided.
                    if (SurveyWidgetState.of(context).widget.onSubmit != null)
                      submitActionButton(),

                    if (SurveyWidgetState.of(context).widget.onNo != null)
                      noButton(),

                    if (SurveyWidgetState.of(context).widget.onApprove != null)
                      approveButton(),

                    if (SurveyWidgetState.of(context).widget.onErrors != null)
                    /* reuse onErrors as REJECT workflow? */
                      rejectWorkflowButton(),

                    if (SurveyWidgetState.of(context).widget.onOK != null)
                      okButton(),

                    if (SurveyWidgetState.of(context).widget.onCompleted != null)
                      completedButton(),

                    if (SurveyWidgetState.of(context).widget.onAccept != null)
                      acceptButton(),

                    if (SurveyWidgetState.of(context).widget.onDefer != null)
                      deferButton(),

                    if (SurveyWidgetState.of(context).widget.onSendToExpert !=
                        null)
                      sendToExpertButton(),

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
    return ElevatedButton(
      child: Text(finished ? S.of(context).submitSurvey : S.of(context).nextPage),
      onPressed: () {
        SurveyWidgetState.of(context).nextPageOrSubmit();
      },
    );
  }

  Widget previousButton() {
    return ElevatedButton(
      child: Text(S.of(context).previousPage),
      onPressed: () {
        toPage(currentPage - 1);
      },
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

  // Existing Cancel / Reject (no payload)
  Widget cancelButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      onPressed: () {
        SurveyWidgetState.of(context).cancel();
      },
      child: Text(S.of(context).cancel),
    );
  }

  Widget rejectButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      onPressed: () {
        SurveyWidgetState.of(context).reject();
      },
      child: Text(S.of(context).reject),
    );
  }

  // --- New workflow buttons (call state methods that pass cleaned form data) ---

  Widget submitActionButton() {
    return actionButton(
      label: "ثبت و ارسال",
      icon: Icons.send,
      color: Colors.green,
      onPressed: () => SurveyWidgetState.of(context).submit(),
    );
  }

  Widget noButton() {
    return actionButton(
      label: "انصراف از درخواست",
      icon: Icons.delete_forever,
      color: Colors.deepOrange,
      onPressed: () => SurveyWidgetState.of(context).no(),
    );
  }

  Widget approveButton() {
    return actionButton(
      label: "تایید",
      icon: Icons.check_circle,
      color: Colors.blue,
      onPressed: () => SurveyWidgetState.of(context).approve(),
    );
  }

  // I reused onErrors presence as a fallback to show a REJECT workflow button if you wired it that way.
  Widget rejectWorkflowButton() {
    return actionButton(
      label: "عدم تایید",
      icon: Icons.cancel,
      color: Colors.red.shade700,
      onPressed: () => SurveyWidgetState.of(context).reject(),
    );
  }

  Widget okButton() {
    return actionButton(
      label: "مشاهده شد",
      icon: Icons.visibility,
      color: Colors.indigo,
      onPressed: () => SurveyWidgetState.of(context).ok(),
    );
  }

  Widget completedButton() {
    return actionButton(
      label: "تکمیل فرآیند",
      icon: Icons.done_all,
      color: Colors.teal,
      onPressed: () => SurveyWidgetState.of(context).completed(),
    );
  }

  Widget acceptButton() {
    return actionButton(
      label: "قبول",
      icon: Icons.thumb_up_alt,
      color: Colors.green.shade700,
      onPressed: () => SurveyWidgetState.of(context).accept(),
    );
  }

  Widget deferButton() {
    return actionButton(
      label: "بازگشت جهت اصلاح",
      icon: Icons.undo,
      color: Colors.amber.shade800,
      onPressed: () => SurveyWidgetState.of(context).defer(),
    );
  }

  Widget sendToExpertButton() {
    return actionButton(
      label: "ارسال جهت کارشناسی",
      icon: Icons.engineering,
      color: Colors.purple,
      onPressed: () => SurveyWidgetState.of(context).sendToExpert(),
    );
  }

  @override
  void dispose() {
    pageController?.dispose();
    super.dispose();
  }
}
