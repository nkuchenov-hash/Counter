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

  late DateTime _selectedDay;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _selectedDay = _clampDay(DateTime(i.year, i.month, i.day));
    _hour = i.hour;
    _minute = i.minute;
  }

  DateTime _clampDay(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(widget.firstDate)) return widget.firstDate;
    if (day.isAfter(widget.lastDate)) return widget.lastDate;
    return day;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    if (!mounted) return;
    Navigator.of(context).pop(
      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, _hour, _minute),
    );
  }

  static const double _kDialogContentMaxWidth = 600;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final dialogW = screenW - 48 < _kDialogContentMaxWidth
        ? screenW - 48
        : _kDialogContentMaxWidth;
    final wide = screenW >= 560;

    final dateSection = _DateSection(
      initial: _selectedDay,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onDateChanged: (date) {
        _selectedDay = date;
      },
    );

    final timeSection = _TimeSection(
      initial: widget.initial,
      onTimeChanged: (h, m) {
        _hour = h;
        _minute = m;
      },
      onSubmit: _submit,
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

// ---------------------------------------------------------------------------
// Date section — owns selected day and text field; CalendarDatePicker manages
// its own displayed month, no external key or focusedDay tracking.
// ---------------------------------------------------------------------------

class _DateSection extends StatefulWidget {
  const _DateSection({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_DateSection> createState() => _DateSectionState();
}

class _DateSectionState extends State<_DateSection> {
  late DateTime _selectedDay;
  late TextEditingController _dateTextController;

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
    _selectedDay = _clampDay(
      DateTime(widget.initial.year, widget.initial.month, widget.initial.day),
    );
    _dateTextController = TextEditingController(text: _formatDateField(_selectedDay));
  }

  @override
  void dispose() {
    _dateTextController.dispose();
    super.dispose();
  }

  // Only fires for user input — programmatic controller changes do not trigger
  // onChanged in Flutter's TextFormField.
  void _onDateTextChanged(String value) {
    final parsed = _tryParseDateField(value);
    if (parsed == null) return;
    final next = _clampDay(parsed);
    if (next == _selectedDay) return;
    setState(() {
      _selectedDay = next;
    });
    widget.onDateChanged(_selectedDay);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mat = MaterialLocalizations.of(context);
    final scheme = theme.colorScheme;
    final sectionBorder = scheme.outlineVariant.withValues(alpha: 0.45);

    return Container(
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
          CalendarDatePicker(
            initialCalendarMode: DatePickerMode.day,
            initialDate: _selectedDay,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            onDateChanged: (date) {
              setState(() {
                _selectedDay = _clampDay(date);
                _dateTextController.text = _formatDateField(_selectedDay);
              });
              widget.onDateChanged(_selectedDay);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time section — owns hour/minute controllers and Cupertino drum. setState calls
// here never touch _DateSection, eliminating the calendar rebuild on wheel scroll.
// ---------------------------------------------------------------------------

class _TimeSection extends StatefulWidget {
  const _TimeSection({
    required this.initial,
    required this.onTimeChanged,
    required this.onSubmit,
  });

  final DateTime initial;
  final void Function(int hour, int minute) onTimeChanged;
  final VoidCallback onSubmit;

  @override
  State<_TimeSection> createState() => _TimeSectionState();
}

class _TimeSectionState extends State<_TimeSection> {
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();

  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late DateTime _wheelTime;
  bool _ignoreWheelCallback = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _hourController = TextEditingController(text: i.hour.toString().padLeft(2, '0'));
    _minuteController = TextEditingController(text: i.minute.toString().padLeft(2, '0'));
    _wheelTime = DateTime(2000, 1, 1, i.hour, i.minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
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
    widget.onTimeChanged(h, m);
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
    widget.onTimeChanged(ch, cm);
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

  static const double _kDigitalFontSize = 24;
  static const double _kTimeBoxWidth = 76;
  static const double _kDrumHeight = 216;

  InputDecoration _digitalDecoration() {
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

  Widget _digitalField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    required void Function(String?) onFieldSubmitted,
    required void Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeFill = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
    final timeBorder = scheme.outlineVariant.withValues(alpha: 0.5);

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
        decoration: _digitalDecoration(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mat = MaterialLocalizations.of(context);
    final scheme = theme.colorScheme;
    final sectionBorder = scheme.outlineVariant.withValues(alpha: 0.45);

    return Container(
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
              _digitalField(
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
              _digitalField(
                controller: _minuteController,
                focusNode: _minuteFocus,
                validator: _validateMinute,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => widget.onSubmit(),
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
  }
}
