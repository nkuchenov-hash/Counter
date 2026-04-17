import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime _displayNow() =>
    DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());

/// Live clock for app bars (profile timezone via [DatabaseService.timeUpdates]).
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
    _timeUpdateSub = DatabaseService.instance.timeUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timeUpdateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: DatabaseService.instance.timeUpdates,
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
