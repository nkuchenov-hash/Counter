import 'package:counter/core/app_icons.dart';
import 'package:flutter/material.dart';

export 'package:counter/core/app_icons.dart' show AppTimezoneIconKey;

class AppTimezoneIcon extends StatelessWidget {
  const AppTimezoneIcon({
    required this.timezoneKey,
    this.size = 32,
    this.color,
    super.key,
  });

  final AppTimezoneIconKey timezoneKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AppTimezoneIconPainter(
          timezoneKey: timezoneKey,
          color: iconColor,
        ),
      ),
    );
  }
}

class _AppTimezoneIconPainter extends CustomPainter {
  const _AppTimezoneIconPainter({
    required this.timezoneKey,
    required this.color,
  });

  final AppTimezoneIconKey timezoneKey;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas
      ..save()
      ..translate(
        (size.width - size.shortestSide) / 2,
        (size.height - size.shortestSide) / 2,
      )
      ..scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = switch (timezoneKey) {
      AppTimezoneIconKey.utc => _utcPath(),
      AppTimezoneIconKey.london => _londonPath(),
      AppTimezoneIconKey.moscow => _moscowPath(),
      AppTimezoneIconKey.dubai => _dubaiPath(),
      AppTimezoneIconKey.newYork => _newYorkPath(),
    };

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppTimezoneIconPainter oldDelegate) {
    return oldDelegate.timezoneKey != timezoneKey || oldDelegate.color != color;
  }
}

Path _subtract(Path base, Path cuts) {
  return Path.combine(PathOperation.difference, base, cuts);
}

RRect _rr(double left, double top, double right, double bottom, double radius) {
  return RRect.fromRectAndRadius(
    Rect.fromLTRB(left, top, right, bottom),
    Radius.circular(radius),
  );
}

Path _utcPath() {
  final base = Path()
    ..addOval(const Rect.fromLTWH(18, 12, 64, 64))
    ..addRRect(_rr(34, 75, 66, 85, 3))
    ..addRRect(_rr(25, 84, 75, 91, 3));

  final cuts = Path()
    ..addRRect(_rr(47, 18, 53, 70, 3))
    ..addRRect(_rr(23, 38, 77, 43, 3))
    ..addRRect(_rr(23, 51, 77, 56, 3))
    ..addRRect(_rr(33, 25, 67, 29, 2))
    ..addRRect(_rr(33, 65, 67, 69, 2));

  return _subtract(base, cuts);
}

Path _londonPath() {
  final base = Path()
    ..addRRect(_rr(30, 80, 70, 90, 3))
    ..addRRect(_rr(35, 28, 65, 82, 4))
    ..moveTo(33, 29)
    ..lineTo(50, 13)
    ..lineTo(67, 29)
    ..close()
    ..addRRect(_rr(46, 7, 54, 17, 2))
    ..moveTo(50, 2)
    ..lineTo(54, 9)
    ..lineTo(46, 9)
    ..close()
    ..addRRect(_rr(25, 86, 75, 94, 3));

  final cuts = Path()
    ..addOval(const Rect.fromLTWH(41, 37, 18, 18))
    ..addRRect(_rr(41, 60, 46, 74, 2))
    ..addRRect(_rr(54, 60, 59, 74, 2))
    ..addRRect(_rr(36, 78, 64, 82, 2));

  return _subtract(base, cuts);
}

Path _moscowPath() {
  final base = Path()
    ..addRRect(_rr(20, 74, 80, 88, 3))
    ..addRRect(_rr(22, 67, 31, 76, 1))
    ..addRRect(_rr(38, 67, 47, 76, 1))
    ..addRRect(_rr(53, 67, 62, 76, 1))
    ..addRRect(_rr(69, 67, 78, 76, 1))
    ..addRRect(_rr(38, 34, 62, 75, 4))
    ..moveTo(34, 36)
    ..lineTo(50, 18)
    ..lineTo(66, 36)
    ..close()
    ..moveTo(50, 5)
    ..lineTo(53, 13)
    ..lineTo(62, 13)
    ..lineTo(55, 18)
    ..lineTo(58, 27)
    ..lineTo(50, 22)
    ..lineTo(42, 27)
    ..lineTo(45, 18)
    ..lineTo(38, 13)
    ..lineTo(47, 13)
    ..close();

  final cuts = Path()
    ..addOval(const Rect.fromLTWH(43, 45, 14, 14))
    ..addRRect(_rr(46, 62, 54, 72, 2));

  return _subtract(base, cuts);
}

Path _dubaiPath() {
  final base = Path()
    ..moveTo(25, 85)
    ..quadraticBezierTo(42, 55, 65, 12)
    ..quadraticBezierTo(78, 36, 76, 82)
    ..quadraticBezierTo(60, 76, 43, 83)
    ..close()
    ..addRRect(_rr(23, 84, 79, 92, 3));

  final cuts = Path()
    ..moveTo(47, 76)
    ..quadraticBezierTo(58, 53, 66, 25)
    ..quadraticBezierTo(69, 50, 67, 75)
    ..quadraticBezierTo(58, 71, 47, 76)
    ..close()
    ..addRRect(_rr(40, 53, 65, 57, 2))
    ..addRRect(_rr(36, 66, 66, 70, 2));

  return _subtract(base, cuts);
}

Path _newYorkPath() {
  final base = Path()
    ..addRRect(_rr(37, 80, 63, 91, 2))
    ..moveTo(39, 80)
    ..lineTo(44, 45)
    ..lineTo(57, 45)
    ..lineTo(62, 80)
    ..close()
    ..addOval(const Rect.fromLTWH(43, 28, 14, 14))
    ..moveTo(36, 34)
    ..lineTo(43, 31)
    ..lineTo(45, 21)
    ..lineTo(50, 29)
    ..lineTo(55, 21)
    ..lineTo(57, 31)
    ..lineTo(64, 34)
    ..lineTo(56, 36)
    ..lineTo(44, 36)
    ..close()
    ..moveTo(57, 45)
    ..lineTo(69, 31)
    ..lineTo(75, 35)
    ..lineTo(61, 56)
    ..close()
    ..addRRect(_rr(70, 17, 78, 36, 2))
    ..moveTo(74, 8)
    ..quadraticBezierTo(83, 18, 76, 24)
    ..quadraticBezierTo(69, 18, 74, 8)
    ..close()
    ..moveTo(43, 47)
    ..lineTo(30, 60)
    ..lineTo(35, 66)
    ..lineTo(45, 55)
    ..close();

  final cuts = Path()
    ..addRRect(_rr(48, 50, 53, 77, 2))
    ..addRRect(_rr(43, 73, 58, 77, 2));

  return _subtract(base, cuts);
}
