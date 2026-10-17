import 'dart:async';
import 'dart:typed_data';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/features/settings/people/people_avatar.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:counter/services/notification_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PeoplePersonEditorResult {
  const PeoplePersonEditorResult.saved(this.person) : archivedRecordId = null;
  const PeoplePersonEditorResult.archived(this.archivedRecordId) : person = null;

  final LifePerson? person;
  final String? archivedRecordId;
}

class _ContactDraft {
  _ContactDraft({String label = '', String value = '', String link = ''})
      : labelController = TextEditingController(text: label),
        valueController = TextEditingController(text: value),
        linkController = TextEditingController(text: link);

  final TextEditingController labelController;
  final TextEditingController valueController;
  final TextEditingController linkController;

  Map<String, String> toMap() => <String, String>{
        'label': labelController.text.trim(),
        'value': valueController.text.trim(),
        'link': linkController.text.trim(),
      };

  void dispose() {
    labelController.dispose();
    valueController.dispose();
    linkController.dispose();
  }
}

Future<PeoplePersonEditorResult?> showPeoplePersonEditor({
  required BuildContext context,
  required PeopleService service,
  required List<PeopleCircle> circles,
  required String locale,
  LifePerson? person,
}) async {
  final metaRaw = person?.sourceRefs['_lifeos'];
  final meta = metaRaw is Map
      ? Map<String, dynamic>.from(metaRaw)
      : <String, dynamic>{};

  final legacyParts = (person?.displayName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  final firstNameController = TextEditingController(
    text: (meta['first_name']?.toString().trim().isNotEmpty ?? false)
        ? meta['first_name'].toString().trim()
        : (legacyParts.isEmpty ? '' : legacyParts.first),
  );
  final lastNameController = TextEditingController(
    text: (meta['last_name']?.toString().trim().isNotEmpty ?? false)
        ? meta['last_name'].toString().trim()
        : (legacyParts.length <= 1 ? '' : legacyParts.skip(1).join(' ')),
  );
  final notesController = TextEditingController(text: person?.notes ?? '');
  final birthdayYearController = TextEditingController(
    text: person?.birthdayYear?.toString() ?? '',
  );

  final relationships = <String>{
    if (meta['relationships'] is List)
      for (final value in meta['relationships'] as List)
        if (value.toString().trim().isNotEmpty) value.toString().trim(),
  };
  final relationshipController = TextEditingController();

  final contacts = <_ContactDraft>[];
  final contactsRaw = meta['contacts'];
  if (contactsRaw is List) {
    for (final raw in contactsRaw) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      contacts.add(
        _ContactDraft(
          label: map['label']?.toString() ?? '',
          value: map['value']?.toString() ?? '',
          link: map['link']?.toString() ?? '',
        ),
      );
    }
  }
  if (contacts.isEmpty) {
    if ((person?.primaryPhone ?? '').trim().isNotEmpty) {
      contacts.add(
        _ContactDraft(
          label: peopleT(locale, 'phone'),
          value: person!.primaryPhone,
          link: 'tel:${person.primaryPhone}',
        ),
      );
    }
    if ((person?.primaryEmail ?? '').trim().isNotEmpty) {
      contacts.add(
        _ContactDraft(
          label: peopleT(locale, 'email'),
          value: person!.primaryEmail,
          link: 'mailto:${person.primaryEmail}',
        ),
      );
    }
  }

  DateTime? birthdayDate =
      person?.birthdayMonth != null && person?.birthdayDay != null
          ? DateTime(2000, person!.birthdayMonth!, person.birthdayDay!)
          : null;
  var notificationsEnabled = person?.birthdayNotificationsEnabled ?? false;

  final selectedCircles = <String>{
    ...person?.circleRecordIds ?? const <String>[],
  };
  final reminderDays = <int>{
    ...person?.birthdayReminderDays ?? const <int>[7, 1, 0],
  };

  Uint8List? newPhotoBytes;
  String newPhotoFilename = 'person.jpg';
  var removePhoto = false;
  var saving = false;
  String? validationError;

  String displayName() => <String>[
        firstNameController.text.trim(),
        lastNameController.text.trim(),
      ].where((part) => part.isNotEmpty).join(' ');

  String primaryForLabel(String needle) {
    for (final item in contacts) {
      final label = item.labelController.text.trim().toLowerCase();
      if (label.contains(needle)) return item.valueController.text.trim();
    }
    return '';
  }

  String birthdayDateLabel() {
    final date = birthdayDate;
    if (date == null) return peopleT(locale, 'birthday_unknown');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return locale.toLowerCase().startsWith('ru') ? '$day.$month' : '$month/$day';
  }

  try {
    return await showDialog<PeoplePersonEditorResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chooseBirthdayDate() async {
            final now = DateTime.now();
            final initial = birthdayDate ?? DateTime(2000, now.month, now.day);
            final picked = await showOmniDateTimePickerDialog(
              context,
              initial: initial,
              firstDate: DateTime(2000, 1, 1),
              lastDate: DateTime(2000, 12, 31, 23, 59),
            );
            if (picked == null || !dialogContext.mounted) return;
            setDialogState(() {
              birthdayDate = DateTime(2000, picked.month, picked.day);
              validationError = null;
            });
          }

          Future<void> setBirthdayNotifications(bool value) async {
            if (!value) {
              setDialogState(() => notificationsEnabled = false);
              return;
            }
            if (birthdayDate == null) {
              await chooseBirthdayDate();
              if (birthdayDate == null) return;
            }
            final status =
                await NotificationService.instance.requestPermissions();
            if (!dialogContext.mounted) return;
            if (status == PlanAlarmPermissionStatus.denied ||
                status == PlanAlarmPermissionStatus.permanentlyDenied) {
              setDialogState(() {
                notificationsEnabled = false;
                validationError =
                    peopleT(locale, 'notifications_permission_needed');
              });
              return;
            }
            setDialogState(() {
              notificationsEnabled = true;
              validationError = null;
            });
          }

          Future<void> choosePhoto() async {
            try {
              final file = await openFile(
                acceptedTypeGroups: const <XTypeGroup>[
                  XTypeGroup(
                    label: 'Images',
                    extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
                    mimeTypes: <String>[
                      'image/jpeg',
                      'image/png',
                      'image/webp',
                    ],
                  ),
                ],
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (bytes.isEmpty) return;
              if (bytes.length > 8 * 1024 * 1024) {
                setDialogState(
                  () => validationError = peopleT(locale, 'photo_too_large'),
                );
                return;
              }
              setDialogState(() {
                newPhotoBytes = bytes;
                newPhotoFilename = file.name;
                removePhoto = false;
                validationError = null;
              });
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => validationError = peopleT(locale, 'photo_failed'),
                );
              }
            }
          }

          Future<void> save() async {
            final firstName = firstNameController.text.trim();
            final lastName = lastNameController.text.trim();
            if (firstName.isEmpty) {
              setDialogState(
                () => validationError = peopleT(locale, 'required_first_name'),
              );
              return;
            }

            final yearText = birthdayYearController.text.trim();
            final year = yearText.isEmpty ? null : int.tryParse(yearText);
            final currentYear = DateTime.now().year;
            if (yearText.isNotEmpty &&
                (year == null || year < 1 || year > currentYear)) {
              setDialogState(
                () => validationError = peopleT(locale, 'invalid_birthday_year'),
              );
              return;
            }
            if (birthdayDate == null && year != null) {
              setDialogState(
                () => validationError = peopleT(locale, 'birthday_date_required'),
              );
              return;
            }

            final cleanedContacts = contacts
                .map((item) => item.toMap())
                .where(
                  (item) =>
                      item['value']!.isNotEmpty || item['link']!.isNotEmpty,
                )
                .toList(growable: false);

            final sourceRefs = <String, dynamic>{
              ...?person?.sourceRefs,
              '_lifeos': <String, dynamic>{
                'first_name': firstName,
                'last_name': lastName,
                'relationships': relationships.toList(growable: false),
                'contacts': cleanedContacts,
              },
            };

            final birthdayMonth = birthdayDate?.month;
            final birthdayDay = birthdayDate?.day;
            final reminders = reminderDays.toList()
              ..sort((a, b) => b.compareTo(a));

            setDialogState(() {
              saving = true;
              validationError = null;
            });

            try {
              final saved = person == null
                  ? await service.createPerson(
                      displayName: displayName(),
                      relationshipStatus: PersonRelationshipStatus.known,
                      birthdayMonth: birthdayMonth,
                      birthdayDay: birthdayDay,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      birthdayReminderDays: reminders,
                      circleRecordIds:
                          selectedCircles.toList(growable: false),
                      notes: notesController.text,
                      primaryEmail: primaryForLabel('mail'),
                      primaryPhone: primaryForLabel(
                        locale.toLowerCase().startsWith('ru')
                            ? 'тел'
                            : 'phone',
                      ),
                      sourceRefs: sourceRefs,
                      photoBytes: newPhotoBytes,
                      photoFilename: newPhotoFilename,
                    )
                  : await service.updatePerson(
                      recordId: person.recordId,
                      displayName: displayName(),
                      relationshipStatus: PersonRelationshipStatus.known,
                      birthdayMonth: birthdayMonth,
                      birthdayDay: birthdayDay,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      birthdayReminderDays: reminders,
                      circleRecordIds:
                          selectedCircles.toList(growable: false),
                      notes: notesController.text,
                      primaryEmail: primaryForLabel('mail'),
                      primaryPhone: primaryForLabel(
                        locale.toLowerCase().startsWith('ru')
                            ? 'тел'
                            : 'phone',
                      ),
                      sourceRefs: sourceRefs,
                      photoBytes: newPhotoBytes,
                      photoFilename: newPhotoFilename,
                      removePhoto: removePhoto,
                    );

              if (dialogContext.mounted) {
                Navigator.of(dialogContext)
                    .pop(PeoplePersonEditorResult.saved(saved));
              }
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                validationError = peopleT(locale, 'save_failed');
              });
            }
          }

          Future<void> archive() async {
            if (person == null) return;
            setDialogState(() => saving = true);
            try {
              await service.archivePerson(person.recordId);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(
                  PeoplePersonEditorResult.archived(person.recordId),
                );
              }
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                validationError = peopleT(locale, 'save_failed');
              });
            }
          }

          final previewUrl = removePhoto
              ? person?.sourceAvatarUrl ?? ''
              : person?.avatarUrl ?? '';
          final theme = Theme.of(context);
          final media = MediaQuery.of(context);
          final isCompact = media.size.width < 600;
          final availableHeight = media.size.height -
              media.viewInsets.bottom -
              media.padding.vertical -
              24;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: availableHeight > 200 ? availableHeight : 200,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            peopleT(
                              locale,
                              person == null ? 'add_person' : 'edit_person',
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (person != null)
                          PopupMenuButton<String>(
                            enabled: !saving,
                            tooltip: peopleT(locale, 'archive'),
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (action) async {
                              if (action != 'archive') return;
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (confirmContext) => AlertDialog(
                                  title: Text(peopleT(locale, 'archive')),
                                  content: Text(
                                    peopleT(locale, 'archive_confirmation'),
                                  ),
                                  actions: [
                                    AppButton.ghost(
                                      label: peopleT(locale, 'cancel'),
                                      onPressed: () => Navigator.of(
                                        confirmContext,
                                      ).pop(false),
                                    ),
                                    AppButton.destructive(
                                      label: peopleT(locale, 'archive'),
                                      onPressed: () => Navigator.of(
                                        confirmContext,
                                      ).pop(true),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && dialogContext.mounted) {
                                unawaited(archive());
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'archive',
                                child: Text(peopleT(locale, 'archive')),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Row(
                          children: [
                            PeopleAvatar(
                              name: displayName(),
                              imageUrl: previewUrl,
                              bytes: newPhotoBytes,
                              radius: 38,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppButton.outlined(
                                    label: peopleT(locale, 'choose_photo'),
                                    size: AppButtonSize.s,
                                    icon: Icons.photo_camera_back_rounded,
                                    onPressed: saving
                                        ? null
                                        : () => unawaited(choosePhoto()),
                                  ),
                                  if (newPhotoBytes != null ||
                                      (person?.photoFileName.isNotEmpty ?? false))
                                    AppButton.ghost(
                                      label: peopleT(locale, 'remove_photo'),
                                      onPressed: saving
                                          ? null
                                          : () => setDialogState(() {
                                                newPhotoBytes = null;
                                                removePhoto = true;
                                              }),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: firstNameController,
                                autofocus: person == null,
                                enabled: !saving,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  labelText: peopleT(locale, 'first_name'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: lastNameController,
                                enabled: !saving,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  labelText: peopleT(locale, 'last_name'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          peopleT(locale, 'relationships'),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final relationship in relationships)
                              InputChip(
                                label: Text(relationship),
                                onDeleted: saving
                                    ? null
                                    : () => setDialogState(
                                          () => relationships.remove(relationship),
                                        ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: relationshipController,
                                enabled: !saving,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: peopleT(locale, 'relationship_hint'),
                                ),
                                onSubmitted: (_) {
                                  final value =
                                      relationshipController.text.trim();
                                  if (value.isEmpty) return;
                                  setDialogState(() {
                                    relationships.add(value);
                                    relationshipController.clear();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppIconButton(
                              icon: Icons.add_rounded,
                              variant: AppIconButtonVariant.filled,
                              tooltip: peopleT(locale, 'add'),
                              onPressed: saving
                                  ? null
                                  : () {
                                      final value =
                                          relationshipController.text.trim();
                                      if (value.isEmpty) return;
                                      setDialogState(() {
                                        relationships.add(value);
                                        relationshipController.clear();
                                      });
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          peopleT(locale, 'contact_details'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton.ghost(
                            size: AppButtonSize.s,
                            label: peopleT(locale, 'add_contact'),
                            icon: Icons.add_rounded,
                            onPressed: saving
                                ? null
                                : () => setDialogState(
                                      () => contacts.add(_ContactDraft()),
                                    ),
                          ),
                        ),
                        if (contacts.isEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            peopleT(locale, 'contact_details_hint'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        for (var index = 0; index < contacts.length; index++) ...[
                          const SizedBox(height: 12),
                          if (isCompact)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: contacts[index].labelController,
                                          enabled: !saving,
                                          decoration: InputDecoration(
                                            labelText: peopleT(locale, 'contact_type'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppIconButton(
                                        icon: Icons.delete_outline_rounded,
                                        variant: AppIconButtonVariant.danger,
                                        tooltip: peopleT(locale, 'remove_contact'),
                                        onPressed: saving
                                            ? null
                                            : () => setDialogState(() {
                                                  final removed =
                                                      contacts.removeAt(index);
                                                  removed.dispose();
                                                }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: contacts[index].valueController,
                                    enabled: !saving,
                                    decoration: InputDecoration(
                                      labelText: peopleT(locale, 'contact_value'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: contacts[index].linkController,
                                          enabled: !saving,
                                          keyboardType: TextInputType.url,
                                          onChanged: (_) => setDialogState(() {}),
                                          decoration: InputDecoration(
                                            labelText: peopleT(locale, 'contact_link'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppIconButton(
                                        icon: Icons.open_in_new_rounded,
                                        tooltip: peopleT(locale, 'open_link'),
                                        onPressed: contacts[index]
                                                .linkController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : () {
                                                final uri = Uri.tryParse(
                                                  contacts[index]
                                                      .linkController
                                                      .text
                                                      .trim(),
                                                );
                                                if (uri != null) {
                                                  unawaited(launchUrl(uri));
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 125,
                                  child: TextField(
                                    controller: contacts[index].labelController,
                                    enabled: !saving,
                                    decoration: InputDecoration(
                                      labelText: peopleT(locale, 'contact_type'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: contacts[index].valueController,
                                    enabled: !saving,
                                    decoration: InputDecoration(
                                      labelText: peopleT(locale, 'contact_value'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: contacts[index].linkController,
                                    enabled: !saving,
                                    keyboardType: TextInputType.url,
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: InputDecoration(
                                      labelText: peopleT(locale, 'contact_link'),
                                    ),
                                  ),
                                ),
                                AppIconButton(
                                  icon: Icons.open_in_new_rounded,
                                  tooltip: peopleT(locale, 'open_link'),
                                  onPressed: contacts[index]
                                          .linkController
                                          .text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : () {
                                          final uri = Uri.tryParse(
                                            contacts[index]
                                                .linkController
                                                .text
                                                .trim(),
                                          );
                                          if (uri != null) {
                                            unawaited(launchUrl(uri));
                                          }
                                        },
                                ),
                                AppIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  variant: AppIconButtonVariant.danger,
                                  tooltip: peopleT(locale, 'remove_contact'),
                                  onPressed: saving
                                      ? null
                                      : () => setDialogState(() {
                                            final removed = contacts.removeAt(index);
                                            removed.dispose();
                                          }),
                                ),
                              ],
                            ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          peopleT(locale, 'birthday'),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: saving
                                    ? null
                                    : () => unawaited(chooseBirthdayDate()),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText:
                                        peopleT(locale, 'birthday_date'),
                                    suffixIcon: const Icon(
                                      Icons.calendar_month_rounded,
                                    ),
                                  ),
                                  child: Text(birthdayDateLabel()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: birthdayYearController,
                                enabled: !saving && birthdayDate != null,
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: InputDecoration(
                                  labelText:
                                      peopleT(locale, 'birthday_year_optional'),
                                  hintText: peopleT(
                                    locale,
                                    'birthday_year_optional_hint',
                                  ),
                                ),
                              ),
                            ),
                            if (birthdayDate != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: peopleT(locale, 'clear'),
                                onPressed: saving
                                    ? null
                                    : () => setDialogState(() {
                                          birthdayDate = null;
                                          birthdayYearController.clear();
                                          notificationsEnabled = false;
                                        }),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          peopleT(locale, 'birthday_year_separate_hint'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(peopleT(locale, 'birthday_notifications')),
                          subtitle: Text(
                            peopleT(locale, 'birthday_notifications_hint'),
                          ),
                          value: notificationsEnabled,
                          onChanged: saving
                              ? null
                              : (value) => unawaited(
                                    setBirthdayNotifications(value),
                                  ),
                        ),
                        if (notificationsEnabled) ...[
                          Text(
                            peopleT(locale, 'remind_when'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value
                                  in const <int>[30, 14, 7, 3, 1, 0])
                                FilterChip(
                                  label: Text(_reminderLabel(locale, value)),
                                  selected: reminderDays.contains(value),
                                  onSelected: saving
                                      ? null
                                      : (selected) => setDialogState(() {
                                            if (selected) {
                                              reminderDays.add(value);
                                            } else if (reminderDays.length > 1) {
                                              reminderDays.remove(value);
                                            }
                                          }),
                                ),
                            ],
                          ),
                        ],
                        if (circles.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            peopleT(locale, 'circles'),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final circle in circles)
                                FilterChip(
                                  label: Text(circle.name),
                                  selected:
                                      selectedCircles.contains(circle.recordId),
                                  onSelected: saving
                                      ? null
                                      : (selected) => setDialogState(() {
                                            if (selected) {
                                              selectedCircles.add(circle.recordId);
                                            } else {
                                              selectedCircles
                                                  .remove(circle.recordId);
                                            }
                                          }),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextField(
                          controller: notesController,
                          enabled: !saving,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: peopleT(locale, 'notes'),
                          ),
                        ),
                        if (validationError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            validationError!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton.ghost(
                            label: peopleT(locale, 'cancel'),
                            fullWidth: true,
                            onPressed: saving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton.primary(
                            label: peopleT(locale, 'save'),
                            fullWidth: true,
                            loading: saving,
                            onPressed: saving
                                ? null
                                : () => unawaited(save()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    firstNameController.dispose();
    lastNameController.dispose();
    relationshipController.dispose();
    birthdayYearController.dispose();
    notesController.dispose();
    for (final contact in contacts) {
      contact.dispose();
    }
  }
}

String _reminderLabel(String locale, int days) {
  if (days == 0) return peopleT(locale, 'remind_same_day');
  return peopleTf(locale, 'remind_days_before', days);
}
