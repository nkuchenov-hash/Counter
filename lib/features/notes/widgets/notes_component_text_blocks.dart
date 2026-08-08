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
    final textStyle = _notesTextStyle(context, style);
    if (controller is NotesTextEditingController) {
      (controller as NotesTextEditingController).linkColor = scheme.primary;
    }
    final textField = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: TextField(
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
        style: textStyle,
        strutStyle: StrutStyle.fromTextStyle(
          textStyle,
          forceStrutHeight: true,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: textStyle.copyWith(
            color: NotesFigmaTokens.textSecondary(
              context,
            ).withValues(alpha: 0.55),
          ),
          filled: false,
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
    return _NotesActiveIndicatorFrame(
      state: state,
      topInset: style == NotesTextBlockStyle.h1 ? 18 : 12,
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
    final marker = listStyle == NotesListStyle.bulleted
        ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: NotesFigmaTokens.textPrimary(context),
              shape: BoxShape.circle,
            ),
          )
        : Text(
            '$ordinal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: NotesFigmaTokens.textPrimary(context),
            ),
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
        leading: _NotesCheckbox(
          checked: checked,
          onChanged: onCheckedChanged,
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

class _NotesCheckbox extends StatelessWidget {
  const _NotesCheckbox({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fill = NotesFigmaTokens.selectedSurface(context);
    final border = NotesFigmaTokens.textPrimary(
      context,
    ).withValues(alpha: 0.15);
    return Semantics(
      button: true,
      checked: checked,
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: checked ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: checked ? null : Border.all(color: border),
          ),
          child: checked
              ? Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: NotesFigmaTokens.selectedIcon(context),
                )
              : null,
        ),
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
        10,
        kNotesContentInset,
        10,
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
                      color: NotesFigmaTokens.textSecondary(context),
                      decoration: TextDecoration.lineThrough,
                    )
                  : baseStyle,
              strutStyle: StrutStyle.fromTextStyle(
                baseStyle,
                forceStrutHeight: true,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: baseStyle.copyWith(
                  color: NotesFigmaTokens.textSecondary(
                    context,
                  ).withValues(alpha: 0.55),
                ),
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
