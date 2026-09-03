import 'dart:async';
import 'dart:typed_data';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/features/settings/people/people_avatar.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PeoplePersonEditorResult {
  const PeoplePersonEditorResult.saved(this.person) : archivedRecordId = null;
  const PeoplePersonEditorResult.archived(this.archivedRecordId) : person = null;

  final LifePerson? person;
  final String? archivedRecordId;
}

Future<PeoplePersonEditorResult?> showPeoplePersonEditor({
  required BuildContext context,
  required PeopleService service,
  required List<PeopleCircle> circles,
  required String locale,
  LifePerson? person,
}) async {
  final nameController = TextEditingController(text: person?.displayName ?? '');
  final emailController = TextEditingController(text: person?.primaryEmail ?? '');
  final phoneController = TextEditingController(text: person?.primaryPhone ?? '');
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

  try {
    return await showDialog<PeoplePersonEditorResult>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
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
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setDialogState(
                () => validationError = peopleT(locale, 'required_name'),
              );
              return;
            }
            if ((month == null) != (day == null)) {
              setDialogState(
                () => validationError = peopleT(locale, 'invalid_birthday'),
              );
              return;
            }
            final yearText = yearController.text.trim();
            final year = yearText.isEmpty ? null : int.tryParse(yearText);
            if (yearText.isNotEmpty && year == null) {
              setDialogState(
                () => validationError = peopleT(locale, 'invalid_birthday'),
              );
              return;
            }
            if (month != null && day != null) {
              final validationYear = year ?? 2000;
              final date = DateTime(validationYear, month!, day!);
              if (date.month != month || date.day != day) {
                setDialogState(
                  () => validationError = peopleT(locale, 'invalid_birthday'),
                );
                return;
              }
            }
            setDialogState(() {
              saving = true;
              validationError = null;
            });
            try {
              final reminders = reminderDays.toList()
                ..sort((a, b) => b.compareTo(a));
              final saved = person == null
                  ? await service.createPerson(
                      displayName: name,
                      relationshipStatus: status,
                      birthdayMonth: month,
                      birthdayDay: day,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      birthdayReminderDays: reminders,
                      circleRecordIds: selectedCircles.toList(growable: false),
                      notes: notesController.text,
                      primaryEmail: emailController.text,
                      primaryPhone: phoneController.text,
                      photoBytes: newPhotoBytes,
                      photoFilename: newPhotoFilename,
                    )
                  : await service.updatePerson(
                      recordId: person.recordId,
                      displayName: name,
                      relationshipStatus: status,
                      birthdayMonth: month,
                      birthdayDay: day,
                      birthdayYear: year,
                      birthdayNotificationsEnabled: notificationsEnabled,
                      birthdayReminderDays: reminders,
                      circleRecordIds: selectedCircles.toList(growable: false),
                      notes: notesController.text,
                      primaryEmail: emailController.text,
                      primaryPhone: phoneController.text,
                      photoBytes: newPhotoBytes,
                      photoFilename: newPhotoFilename,
                      removePhoto: removePhoto,
                    );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(
                  PeoplePersonEditorResult.saved(saved),
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

          final previewUrl = removePhoto ? person?.sourceAvatarUrl ?? '' : person?.avatarUrl ?? '';
          return AlertDialog(
            title: Text(
              peopleT(locale, person == null ? 'add_person' : 'edit_person'),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        PeopleAvatar(
                          name: nameController.text,
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
                              AppButton.secondary(
                                label: peopleT(locale, 'choose_photo'),
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
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      autofocus: person == null,
                      textCapitalization: TextCapitalization.words,
                      enabled: !saving,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: peopleT(locale, 'name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PersonRelationshipStatus>(
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: peopleT(locale, 'relationship'),
                      ),
                      items: <PersonRelationshipStatus>[
                        PersonRelationshipStatus.important,
                        PersonRelationshipStatus.known,
                        PersonRelationshipStatus.reference,
                      ]
                          .map(
                            (value) => DropdownMenuItem<PersonRelationshipStatus>(
                              value: value,
                              child: Text(_statusLabel(locale, value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: peopleT(locale, 'phone'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      enabled: !saving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: peopleT(locale, 'email'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peopleT(locale, 'birthday'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (month != null || day != null ||
                            yearController.text.isNotEmpty)
                          AppButton.ghost(
                            label: peopleT(locale, 'clear'),
                            onPressed: saving
                                ? null
                                : () => setDialogState(() {
                                      month = null;
                                      day = null;
                                      yearController.clear();
                                      notificationsEnabled = false;
                                    }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: month,
                            decoration: InputDecoration(
                              labelText: peopleT(locale, 'birthday_month'),
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
                                : (value) => setDialogState(() => month = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: day,
                            decoration: InputDecoration(
                              labelText: peopleT(locale, 'birthday_day'),
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
                                : (value) => setDialogState(() => day = value),
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
                              labelText: peopleT(locale, 'birthday_year'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(peopleT(locale, 'birthday_notifications')),
                      subtitle: Text(
                        peopleT(locale, 'birthday_notifications_hint'),
                      ),
                      value: notificationsEnabled && month != null && day != null,
                      onChanged: saving || month == null || day == null
                          ? null
                          : (value) => setDialogState(
                                () => notificationsEnabled = value,
                              ),
                    ),
                    if (notificationsEnabled && month != null && day != null) ...[
                      Text(
                        peopleT(locale, 'remind_when'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in const <int>[30, 14, 7, 3, 1, 0])
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
                      const SizedBox(height: 18),
                      Text(
                        peopleT(locale, 'circles'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
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
                    const SizedBox(height: 18),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (person != null)
                AppButton.destructive(
                  label: peopleT(locale, 'archive'),
                  onPressed: saving ? null : () => unawaited(archive()),
                ),
              AppButton.ghost(
                label: peopleT(locale, 'cancel'),
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              AppButton.primary(
                label: peopleT(locale, 'save'),
                loading: saving,
                onPressed: saving ? null : () => unawaited(save()),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    yearController.dispose();
    notesController.dispose();
  }
}

String _statusLabel(String locale, PersonRelationshipStatus status) =>
    switch (status) {
      PersonRelationshipStatus.important => peopleT(locale, 'status_important'),
      PersonRelationshipStatus.known => peopleT(locale, 'status_known'),
      PersonRelationshipStatus.reference => peopleT(locale, 'status_reference'),
      PersonRelationshipStatus.ignored => peopleT(locale, 'ignored'),
      PersonRelationshipStatus.blocked => peopleT(locale, 'blocked'),
    };

String _reminderLabel(String locale, int days) {
  if (days == 0) return peopleT(locale, 'remind_same_day');
  return peopleTf(locale, 'remind_days_before', days);
}
