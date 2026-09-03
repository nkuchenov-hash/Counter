import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/features/settings/people/people_avatar.dart';
import 'package:counter/features/settings/people/people_person_editor.dart';
import 'package:counter/features/settings/people/people_sources_section.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

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
  _PeopleSection _section = _PeopleSection.people;
  bool _loading = true;
  String? _error;

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
      circles.sort(_circleSort);
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

  int _circleSort(PeopleCircle a, PeopleCircle b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0
        ? byOrder
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _upsertPerson(LifePerson person) {
    final next = List<LifePerson>.from(_people);
    final index = next.indexWhere((item) => item.recordId == person.recordId);
    if (index >= 0) {
      next[index] = person;
    } else {
      next.add(person);
    }
    next.sort(_personSort);
    setState(() => _people = next);
  }

  Future<void> _showPersonEditor({LifePerson? person}) async {
    final result = await showPeoplePersonEditor(
      context: context,
      service: _service,
      circles: _circles,
      locale: _locale,
      person: person,
    );
    if (!mounted || result == null) return;
    if (result.person != null) {
      _upsertPerson(result.person!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(peopleT(_locale, 'saved'))),
      );
      return;
    }
    final archivedId = result.archivedRecordId;
    if (archivedId != null) {
      setState(() {
        _people = _people
            .where((item) => item.recordId != archivedId)
            .toList(growable: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: settingsNeutralTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(peopleT(_locale, 'title')),
          actions: [
            IconButton(
              tooltip: peopleT(_locale, 'refresh'),
              onPressed: _loading ? null : () => unawaited(_loadHome()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
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
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  setState(() => _section = selected.first);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: AppLoading(),
              )
            else if (_error != null)
              _InlineError(
                message: peopleT(_locale, 'load_failed'),
                detail: _error,
                onRetry: _loadHome,
              )
            else
              switch (_section) {
                _PeopleSection.people => _buildPeople(context),
                _PeopleSection.circles => _buildCircles(context),
                _PeopleSection.sources => PeopleSourcesSection(
                    locale: _locale,
                    people: _people,
                    onPersonLinked: _upsertPerson,
                  ),
              },
          ],
        ),
      ),
    );
  }

  Widget _buildPeople(BuildContext context) {
    final visible = _people
        .where((person) =>
            !person.archived &&
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
            onPressed: () => unawaited(_showPersonEditor()),
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
              onTap: () => unawaited(_showPersonEditor(person: person)),
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
            onPressed: () => unawaited(_showCircleEditor()),
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
                subtitle: Text(
                  peopleTf(
                    _locale,
                    'people_count',
                    countByCircle[circle.recordId] ?? 0,
                  ),
                ),
                onTap: () => unawaited(_showCircleEditor(circle: circle)),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
      ],
    );
  }

  Future<void> _showCircleEditor({PeopleCircle? circle}) async {
    final controller = TextEditingController(text: circle?.name ?? '');
    var saving = false;
    String? error;
    try {
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
                    : await _service.renameCircle(
                        recordId: circle.recordId,
                        name: name,
                      );
                if (!mounted) return;
                final next = List<PeopleCircle>.from(_circles);
                final index = next.indexWhere(
                  (item) => item.recordId == saved.recordId,
                );
                if (index >= 0) {
                  next[index] = saved;
                } else {
                  next.add(saved);
                }
                next.sort(_circleSort);
                setState(() => _circles = next);
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
              title: Text(
                peopleT(_locale, circle == null ? 'add_circle' : 'edit_circle'),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !saving,
                      decoration: InputDecoration(
                        labelText: peopleT(_locale, 'circle_name'),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
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
    } finally {
      controller.dispose();
    }
  }

  String _statusLabel(PersonRelationshipStatus status) => switch (status) {
        PersonRelationshipStatus.important => peopleT(_locale, 'status_important'),
        PersonRelationshipStatus.known => peopleT(_locale, 'status_known'),
        PersonRelationshipStatus.reference => peopleT(_locale, 'status_reference'),
        PersonRelationshipStatus.ignored => peopleT(_locale, 'ignored'),
        PersonRelationshipStatus.blocked => peopleT(_locale, 'blocked'),
      };

  String _birthdayLabel(LifePerson person) {
    if (!person.hasBirthday) return peopleT(_locale, 'birthday_unknown');
    final month = person.birthdayMonth!;
    final day = person.birthdayDay!;
    final year = person.birthdayYear;
    if (_locale.toLowerCase().startsWith('ru')) {
      return year == null
          ? '$day.${month.toString().padLeft(2, '0')}'
          : '$day.${month.toString().padLeft(2, '0')}.$year';
    }
    return year == null ? '$month/$day' : '$month/$day/$year';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PeopleAvatar(
                name: person.displayName,
                imageUrl: person.avatarUrl,
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          statusLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          birthdayLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (person.primaryPhone.isNotEmpty)
                          Text(
                            person.primaryPhone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (circleNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final circle in circleNames)
                            Chip(
                              label: Text(circle),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSettingsSectionCard(
      title: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail != null && detail!.isNotEmpty) ...[
            Text(
              detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          AppButton.secondary(
            label: peopleT(currentLocale.value, 'retry'),
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
