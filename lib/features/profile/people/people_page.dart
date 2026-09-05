import 'package:counter/features/profile/people/people_l10n.dart';
import 'package:counter/features/profile/people/people_repository.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  static const _groups = ['close', 'family', 'friends', 'work', 'other'];

  bool _loading = true;
  String? _error;
  List<PersonEntry> _people = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await PeopleRepository.instance.list();
      if (!mounted) return;
      setState(() {
        _people = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = peopleT(currentLocale.value, 'load_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(peopleT(loc, 'title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(peopleT(loc, 'add')),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              peopleT(loc, 'subtitle'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _MessageCard(
                icon: Icons.cloud_off_rounded,
                text: _error!,
                action: TextButton(
                  onPressed: _reload,
                  child: Text(t(loc, 'refresh_now')),
                ),
              )
            else if (_people.isEmpty)
              _MessageCard(
                icon: Icons.people_outline_rounded,
                text: peopleT(loc, 'empty'),
              )
            else
              ..._buildGroupedPeople(context, loc),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedPeople(BuildContext context, String loc) {
    final widgets = <Widget>[];
    for (final group in _groups) {
      final rows = _people.where((p) => p.group == group).toList();
      if (rows.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            peopleT(loc, group),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final person in rows) {
        widgets.add(_personTile(context, loc, person));
      }
    }
    return widgets;
  }

  Widget _personTile(BuildContext context, String loc, PersonEntry person) {
    final birthday = person.birthday == null
        ? null
        : _formatBirthday(person.birthday!);
    final subtitleParts = <String>[
      if (birthday != null) '${peopleT(loc, 'birthday')}: $birthday',
      if (person.notes.isNotEmpty) person.notes,
    ];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase(),
          ),
        ),
        title: Text(person.name),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openEditor(person),
      ),
    );
  }

  Future<void> _openEditor([PersonEntry? person]) async {
    final loc = currentLocale.value;
    final name = TextEditingController(text: person?.name ?? '');
    final notes = TextEditingController(text: person?.notes ?? '');
    var group = person?.group ?? 'friends';
    var birthday = person?.birthday;
    var saving = false;
    String? localError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(person == null ? peopleT(loc, 'add') : person.name),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: name,
                        autofocus: person == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: peopleT(loc, 'name'),
                          errorText: localError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: group,
                        decoration: InputDecoration(labelText: peopleT(loc, 'group')),
                        items: [
                          for (final item in _groups)
                            DropdownMenuItem(
                              value: item,
                              child: Text(peopleT(loc, item)),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => group = value);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: birthday ?? DateTime(now.year - 30),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(now.year),
                                );
                                if (picked != null) {
                                  setDialogState(() => birthday = picked);
                                }
                              },
                        icon: const Icon(Icons.cake_outlined),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            birthday == null
                                ? peopleT(loc, 'birthday_optional')
                                : _formatBirthday(birthday!),
                          ),
                        ),
                      ),
                      if (birthday != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: saving
                                ? null
                                : () => setDialogState(() => birthday = null),
                            child: Text(t(loc, 'delete')),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: peopleT(loc, 'notes_optional'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (person != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setDialogState(() => saving = true);
                            try {
                              await PeopleRepository.instance.delete(person.id);
                              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                            } catch (_) {
                              setDialogState(() {
                                saving = false;
                                localError = peopleT(loc, 'delete_error');
                              });
                            }
                          },
                    child: Text(
                      peopleT(loc, 'delete'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                  child: Text(peopleT(loc, 'cancel')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final trimmed = name.text.trim();
                          if (trimmed.isEmpty) {
                            setDialogState(
                              () => localError = peopleT(loc, 'name_required'),
                            );
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            localError = null;
                          });
                          try {
                            if (person == null) {
                              await PeopleRepository.instance.create(
                                name: trimmed,
                                group: group,
                                birthday: birthday,
                                notes: notes.text,
                              );
                            } else {
                              await PeopleRepository.instance.update(
                                person,
                                name: trimmed,
                                group: group,
                                birthday: birthday,
                                notes: notes.text,
                              );
                            }
                            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                          } catch (_) {
                            setDialogState(() {
                              saving = false;
                              localError = peopleT(loc, 'save_error');
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(peopleT(loc, 'save')),
                ),
              ],
            );
          },
        );
      },
    );

    name.dispose();
    notes.dispose();
    if (saved == true) {
      await _reload();
    }
  }

  String _formatBirthday(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(child: Text(text)),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
