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

  // ✅ new fields
  final List<String>? outcomeTypes;
  final void Function(String action, Map<String, Object?> data)? onAction;

  const SurveyLayout({
    Key? key,
    this.surveyTitleBuilder,
    this.stepperBuilder,
    this.pageBuilder,
    this.padding,
    this.outcomeTypes,
    this.onAction,
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
      final provider = SurveyProvider.of(context);
      if (provider.initialPage != pageController?.initialPage) {
        pageController?.jumpToPage(provider.initialPage);
      }
      if (provider.currentPage != pageController?.page?.toInt()) {
        pageController?.jumpToPage(provider.currentPage);
      }
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final surveyWidgetState = SurveyWidgetState.of(context);
    final currentPage = surveyWidgetState.currentPage;
    final pages = reCalculatePages(survey);
    final formData = surveyWidgetState.formGroup.value;

    final latestUnfinished = SurveyProvider.of(context)
        .rootNode
        .findByCondition((node) => node.isLatestUnfinishedQuestion == true);

    return Column(
      children: [
        (widget.surveyTitleBuilder ?? defaultSurveyTitleBuilder)(
            context, survey),
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

                // ✅ Replace bottom buttons with dynamic outcome buttons
                if (widget.outcomeTypes?.isNotEmpty ?? false)
                  _buildOutcomeButtons(formData)
                else
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
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

  Widget _buildOutcomeButtons(Map<String, Object?> data) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (final action in widget.outcomeTypes!) _buildActionButton(action, data),
      ],
    );
  }

  Widget _buildActionButton(String action, Map<String, Object?> data) {
    Color color;
    IconData icon;
    switch (action.toUpperCase()) {
      case 'SUBMIT':
      case 'OK':
      case 'COMPLETED':
        color = Colors.green;
        icon = Icons.check;
        break;
      case 'REJECT':
      case 'NO':
        color = Colors.red;
        icon = Icons.close;
        break;
      case 'APPROVE':
        color = Colors.blue;
        icon = Icons.thumb_up;
        break;
      case 'DEFER':
        color = Colors.orange;
        icon = Icons.pause_circle;
        break;
      case 'SENDTOEXPORT':
        color = Colors.purple;
        icon = Icons.upload;
        break;
      default:
        color = Colors.grey;
        icon = Icons.circle;
    }

    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(action),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        widget.onAction?.call(action, data);
      },
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

  @override
  void dispose() {
    pageController?.dispose();
    super.dispose();
  }
}
