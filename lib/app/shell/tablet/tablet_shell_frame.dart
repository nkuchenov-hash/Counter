import 'package:counter/app/shell/phone/phone_shell_frame.dart';
import 'package:flutter/material.dart';

/// Tablet shell frame.
///
/// Existing production behavior: tablet-width viewports below the desktop
/// nav breakpoint use the same compact bottom-nav chrome as phone. This
/// widget makes that ownership explicit without redesigning tablet UX.
class TabletShellFrame extends StatelessWidget {
  const TabletShellFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PhoneShellFrame(child: child);
}
