import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _PeopleSection { people, circles, sources }

class PeopleSettingsPage extends StatefulWidget {
  const PeopleSettingsPage({super.key});

  @override
  State<PeopleSettingsPage> createState() => _PeopleSettingsPageState();
}

class _PeopleSettingsPageState extends State<PeopleSettingsPage> {
  final PeopleService _service = PeopleService.instance;
  List<LifePerson> _people = const <LifePerson>[];
  List<PeopleCircle> _circles = const <PeopleCircle>[];
  List<PeopleSourceStats> _sourceStats = const <PeopleSourceStats>[];
  _PeopleSection _section = _PeopleSection.people;
  bool _loading = true;
  bool _sourcesLoading = false;
  String? _error;
  String? _sourcesError;

  String get _locale => currentLocale.value;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHome());
  }

  Future<void> _loadHome() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final (people, circles) = await _service.fetchPeopleHome();
      people.sort(_personSort);
      if (!mounted) return;
      setState(() {
        _people = people;
        _circles = circles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  int _personSort(LifePerson a, LifePerson b) {
    int rank(PersonRelationshipStatus status) => switch (status) {
          PersonRelationshipStatus.important => 0,
          PersonRelationshipStatus.known => 1,
          PersonRelationshipStatus.reference => 2,
          PersonRelationshipStatus.ignored => 3,
          PersonRelationshipStatus.blocked => 4,
        };
    final byStatus = rank(a.relationshipStatus).compareTo(rank(b.relationshipStatus));
    if (byStatus != 0) return byStatus;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  Future<void> _loadSources() async {
    if (_sourcesLoading) return;
    setState(() {
      _sourcesLoading = true;
      _sourcesError = null;
    });
    try {
      final stats = await _service.fetchSourceStats();
      if (!mounted) return;
      setState(() {
        _sourceStats = stats;
        _sourcesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sourcesLoading = false;
        _sourcesError = '$error';
      });
    }
  }

  void _selectSection(Set<_PeopleSection> selected) {
    if (selected.isEmpty) return;
    final next = selected.first;
    if (next == _section) return;
    setState(() => _section = next);
    if (next == _PeopleSection.sources && _sourceStats.isEmpty) {
      unawaited(_loadSources());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: settingsNeutralTheme(context),
      child: Scaffold(
        appBar: AppBar(title: Text(peopleT(_locale, 'title'))),
        body: AppSettingsPageBody(
          children: [
            Text(
              peopleT(_locale, 'subtitle'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_PeopleSection>(
              segments: <ButtonSegment<_PeopleSection>>[
                ButtonSegment<_PeopleSection>(
                  value: _PeopleSection.people,
                  icon: const Icon(Icons.people_alt_rounded),
                  label: Text(peopleT(_locale, 'tab_people')),
                ),
                ButtonSegment<_PeopleSection>(
                  value: _PeopleSection.circles,
                  icon: const Icon(Icons.hub_rounded),
                  label: Text(peopleT(_locale, 'tab_circles')),
                ),
                ButtonSegment<_PeopleSection>(
                  value: _PeopleSection.sources,
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: Text(peopleT(_locale, 'tab_sources')),
                ),
              ],
              selected: <_PeopleSection>{_section},
              onSelectionChanged: _selectSection,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: AppLoading()),
              )
            else if (_error != null)
              _InlineError(
                message: peopleT(_locale, 'load_failed'),
                onRetry: _loadHome,
              )
            else
              switch (_section) {
                _PeopleSection.people => _buildPeople(context),
                _PeopleSection.circles => _buildCircles(context),
                _PeopleSection.sources => _buildSources(context),
              },
          ],
        ),
      ),
    );
  }

  Widget _buildPeople(BuildContext context) {
    final visible = _people
        .where((person) =>
            person.relationshipStatus != PersonRelationshipStatus.ignored &&
            person.relationshipStatus != PersonRelationshipStatus.blocked)
        .toList(growable: false);
    final circleById = <String, PeopleCircle>{
      for (final circle in _circles) circle.recordId: circle,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            label: peopleT(_locale, 'add_person'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _showPersonEditor(),
          ),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          AppSettingsSectionCard(
            title: peopleT(_locale, 'no_people'),
            child: Text(
              peopleT(_locale, 'no_people_hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          )
        else
          for (final person in visible)
            _PersonCard(
              person: person,
              statusLabel: _statusLabel(person.relationshipStatus),
              birthdayLabel: _birthdayLabel(person),
              circleNames: <String>[
                for (final id in person.circleRecordIds)
                  if (circleById[id] != null) circleById[id]!.name,
              ],
              onTap: () => _showPersonEditor(person: person),
            ),
      ],
    );
  }

  Widget _buildCircles(BuildContext context) {
    final countByCircle = <String, int>{};
    for (final person in _people) {
      if (person.archived ||
          person.relationshipStatus == PersonRelationshipStatus.ignored ||
          person.relationshipStatus == PersonRelationshipStatus.blocked) {
        continue;
      }
      for (final circleId in person.circleRecordIds) {
        countByCircle[circleId] = (countByCircle[circleId] ?? 0) + 1;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.primary(
            label: peopleT(_locale, 'add_circle'),
            icon: Icons.add_rounded,
            onPressed: () => _showCircleEditor(),
          ),
        ),
        const SizedBox(height: 16),
        if (_circles.isEmpty)
          AppSettingsSectionCard(
            title: peopleT(_locale, 'no_circles'),
            child: Text(
              peopleT(_locale, 'no_circles_hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          )
        else
          for (final circle in _circles)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.hub_rounded)),
                title: Text(circle.name),
                subtitle: Text('${countByCircle[circle.recordId] ?? 0}'),
                onTap: () => _showCircleEditor(circle: circle),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
      ],
    );
  }

  Widget _buildSources(BuildContext context) {
    final statByProvider = <PeopleSourceProvider, PeopleSourceStats>{
      for (final stat in _sourceStats) stat.provider: stat,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsSectionCard(
          title: peopleT(_locale, 'source_rule_title'),
          child: Text(
            peopleT(_locale, 'source_rule_body'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ),
        if (_sourcesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: AppLoading()),
          )
        else if (_sourcesError != null)
          _InlineError(
            message: peopleT(_locale, 'source_adapter_pending'),
            onRetry: _loadSources,
          )
        else
          AppSettingsCardGrid(
            children: [
              for (final provider in const <PeopleSourceProvider>[
                PeopleSourceProvider.deviceContacts,
                PeopleSourceProvider.googleContacts,
                PeopleSourceProvider.vk,
                PeopleSourceProvider.telegram,
                PeopleSourceProvider.microsoft,
                PeopleSourceProvider.facebook,
              ])
                _SourceCard(
                  title: _sourceLabel(provider),
                  stat: statByProvider[provider],
                  locale: _locale,
                ),
            ],
          ),
      ],
    );
  }

  String _sourceLabel(PeopleSourceProvider provider) => switch (provider) {
        PeopleSourceProvider.deviceContacts => peopleT(_locale, 'source_device'),
        PeopleSourceProvider.googleContacts => peopleT(_locale, 'source_google'),
        PeopleSourceProvider.microsoft => peopleT(_locale, 'source_microsoft'),
        PeopleSourceProvider.vk => peopleT(_locale, 'source_vk'),
        PeopleSourceProvider.telegram => peopleT(_locale, 'source_telegram'),
        PeopleSourceProvider.facebook => peopleT(_locale, 'source_facebook'),
        PeopleSourceProvider.manual => peopleT(_locale, 'tab_people'),
      };

  String _statusLabel(PersonRelationshipStatus status) => switch (status) {
        PersonRelationshipStatus.important => peopleT(_locale, 'status_important'),
        PersonRelationshipStatus.known => peopleT(_locale, 'status_known'),
        PersonRelationshipStatus.reference => peopleT(_locale, 'status_reference'),
        PersonRelationshipStatus.ignored => 'Ignored',
        PersonRelationshipStatus.blocked => 'Blocked',
      };

  String _birthdayLabel(LifePerson person) {
    if (!person.hasBirthday) return peopleT(_locale, 'birthday_unknown');
    final month = person.birthdayMonth!;
    final day = person.birthdayDay!;
    final year = person.birthdayYear;
    if (_locale.toLowerCase().startsWith('ru')) {
      return year == null ? '$day.${month.toString().padLeft(2, '0')}' :
          '$day.${month.toString().padLeft(2, '0')}.$year';
    }
    return year == null ? '$month/$day' : '$month/$day/$year';
  }

  Future<void> _showPersonEditor({LifePerson? person}) async {
    final nameController = TextEditingController(text: person?.displayName ?? '');
    final yearController = TextEditingController(
      text: person?.birthdayYear?.toString() ?? '',
    );
    final notesController = TextEditingController(text: person?.notes ?? '');
    var status = person?.relationshipStatus ?? PersonRelationshipStatus.known;
    if (status == PersonRelationshipStatus.ignored ||
        status == PersonRelationshipStatus.blocked) {
      status = PersonRelationshipStatus.known;
    }
    int? month = person?.birthdayMonth;
    int? day = person?.birthdayDay;
    var notificationsEnabled = person?.birthdayNotificationsEnabled ?? false;
    final selectedCircles = <String>{...person?.circleRecordIds ?? const <String>[]};
    var saving = false;
    String? validationError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setDialogState(() => validationError = peopleT(_locale, 'required_name'));
              return;
            }
            if ((month == null) != (day == null)) {
              setDialogState(() => validationError = peopleT(_locale, 'invalid_birthday'));
              return;
            }
            final yearText = yearController.text.trim();
            final year = yearText.isEmpty ? null : int.tryParse(yearText);
            if (yearText.isNotEmpty && year == null) {
              setDialogState(() => validationError = peopleT(_locale, 'invalid_birthday'));
              return;
            }
            setDialogState(() {
              saving = true;
              validationError = null;
            });
            try {
              final saved = person == null
                  ? await _service.createPerson(
                      displayName: name,
                      relationshipStatus: status,
                      birthdayMonth: month,
                      birthdayDay: day,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      circleRecordIds: selectedCircles.toList(growable: false),
                      notes: notesController.text,
                    )
                  : await _service.updatePerson(
                      recordId: person.recordId,
                      displayName: name,
                      relationshipStatus: status,
                      birthdayMonth: month,
                      birthdayDay: day,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      circleRecordIds: selectedCircles.toList(growable: false),
                      notes: notesController.text,
                    );
              if (!mounted) return;
              setState(() {
                final next = List<LifePerson>.from(_people);
                final index = next.indexWhere((item) => item.recordId == saved.recordId);
                if (index >= 0) {
                  next[index] = saved;
                } else {
                  next.add(saved);
                }
                next.sort(_personSort);
                _people = next;
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(peopleT(_locale, 'saved'))),
              );
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                validationError = peopleT(_locale, 'save_failed');
              });
            }
          }

          Future<void> archive() async {
            if (person == null) return;
            setDialogState(() => saving = true);
            try {
              await _service.archivePerson(person.recordId);
              if (!mounted) return;
              setState(() {
                _people = _people
                    .where((item) => item.recordId != person.recordId)
                    .toList(growable: false);
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  saving = false;
                  validationError = peopleT(_locale, 'save_failed');
                });
              }
            }
          }

          return AlertDialog(
            title: Text(peopleT(_locale, person == null ? 'add_person' : 'edit_person')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: person == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: peopleT(_locale, 'name')),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PersonRelationshipStatus>(
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: peopleT(_locale, 'relationship'),
                      ),
                      items: <PersonRelationshipStatus>[
                        PersonRelationshipStatus.important,
                        PersonRelationshipStatus.known,
                        PersonRelationshipStatus.reference,
                      ]
                          .map(
                            (value) => DropdownMenuItem<PersonRelationshipStatus>(
                              value: value,
                              child: Text(_statusLabel(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) setDialogState(() => status = value);
                            },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      peopleT(_locale, 'birthday'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: month,
                            decoration: InputDecoration(
                              labelText: peopleT(_locale, 'birthday_month'),
                            ),
                            items: <DropdownMenuItem<int>>[
                              for (var value = 1; value <= 12; value++)
                                DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value'),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(() {
                                      month = value;
                                      if (month == null) notificationsEnabled = false;
                                    }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: day,
                            decoration: InputDecoration(
                              labelText: peopleT(_locale, 'birthday_day'),
                            ),
                            items: <DropdownMenuItem<int>>[
                              for (var value = 1; value <= 31; value++)
                                DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value'),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(() {
                                      day = value;
                                      if (day == null) notificationsEnabled = false;
                                    }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            enabled: !saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: peopleT(_locale, 'birthday_year'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(peopleT(_locale, 'birthday_notifications')),
                      subtitle: Text(peopleT(_locale, 'birthday_notifications_hint')),
                      value: notificationsEnabled && month != null && day != null,
                      onChanged: saving || month == null || day == null
                          ? null
                          : (value) => setDialogState(
                                () => notificationsEnabled = value,
                              ),
                    ),
                    if (_circles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        peopleT(_locale, 'circles'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final circle in _circles)
                            FilterChip(
                              label: Text(circle.name),
                              selected: selectedCircles.contains(circle.recordId),
                              onSelected: saving
                                  ? null
                                  : (selected) => setDialogState(() {
                                        if (selected) {
                                          selectedCircles.add(circle.recordId);
                                        } else {
                                          selectedCircles.remove(circle.recordId);
                                        }
                                      }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      enabled: !saving,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: peopleT(_locale, 'notes')),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (person != null)
                AppButton.destructive(
                  label: peopleT(_locale, 'archive'),
                  onPressed: saving ? null : () => unawaited(archive()),
                ),
              AppButton.ghost(
                label: peopleT(_locale, 'cancel'),
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
              ),
              AppButton.primary(
                label: peopleT(_locale, 'save'),
                loading: saving,
                onPressed: saving ? null : () => unawaited(save()),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    yearController.dispose();
    notesController.dispose();
  }

  Future<void> _showCircleEditor({PeopleCircle? circle}) async {
    final controller = TextEditingController(text: circle?.name ?? '');
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            final name = controller.text.trim();
            if (name.isEmpty) {
              setDialogState(() => error = peopleT(_locale, 'required_name'));
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final saved = circle == null
                  ? await _service.createCircle(name)
                  : await _service.renameCircle(recordId: circle.recordId, name: name);
              if (!mounted) return;
              setState(() {
                final next = List<PeopleCircle>.from(_circles);
                final index = next.indexWhere((item) => item.recordId == saved.recordId);
                if (index >= 0) {
                  next[index] = saved;
                } else {
                  next.add(saved);
                }
                next.sort((a, b) {
                  final byOrder = a.sortOrder.compareTo(b.sortOrder);
                  return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
                });
                _circles = next;
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  saving = false;
                  error = peopleT(_locale, 'save_failed');
                });
              }
            }
          }

          Future<void> archive() async {
            if (circle == null) return;
            setDialogState(() => saving = true);
            try {
              await _service.archiveCircle(circle.recordId);
              if (!mounted) return;
              setState(() {
                _circles = _circles
                    .where((item) => item.recordId != circle.recordId)
                    .toList(growable: false);
              });
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  saving = false;
                  error = peopleT(_locale, 'save_failed');
                });
              }
            }
          }

          return AlertDialog(
            title: Text(peopleT(_locale, circle == null ? 'add_circle' : 'circles')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: peopleT(_locale, 'circle_name')),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
            actions: [
              if (circle != null)
                AppButton.destructive(
                  label: peopleT(_locale, 'archive'),
                  onPressed: saving ? null : () => unawaited(archive()),
                ),
              AppButton.ghost(
                label: peopleT(_locale, 'cancel'),
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
              ),
              AppButton.primary(
                label: peopleT(_locale, 'save'),
                loading: saving,
                onPressed: saving ? null : () => unawaited(save()),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.statusLabel,
    required this.birthdayLabel,
    required this.circleNames,
    required this.onTap,
  });

  final LifePerson person;
  final String statusLabel;
  final String birthdayLabel;
  final List<String> circleNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = person.displayName.trim().isEmpty
        ? '?'
        : person.displayName.trim().characters.first.toUpperCase();
    final secondary = <String>[
      statusLabel,
      birthdayLabel,
      if (circleNames.isNotEmpty) circleNames.join(' · '),
    ].join('  •  ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(child: Text(initial)),
        title: Text(
          person.displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: person.relationshipStatus == PersonRelationshipStatus.important
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
        ),
        subtitle: Text(secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: person.relationshipStatus == PersonRelationshipStatus.important
            ? const Icon(Icons.star_rounded)
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.stat,
    required this.locale,
  });

  final String title;
  final PeopleSourceStats? stat;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final value = stat;
    final details = value == null || value!.total == 0
        ? peopleT(locale, 'source_none')
        : <String>[
            peopleTf(locale, 'source_total', value.total),
            if (value.candidates > 0)
              peopleTf(locale, 'source_candidates', value.candidates),
            if (value.linked > 0) peopleTf(locale, 'source_linked', value.linked),
            if (value.ignored > 0) peopleTf(locale, 'source_ignored', value.ignored),
            if (value.blocked > 0) peopleTf(locale, 'source_blocked', value.blocked),
          ].join(' · ');
    return AppSettingsGridCard(
      title: title,
      subtitle: details,
      leading: const Icon(Icons.contacts_rounded),
      child: Text(
        value == null || value.total == 0
            ? peopleT(locale, 'source_not_connected')
            : peopleT(locale, 'source_adapter_pending'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSettingsSectionCard(
      title: message,
      child: AppButton.secondary(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        onPressed: () => unawaited(onRetry()),
      ),
    );
  }
}
