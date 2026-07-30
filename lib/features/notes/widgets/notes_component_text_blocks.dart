part of 'notes_canonical_components.dart';

class NotesTextBlock extends StatelessWidget {
  const NotesTextBlock({
    super.key,
    required this.controller,
    this.style = NotesTextBlockStyle.body,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.semanticLabel,
    this.autofocus = false,
    this.readOnly = false,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final NotesTextBlockStyle style;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final String? semanticLabel;
  final bool autofocus;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (controller is NotesTextEditingController) {
      (controller as NotesTextEditingController).linkColor = scheme.primary;
    }
    final textField = TextField(
      key: textFieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      onTap: onTap,
      style: _notesTextStyle(context, style),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: _notesTextStyle(context, style).copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kNotesContentInset,
          vertical: kNotesBlockVerticalPadding,
        ),
      ),
    );
    return _NotesActiveIndicatorFrame(
      state: state,
      topInset: style == NotesTextBlockStyle.h1 ? 20 : 12,
      child: semanticLabel == null
          ? textField
          : Semantics(label: semanticLabel, textField: true, child: textField),
    );
  }
}

class NotesListBlock extends StatelessWidget {
  const NotesListBlock({
    super.key,
    required this.controller,
    required this.listStyle,
    this.ordinal = 1,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final NotesListStyle listStyle;
  final int ordinal;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = listStyle == NotesListStyle.bulleted
        ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.onSurface,
              shape: BoxShape.circle,
            ),
          )
        : Text(
            '$ordinal.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.45),
          );
    return _NotesActiveIndicatorFrame(
      state: state,
      child: _NotesLeadingTextRow(
        leading: marker,
        controller: controller,
        focusNode: focusNode,
        hintText: hintText,
        onChanged: onChanged,
        onTap: onTap,
        textFieldKey: textFieldKey,
      ),
    );
  }
}

class NotesChecklistBlock extends StatelessWidget {
  const NotesChecklistBlock({
    super.key,
    required this.controller,
    required this.checked,
    required this.onCheckedChanged,
    this.state = NotesBlockState.defaultState,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
  });

  final TextEditingController controller;
  final bool checked;
  final ValueChanged<bool> onCheckedChanged;
  final NotesBlockState state;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;

  @override
  Widget build(BuildContext context) {
    return _NotesActiveIndicatorFrame(
      state: state,
      child: _NotesLeadingTextRow(
        leading: Checkbox(
          value: checked,
          onChanged: (value) => onCheckedChanged(value ?? false),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        controller: controller,
        focusNode: focusNode,
        hintText: hintText,
        onChanged: onChanged,
        onTap: onTap,
        textFieldKey: textFieldKey,
        checked: checked,
      ),
    );
  }
}

class _NotesLeadingTextRow extends StatelessWidget {
  const _NotesLeadingTextRow({
    required this.leading,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onTap,
    this.textFieldKey,
    this.checked = false,
  });

  final Widget leading;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Key? textFieldKey;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final baseStyle = _notesTextStyle(context, NotesTextBlockStyle.body);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kNotesContentInset,
        kNotesBlockVerticalPadding,
        kNotesContentInset,
        kNotesBlockVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kNotesLeadingSize,
            height: 24,
            child: Center(child: leading),
          ),
          const SizedBox(width: kNotesLeadingGap),
          Expanded(
            child: TextField(
              key: textFieldKey,
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: onChanged,
              onTap: onTap,
              style: checked
                  ? baseStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    )
                  : baseStyle,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
