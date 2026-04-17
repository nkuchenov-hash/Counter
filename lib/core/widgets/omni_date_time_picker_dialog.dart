// ---------------------------------------------------------------------------
// Omni-Picker (Web / desktop): hybrid CalendarDatePicker + typed HH:mm in one dialog.
// See ARCHITECTURE.md §8.1 Omni-Picker Law — never chain showDatePicker + showTimePicker.
// ---------------------------------------------------------------------------

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified date+time picker for keyboard-friendly surfaces. Single dialog only.
Future<DateTime?> showOmniDateTimePickerDialog(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _OmniDateTimePickerDialog(
      initial: initial,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime(lastDate.year, lastDate.month, lastDate.day),
    ),
  );
}

class _OmniDateTimePickerDialog extends StatefulWidget {
  const _OmniDateTimePickerDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_OmniDateTimePickerDialog> createState() =>
      _OmniDateTimePickerDialogState();
}

class _OmniDateTimePickerDialogState extends State<_OmniDateTimePickerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();

  late TextEditingController _hourController;
  late TextEditingController _minuteController;

  late DateTime _selectedDay;

  DateTime _clampDay(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(widget.firstDate)) return widget.firstDate;
    if (day.isAfter(widget.lastDate)) return widget.lastDate;
    return day;
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _selectedDay = _clampDay(DateTime(i.year, i.month, i.day));
    _hourController = TextEditingController(
      text: i.hour.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: i.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  String? _validateHour(String? s) {
    final mat = MaterialLocalizations.of(context);
    if (s == null || s.trim().isEmpty) return mat.invalidTimeLabel;
    final h = int.tryParse(s.trim());
    if (h == null || h < 0 || h > 23) return mat.invalidTimeLabel;
    return null;
  }

  String? _validateMinute(String? s) {
    final mat = MaterialLocalizations.of(context);
    if (s == null || s.trim().isEmpty) return mat.invalidTimeLabel;
    final m = int.tryParse(s.trim());
    if (m == null || m < 0 || m > 59) return mat.invalidTimeLabel;
    return null;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    if (!mounted) return;
    final h = int.parse(_hourController.text.trim());
    final m = int.parse(_minuteController.text.trim());
    final d = _selectedDay;
    Navigator.of(context).pop(DateTime(d.year, d.month, d.day, h, m));
  }

  static const double _kDialogContentMaxWidth = 350;
  static const double _kDigitalFontSize = 24;
  static const double _kTimeBoxWidth = 76;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final mat = MaterialLocalizations.of(context);
    final scheme = theme.colorScheme;
    final screenW = MediaQuery.sizeOf(context).width;
    final dialogW = screenW - 48 < _kDialogContentMaxWidth
        ? screenW - 48
        : _kDialogContentMaxWidth;

    final timeFill = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final timeBorder = scheme.outlineVariant.withValues(alpha: 0.5);

    InputDecoration digitalDecoration() {
      return const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        counterText: '',
        filled: false,
      );
    }

    Widget digitalField({
      required TextEditingController controller,
      required FocusNode focusNode,
      required String? Function(String?) validator,
      required TextInputAction textInputAction,
      required void Function(String?) onFieldSubmitted,
    }) {
      return Container(
        width: _kTimeBoxWidth,
        decoration: BoxDecoration(
          color: timeFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: timeBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: _kDigitalFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: 1.1,
          ),
          decoration: digitalDecoration(),
          keyboardType: TextInputType.number,
          textInputAction: textInputAction,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
        ),
      );
    }

    return AlertDialog(
      title: Text(t(loc, 'omni_picker_dialog_title')),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogW),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalendarDatePicker(
                key: ValueKey<int>(
                  _selectedDay.year * 10000 +
                      _selectedDay.month * 100 +
                      _selectedDay.day,
                ),
                initialDate: _selectedDay,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: (d) {
                  setState(() {
                    _selectedDay = DateTime(d.year, d.month, d.day);
                  });
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.45)),
              const SizedBox(height: 14),
              Text(
                mat.timePickerInputHelpText,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    digitalField(
                      controller: _hourController,
                      focusNode: _hourFocus,
                      validator: _validateHour,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _minuteFocus.requestFocus(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        ':',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: _kDigitalFontSize + 2,
                          fontWeight: FontWeight.w300,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    digitalField(
                      controller: _minuteController,
                      focusNode: _minuteFocus,
                      validator: _validateMinute,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(loc, 'cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(t(loc, 'save')),
        ),
      ],
    );
  }
}
