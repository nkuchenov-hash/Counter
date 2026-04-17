// ---------------------------------------------------------------------------
// Omni-Picker (keyboard / desktop): single dialog with date + time text inputs.
// See ARCHITECTURE.md §8.1 Omni-Picker Law — never chain showDatePicker + showTimePicker.
// ---------------------------------------------------------------------------

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified date+time picker for surfaces that use text-first Material modes
/// (Web + desktop native). One dialog, one confirm — tab-friendly flow.
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
  final _dateFocus = FocusNode();
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();

  late TextEditingController _hourController;
  late TextEditingController _minuteController;

  late DateTime _savedDay;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _savedDay = DateTime(i.year, i.month, i.day);
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
    _dateFocus.dispose();
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
    form.save();
    final day = _savedDay;
    if (!mounted) return;
    final h = int.parse(_hourController.text.trim());
    final m = int.parse(_minuteController.text.trim());
    Navigator.of(context).pop(DateTime(day.year, day.month, day.day, h, m));
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final mat = MaterialLocalizations.of(context);
    final maxW = MediaQuery.sizeOf(context).width - 48;

    return AlertDialog(
      title: Text(t(loc, 'omni_picker_dialog_title')),
      content: SizedBox(
        width: maxW < 360 ? maxW : 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDatePickerFormField(
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                initialDate: _savedDay,
                autofocus: true,
                focusNode: _dateFocus,
                errorFormatText: mat.invalidDateFormatLabel,
                errorInvalidText: mat.dateOutOfRangeLabel,
                onDateSubmitted: (_) {
                  _hourFocus.requestFocus();
                },
                onDateSaved: (d) => _savedDay = d,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hourController,
                      focusNode: _hourFocus,
                      decoration: InputDecoration(
                        labelText: mat.timePickerHourLabel,
                        border: theme.useMaterial3
                            ? const OutlineInputBorder()
                            : const UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: _validateHour,
                      onFieldSubmitted: (_) => _minuteFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minuteController,
                      focusNode: _minuteFocus,
                      decoration: InputDecoration(
                        labelText: mat.timePickerMinuteLabel,
                        border: theme.useMaterial3
                            ? const OutlineInputBorder()
                            : const UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: _validateMinute,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
