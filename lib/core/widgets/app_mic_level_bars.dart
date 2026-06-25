import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes normalized RMS level (0..1) from PCM16 LE mono bytes.
double pcm16RmsLevel(List<int> bytes) {
  if (bytes.length < 2) return 0;
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final sample = bytes[i] | (bytes[i + 1] << 8);
    final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
    sum += signed * signed;
    count++;
  }
  if (count == 0) return 0;
  final rms = math.sqrt(sum / count) / 32768.0;
  return rms.clamp(0.0, 1.0);
}

/// Shared mic level meter bars driven by real amplitude (not decorative).
class AppMicLevelBars extends StatelessWidget {
  const AppMicLevelBars({
    super.key,
    required this.level,
    this.barCount = 12,
    this.height = 28,
  });

  final double level;
  final int barCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final threshold = (i + 1) / barCount;
          final active = level >= threshold * 0.85;
          final h = 6.0 + (i + 1) * (height / barCount) * 0.55;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                height: active ? h : 6,
                decoration: BoxDecoration(
                  color: active ? scheme.onSurface : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
