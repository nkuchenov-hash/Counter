import 'package:flutter/material.dart';class PlanningDayCardListKeepAlive extends StatefulWidget {
  const PlanningDayCardListKeepAlive({required this.child});

  final Widget child;

  @override
  State<PlanningDayCardListKeepAlive> createState() =>
      PlanningDayCardListKeepAliveState();
}

class PlanningDayCardListKeepAliveState extends State<PlanningDayCardListKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
