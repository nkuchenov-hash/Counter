import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_mic_level_bars.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal microphone card shell for layout regression (no device/STT I/O).
class _TestMicrophoneCard extends StatelessWidget {
  const _TestMicrophoneCard();

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    return AppSettingsGridCard(
      leading: const Icon(Icons.settings_voice_outlined),
      title: t(loc, 'desktop_voice_card_microphone'),
      subtitle: t(loc, 'desktop_voice_mic_select_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownMenu<String?>(
            initialSelection: null,
            expandedInsets: EdgeInsets.zero,
            label: Text(t(loc, 'desktop_voice_mic_select_label')),
            dropdownMenuEntries: [
              DropdownMenuEntry<String?>(
                value: null,
                label: t(loc, 'desktop_voice_mic_device_default'),
              ),
            ],
            onSelected: (_) {},
          ),
          const SizedBox(height: 12),
          Text(
            t(loc, 'desktop_voice_mic_input_level'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          const AppMicLevelBars(level: 0.2, height: 32),
          const SizedBox(height: 16),
          AppSettingsActionRow(
            children: [
              AppButton.secondary(
                label: t(loc, 'desktop_voice_mic_start_monitor'),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('Microphone card primary action is fully visible', (
    tester,
  ) async {
    currentLocale.value = 'en';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: const _TestMicrophoneCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(AppButton);
    expect(buttonFinder, findsOneWidget);

    final clip = tester.renderObject<RenderBox>(buttonFinder);
    final card = tester.renderObject<RenderBox>(find.byType(Card));
    expect(
      clip.size.height,
      greaterThan(0),
      reason: 'monitor button should have non-zero height',
    );
    expect(
      clip.localToGlobal(Offset.zero).dy + clip.size.height,
      lessThanOrEqualTo(
        card.localToGlobal(Offset.zero).dy + card.size.height + 1,
      ),
      reason: 'monitor button must fit inside the microphone card',
    );
  });
}
