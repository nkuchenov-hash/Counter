import 'dart:ui' as ui;
import 'package:counter/core/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:intl/intl.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';

/// Shared native editor chrome derived from the approved B1 prototype.
/// Domain mutations and persistence remain in the host edit sheets.
class EditorV45Title extends StatefulWidget {
  const EditorV45Title({super.key, required this.controller, required this.onChanged,
    required this.onClose, required this.creating, required this.writing,
    this.contextLabel, this.contextTime});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool creating, writing;
  final String? contextLabel, contextTime;
  @override
  State<EditorV45Title> createState() => _EditorV45TitleState();
}
class _EditorV45TitleState extends State<EditorV45Title> {
  final FocusNode _focus = FocusNode();
  bool _editing = false;
  @override
  void dispose() { _focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.creating || _editing;
    final titleStyle = TextStyle(fontSize: widget.writing ? 22 : 28, height: 1.22,
      fontWeight: FontWeight.w700, letterSpacing: -.65, color: scheme.onSurface);
    // The title and pencil are one group, not two opposite-edge actions.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Row(children: [
          Flexible(fit: FlexFit.loose, child: editing || widget.writing
            ? AppTextField(
            surface: AppTextFieldSurface.inlineTitle,
            hintText: t(currentLocale.value, 'title_label'),
            textInputAction: TextInputAction.done,
            controller: widget.controller, focusNode: _focus,
            readOnly: !editing || widget.writing,
            minLines: 1, maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            inlineTitleStyle: titleStyle,
            onChanged: widget.onChanged,
            onSubmitted: (_) { if (!widget.creating) setState(() => _editing = false); _focus.unfocus(); },
            onTap: () { if (!widget.creating && !widget.writing && !_editing) {
              setState(() => _editing = true); _focus.requestFocus();
            }},
          ) : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { setState(() => _editing = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focus.requestFocus(); }); },
            child: Text(widget.controller.text.isEmpty ? t(currentLocale.value, 'title_label') : widget.controller.text,
              style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
          )),
          if (!widget.creating && !widget.writing)
            AppIconButton(tooltip: _editing ? t(currentLocale.value, 'save') : t(currentLocale.value, 'title_label'),
              size: AppIconButtonSize.s, onPressed: () { setState(() => _editing = !_editing);
                if (_editing) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focus.requestFocus(); }); } else { _focus.unfocus(); }
              }, icon: _editing ? Icons.check_rounded : Icons.edit_outlined),
          ])),
          if (widget.writing)
            AppButton.ghost(onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              label: currentLocale.value == 'ru' ? 'Готово' : 'Done')
          else AppIconButton(size: AppIconButtonSize.s, shape: AppIconButtonShape.circular, variant: AppIconButtonVariant.filled, onPressed: widget.onClose, tooltip: currentLocale.value == 'ru' ? 'Закрыть' : 'Close', icon: Icons.close_rounded),
        ]),
        if (widget.writing) Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 4),
          child: Row(children: [
            Expanded(child: Text(widget.contextLabel ?? '', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant))),
            Text(widget.contextTime ?? '', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

/// Use the current app locale when available; the widget remains safe before
/// the international date-symbol tables have finished initializing.
String editorV45Date(BuildContext context, DateTime date) {
  try {
    return DateFormat('d MMM, E', currentLocale.value).format(date);
  } catch (_) {
    return MaterialLocalizations.of(context).formatShortDate(date);
  }
}

String editorV45Time(DateTime? date) => date == null ? '—:—' :
  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String editorV45Range(DateTime? start, DateTime? end) =>
  start == null ? '' : end == null ? editorV45Time(start) : '${editorV45Time(start)} — ${editorV45Time(end)}';

class EditorV45TimeCard extends StatelessWidget {
  const EditorV45TimeCard({super.key, this.start, this.end, this.fallbackDate,
    required this.onStart, this.onEnd, this.running = false, this.compact = false});
  final DateTime? start, end, fallbackDate;
  final ValueChanged<Rect?> onStart;
  final ValueChanged<Rect?>? onEnd;
  final bool running, compact;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ru = currentLocale.value == 'ru';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = start != null && end != null && !running ? end!.difference(start!) : null;
    final mins = duration?.inMinutes ?? -1;
    final label = mins < 0 ? '' : [
      if (mins >= 1440) '${mins ~/ 1440} ${ru ? 'д' : 'd'}',
      if (mins ~/ 60 % 24 > 0) '${mins ~/ 60 % 24} ${ru ? 'ч' : 'h'}',
      if (mins % 60 > 0 || mins == 0) '${mins % 60} ${ru ? 'мин' : 'min'}',
    ].join(' ');
    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 9 : 14, 14, compact ? 8 : 12),
      decoration: BoxDecoration(color: dark ? AppColors.editorTimeCardDark : AppColors.editorTimeCardLight, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? AppColors.editorRuleDark : AppColors.editorRuleLight)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _EditorTimePoint(label: ru ? 'Начало' : 'Start', value: start,
            fallbackDate: fallbackDate, onTap: onStart, compact: compact)),
          const SizedBox(width: 14),
          Expanded(child: _EditorTimePoint(label: ru ? 'Окончание' : 'End', value: end,
            fallbackDate: fallbackDate, onTap: onEnd, end: true, running: running, compact: compact)),
        ]),
        if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            const _DurationLine(), Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(label, style: TextStyle(fontSize: 13, color: s.onSurfaceVariant))),
            const _DurationLine(reverse: true),
          ])),
      ]),
    );
  }
}
class _DurationLine extends StatelessWidget {
  const _DurationLine({this.reverse = false});
  final bool reverse;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    final dot = Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    final line = Expanded(child: Container(height: 1, color: color));
    return Expanded(child: Row(children: reverse ? [line, dot] : [dot, line]));
  }
}
class _EditorTimePoint extends StatelessWidget {
  const _EditorTimePoint({required this.label, this.value, this.fallbackDate, this.onTap, this.end = false, this.running = false, this.compact = false});
  final String label;
  final DateTime? value, fallbackDate;
  final ValueChanged<Rect?>? onTap;
  final bool end, running, compact;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final date = value ?? fallbackDate;
    final timeKey = GlobalKey();
    final time = Text(running ? t(currentLocale.value, 'running_label') : editorV45Time(value), key: timeKey,
      maxLines: 1, style: TextStyle(fontSize: running ? 16 : compact ? 29 : 32, height: 1.13, fontWeight: FontWeight.w700, color: s.onSurface));
    final chevron = Icon(Icons.expand_more_rounded, size: 17, color: s.onSurfaceVariant);
    return InkWell(onTap: onTap == null ? null : () {
        final render = timeKey.currentContext?.findRenderObject();
        final rect = render is RenderBox && render.hasSize ? render.localToGlobal(Offset.zero) & render.size : null;
        onTap!(rect);
      }, borderRadius: BorderRadius.circular(8),
      child: Column(crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (end && onTap != null) chevron, time, if (!end && onTap != null) chevron,
          ])),
        const SizedBox(height: 4),
        Text(date == null ? '—' : editorV45Date(context, date),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: s.onSurfaceVariant)),
      ]),
    );
  }
}

