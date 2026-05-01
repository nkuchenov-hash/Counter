// ---------------------------------------------------------------------------
// Omni-Picker (Web / desktop): single dialog — typed date + calendar, typed time + drum.
// See ARCHITECTURE.md §8.1 Omni-Picker Law — never chain showDatePicker + showTimePicker.
// ---------------------------------------------------------------------------

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  late TextEditingController _dateTextController;

  late DateTime _selectedDay;
  /// Fixed calendar date for the Cupertino time wheel (time-of-day only).
  late DateTime _wheelTime;

  bool _dateTextFromCalendar = false;
  bool _ignoreWheelCallback = false;

  DateTime _clampDay(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(widget.firstDate)) return widget.firstDate;
    if (day.isAfter(widget.lastDate)) return widget.lastDate;
    return day;
  }

  String _formatDateField(DateTime d) {
    final loc = currentLocale.value;
    return DateFormat.yMd(loc).format(DateTime(d.year, d.month, d.day));
  }

  DateTime? _tryParseDateField(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final loc = currentLocale.value;
    try {
      return DateFormat.yMd(loc).parseStrict(s);
    } catch (_) {
      try {
        return DateFormat.yMd(loc).parseLoose(s);
      } catch (_) {
        return DateTime.tryParse(s);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _selectedDay = _clampDay(DateTime(i.year, i.month, i.day));
    _dateTextController = TextEditingController(text: _formatDateField(_selectedDay));
    _hourController = TextEditingController(
      text: i.hour.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: i.minute.toString().padLeft(2, '0'),
    );
    _wheelTime = DateTime(2000, 1, 1, i.hour, i.minute);
  }

  @override
  void dispose() {
    _dateTextController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _onDateTextChanged(String value) {
    if (_dateTextFromCalendar) return;
    final parsed = _tryParseDateField(value);
    if (parsed == null) return;
    final next = _clampDay(parsed);
    if (next == _selectedDay &&
        _formatDateField(next) == value.trim()) {
      return;
    }
    setState(() {
      _selectedDay = next;
      _dateTextFromCalendar = true;
      _dateTextController.value = TextEditingValue(
        text: _formatDateField(next),
        selection: TextSelection.collapsed(offset: _formatDateField(next).length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dateTextFromCalendar = false;
    });
  }

  void _onCalendarDateChanged(DateTime d) {
    final next = _clampDay(DateTime(d.year, d.month, d.day));
    _dateTextFromCalendar = true;
    setState(() {
      _selectedDay = next;
      _dateTextController.text = _formatDateField(next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dateTextFromCalendar = false;
    });
  }

  void _applyTimeFromWheel(DateTime dt) {
    if (_ignoreWheelCallback) return;
    final h = dt.hour.clamp(0, 23);
    final m = dt.minute.clamp(0, 59);
    _hourController.text = h.toString().padLeft(2, '0');
    _minuteController.text = m.toString().padLeft(2, '0');
    setState(() {
      _wheelTime = DateTime(2000, 1, 1, h, m);
    });
  }

  void _syncWheelFromTypedTime() {
    final h = int.tryParse(_hourController.text.trim());
    final m = int.tryParse(_minuteController.text.trim());
    if (h == null || m == null) return;
    final ch = h.clamp(0, 23);
    final cm = m.clamp(0, 59);
    if (ch == _wheelTime.hour && cm == _wheelTime.minute) return;
    _ignoreWheelCallback = true;
    setState(() {
      _wheelTime = DateTime(2000, 1, 1, ch, cm);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ignoreWheelCallback = false;
    });
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

  String? _validateDateText(String? s) {
    if (s == null || s.trim().isEmpty) {
      return MaterialLocalizations.of(context).invalidDateFormatLabel;
    }
    final p = _tryParseDateField(s);
    if (p == null) {
      return MaterialLocalizations.of(context).invalidDateFormatLabel;
    }
    final day = DateTime(p.year, p.month, p.day);
    if (day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate)) {
      return MaterialLocalizations.of(context).dateOutOfRangeLabel;
    }
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

  static const double _kDialogContentMaxWidth = 600;
  static const double _kDigitalFontSize = 24;
  static const double _kTimeBoxWidth = 76;
  static const double _kDrumHeight = 216;

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
    final wide = screenW >= 560;

    final timeFill = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final timeBorder = scheme.outlineVariant.withValues(alpha: 0.5);
    final sectionBorder = scheme.outlineVariant.withValues(alpha: 0.45);

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
      required void Function(String) onChanged,
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
          onChanged: onChanged,
        ),
      );
    }

    final dateSection = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: sectionBorder),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mat.datePickerHelpText,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _dateTextController,
            decoration: InputDecoration(
              labelText: mat.dateInputLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            onChanged: _onDateTextChanged,
            validator: _validateDateText,
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: CalendarDatePicker(
              key: ValueKey<String>('${_selectedDay.year}-${_selectedDay.month}'),
              initialCalendarMode: DatePickerMode.day,
              initialDate: _selectedDay,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDateChanged: _onCalendarDateChanged,
            ),
          ),
        ],
      ),
    );

    final timeSection = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: sectionBorder),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mat.timePickerInputHelpText,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              digitalField(
                controller: _hourController,
                focusNode: _hourFocus,
                validator: _validateHour,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _minuteFocus.requestFocus(),
                onChanged: (_) => _syncWheelFromTypedTime(),
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
                onChanged: (_) => _syncWheelFromTypedTime(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _kDrumHeight,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                primaryColor: scheme.primary,
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 1,
                initialDateTime: _wheelTime,
                onDateTimeChanged: (DateTime dt) {
                  if (_ignoreWheelCallback) return;
                  _applyTimeFromWheel(dt);
                },
              ),
            ),
          ),
        ],
      ),
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dateSection),
              const SizedBox(width: 12),
              Expanded(child: timeSection),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              dateSection,
              const SizedBox(height: 12),
              timeSection,
            ],
          );

    return AlertDialog(
      title: Text(t(loc, 'omni_picker_dialog_title')),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogW),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: body,
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
