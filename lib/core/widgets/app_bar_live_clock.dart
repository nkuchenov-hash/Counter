import 'dart:async';

import 'package:counter/shared/time/app_clock.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime _displayNow() => AppClock.wallNow?.call() ?? DateTime.now();

/// Live clock for app bars (profile timezone via [AppClock.timeTicks]).
class AppBarLiveClock extends StatefulWidget {
  const AppBarLiveClock({super.key, this.textStyle});

  final TextStyle? textStyle;

  @override
  State<AppBarLiveClock> createState() => _AppBarLiveClockState();
}

class _AppBarLiveClockState extends State<AppBarLiveClock> {
  StreamSubscription<void>? _timeUpdateSub;

  @override
  void initState() {
    super.initState();
    final ticks = AppClock.timeTicks;
    if (ticks != null) {
      _timeUpdateSub = ticks.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timeUpdateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: AppClock.timeTicks,
      builder: (context, _) {
        return Text(
          DateFormat.Hm(currentLocale.value).format(_displayNow()),
          style: widget.textStyle ??
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        );
      },
    );
  }
}