class EditorV45MetadataRow extends StatelessWidget {
  const EditorV45MetadataRow({super.key, required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Icon(icon, size: 20, color: s.onSurfaceVariant), const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: s.onSurface))),
          const SizedBox(width: 4), Icon(Icons.expand_more_rounded, size: 16, color: s.onSurfaceVariant),
        ])),
    );
  }
}

class EditorV45CategoryRow extends StatelessWidget {
  const EditorV45CategoryRow({super.key, required this.value, required this.display, required this.onChanged});
  final int? value;
  final String display;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => EditorV45MetadataRow(icon: Icons.folder_outlined,
    label: t(currentLocale.value, 'category_label'), value: display,
    onTap: () async { final id = await showCategoryTreePicker(context, initialCategoryId: value);
      if (id != null && context.mounted) onChanged(id); });
}

class EditorV45Actions extends StatelessWidget {
  const EditorV45Actions({super.key, required this.primaryLabel, required this.onPrimary, this.onCancel, this.onDelete, this.onStop});
  final String primaryLabel;
  final VoidCallback? onPrimary, onCancel, onDelete, onStop;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final nativePhone = Theme.of(context).platform == TargetPlatform.android && MediaQuery.widthOf(context) < 600;
    final pill = DecoratedBox(key: const ValueKey('v45-action-pill'), decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: dark
          ? [AppColors.editorGlassDarkTop.withValues(alpha: .65), AppColors.editorGlassDarkBottom.withValues(alpha: .53)]
          : [AppNeutralTones.white.withValues(alpha: .70), AppNeutralTones.white.withValues(alpha: .56)]),
        borderRadius: BorderRadius.circular(29), border: Border.all(color: s.outlineVariant),
        boxShadow: [BoxShadow(color: s.shadow.withValues(alpha: .06), blurRadius: 14, offset: const Offset(0, 3))]),
        child: Padding(padding: const EdgeInsets.all(5), child: Row(children: [
          if (onStop != null) AppIconButton(onPressed: onStop, tooltip: t(loc, 'stop'), icon: Icons.stop_rounded),
          if (onDelete != null) Expanded(flex: 100, child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: s.error, minimumSize: const Size(0, 44)),
            onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18), label: Text(t(loc, 'delete'))))
          else if (onCancel != null) Expanded(flex: 100, child: AppButton.ghost(onPressed: onCancel, label: t(loc, 'cancel'))),
          if (onDelete != null || onCancel != null) const SizedBox(width: 8),
          Expanded(flex: 155, child: AppButton.primary(onPressed: onPrimary, label: primaryLabel)),
        ])));
    return SafeArea(top: false, minimum: EdgeInsets.fromLTRB(24, 4, 24, _v45ActionBottomInset(context)),
      child: Align(alignment: Alignment.bottomCenter, child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: nativePhone ? pill : ClipRRect(borderRadius: BorderRadius.circular(29),
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9), child: pill)),
      )),
    );
  }
}

/// Keep the editor subtree mounted while chrome slides out of the way.
class EditorV45Collapsible extends StatelessWidget {
  const EditorV45Collapsible({super.key, required this.collapsed, required this.child});
  final bool collapsed;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.viewInsetsOf(context).bottom > 0
      ? Duration.zero : const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    clipBehavior: Clip.hardEdge,
    child: collapsed ? const SizedBox(width: double.infinity) : child,
  );
}

double _v45ActionBottomInset(BuildContext context) =>
  MediaQuery.widthOf(context) >= 768 ? 14 : 22;

/// Overlay actions on the same feathered paper surface as Notes tools.
class EditorV45ActionOverlay extends StatelessWidget {
  const EditorV45ActionOverlay({super.key, required this.content, required this.actions, required this.visible});
  final Widget content, actions;
  final bool visible;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    Positioned.fill(child: content),
    if (visible) Positioned(left: 0, right: 0, bottom: 0,
      child: NotesBottomGlassFade(height: 100,
        toolbarBottomInset: _v45ActionBottomInset(context),
        apertureMaxWidth: 440, apertureSideInset: 24, apertureHeight: 56,
        enableBackdropBlur: false,
        child: Align(alignment: Alignment.bottomCenter, child: actions))),
  ]);
}
