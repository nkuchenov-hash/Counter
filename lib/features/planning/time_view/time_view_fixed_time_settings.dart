import 'dart:async';import 'package:counter/data/database_service.dart';import 'package:counter/data/models.dart';import 'package:counter/data/time_view_fixed_time_policy.dart';import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';/// Local Time View setting: tags whose plans block cascade shifts.
class TimeViewFixedTagsSettingsBlock extends StatefulWidget {
  const TimeViewFixedTagsSettingsBlock({
    required this.initialSelectedIds,
    required this.onSave,
  });

  final Set<String> initialSelectedIds;
  final Future<void> Function(Set<String> ids) onSave;

  @override
  State<TimeViewFixedTagsSettingsBlock> createState() =>
      TimeViewFixedTagsSettingsBlockState();
}

class TimeViewFixedTagsSettingsBlockState
    extends State<TimeViewFixedTagsSettingsBlock> {
  late Set<String> _selected;
  List<Tag> _tags = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedIds);
    unawaited(_loadTags());
  }

  Future<void> _loadTags() async {
    final tags = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: TagCatalogScope.plan,
    );
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _loading = false;
    });
  }

  String _tagKey(Tag tag) {
    final pb = tag.pbRecordId?.trim();
    if (pb != null && pb.isNotEmpty) return pb;
    return tag.tagId.toString();
  }

  bool _alwaysFixed(Tag tag) =>
      kInherentlyFixedTimeTagNames.contains(tag.name.trim().toLowerCase());

  Future<void> _toggle(Tag tag) async {
    if (_alwaysFixed(tag)) return; // Meetings are immutable by default.
    final key = _tagKey(tag);
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
    await widget.onSave(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final title = loc == 'ru'
        ? 'Теги с фиксированным временем'
        : 'Fixed-time tags';
    final subtitle = loc == 'ru'
        ? 'Встречи и звонки защищены всегда. Остальные выбранные теги также не сдвигаются.'
        : 'Meetings and calls are always fixed. Other selected tags also block shifts.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_clock_outlined),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc == 'ru' ? 'Нет тегов' : 'No tags',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: _alwaysFixed(tag) || _selected.contains(_tagKey(tag)),
                  onSelected: _alwaysFixed(tag)
                      ? null
                      : (_) => unawaited(_toggle(tag)),
                ),
            ],
          ),
      ],
    );
  }
}
