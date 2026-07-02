import 'dart:async';import 'package:counter/core/tag_contrast.dart';import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';/// “No Tags” synthetic chip: visibility + B/W presets (Planning settings sheet only).
class PlanningNoTagsSettingsBlock extends StatefulWidget {
  const PlanningNoTagsSettingsBlock({
    required this.initialVisible,
    required this.initialColorHex,
    required this.onApply,
  });

  final bool initialVisible;
  final String initialColorHex;
  final Future<void> Function(bool visible, String colorHex) onApply;

  @override
  State<PlanningNoTagsSettingsBlock> createState() =>
      PlanningNoTagsSettingsBlockState();
}

class PlanningNoTagsSettingsBlockState
    extends State<PlanningNoTagsSettingsBlock> {
  static const List<String> _presets = <String>[
    '#000000',
    '#FFFFFF',
    '#9E9E9E',
    '#F44336',
    '#2196F3',
    '#4CAF50',
    '#FF9800',
  ];

  late bool _visible;
  late String _colorHex;

  @override
  void initState() {
    super.initState();
    _visible = widget.initialVisible;
    _colorHex = widget.initialColorHex;
  }

  Future<void> _persist() async {
    await widget.onApply(_visible, _colorHex);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t(loc, 'plan_filter_no_tags')),
            subtitle: Text(t(loc, 'category_visibility_toggle')),
            value: _visible,
            onChanged: (v) {
              setState(() => _visible = v);
              unawaited(_persist());
            },
          ),
          Text(
            t(loc, 'category_color'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _presets)
                GestureDetector(
                  onTap: () {
                    setState(() => _colorHex = h);
                    unawaited(_persist());
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: parseTagHexColor(h),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorHex == h
                            ? scheme.primary
                            : (h == '#FFFFFF'
                                  ? scheme.outline
                                  : Colors.transparent),
                        width: _colorHex == h ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
