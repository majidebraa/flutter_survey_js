Widget commentBuilder(
    BuildContext context,
    s.Elementbase element, {
      ElementConfiguration? configuration,
    }) {
  final comment = element as s.Comment;
  final bool isReadOnly = comment.readOnly ?? false;

  return Opacity(
    opacity: isReadOnly ? 0.6 : 1.0, // 👈 visual feedback
    child: ReactiveTextField(
      keyboardType: TextInputType.multiline,
      maxLines: null,
      formControlName: element.name!,
      readOnly: isReadOnly,
      decoration: InputDecoration(
        filled: true,
        fillColor: isReadOnly
            ? Colors.grey.shade200 // 👈 readonly background
            : Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.only(
          bottom: 10.0,
          left: 10.0,
          right: 10.0,
        ),
        hintText: comment.placeholder?.getLocalizedText(context),
      ),
    ),
  ).wrapQuestionTitle(
    context,
    element,
    configuration: configuration,
  );
}
