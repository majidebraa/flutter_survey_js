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
      title: Text(survey.title!.getLocalizedText(context)!),
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
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    cancelButton(),
                    rejectButton(),
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
      child:
      Text(finished ? S.of(context).submitSurvey : S.of(context).nextPage),
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

  Widget cancelButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      onPressed: () {
        SurveyWidgetState.of(context).cancel();
      },
      child: const Text("Cancel"),
    );
  }

  Widget rejectButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      onPressed: () {
        SurveyWidgetState.of(context).reject();
      },
      child: const Text("Reject"),
    );
  }

  @override
  void dispose() {
    pageController?.dispose();
    super.dispose();
  }
}
