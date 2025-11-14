// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_survey_js/ui/survey_widget.dart';
import 'package:flutter_survey_js/utils.dart';
import 'package:flutter_survey_js_model/flutter_survey_js_model.dart' as s;

class QuestionTitle extends StatelessWidget {
  final s.Question q;
  final Widget? child;

  const QuestionTitle({Key? key, required this.q, this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    description() {
      if (q.description?.getLocalizedText(context) != null &&
          q.description!.getLocalizedText(context)!.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.only(left: 0.0, right: 0.0, bottom: 10.0),
          child: Text(q.description!.getLocalizedText(context)!,
              style: Theme.of(context).textTheme.bodyMedium),
        );
      } else {
        return Container();
      }
    }

    titleTextStyle() => Theme.of(context).textTheme.titleLarge;

    title() {
      final survey = SurveyProvider.of(context);
      final status = survey.rootNode.findByElement(element: q);

      // Determine question number
      String questionNumber = '';
      if (status != null) {
        if (survey.survey.showQuestionNumbers?.isOn ?? true) {
          if (status.isInsideDynamic == true && status.panelIndex != null) {
            questionNumber = '${status.panelIndex! + 1}. ';
          } else if (status.indexAll != null) {
            questionNumber = '${status.indexAll! + 1}. ';
          }
        } else if (survey.survey.showQuestionNumbers?.isOnPage ?? false) {
          if (status.isInsideDynamic == true && status.panelIndex != null) {
            questionNumber = '${status.panelIndex! + 1}. ';
          } else if (status.indexInPage != null) {
            questionNumber = '${status.indexInPage! + 1}. ';
          }
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (questionNumber.isNotEmpty)
                Text(
                  questionNumber,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              const SizedBox(width: 4),
              // Main title wraps inside Expanded
              Expanded(
                child: Text(
                  q.title?.getLocalizedText(context) ?? q.name ?? "",
                  style: Theme.of(context).textTheme.titleLarge,
                  softWrap: true,
                ),
              ),
              // Required mark
              if (q.isRequired == true)
                const Padding(
                  padding: EdgeInsets.only(left: 2.0),
                  child: Text(
                    '*',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontFamily: 'SF-UI-Text',
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          // Question description
          if (q.description?.getLocalizedText(context)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 10.0),
              child: Text(
                q.description!.getLocalizedText(context)!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(),
        if (child != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: child!,
          )
      ],
    );
  }

  TextStyle get requiredTextStyle => const TextStyle(
      fontSize: 16.0,
      fontFamily: 'SF-UI-Text',
      fontWeight: FontWeight.w900,
      color: Colors.red);
}
