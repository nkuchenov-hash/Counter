import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/people/people_device_contacts_bridge.dart';
import 'package:counter/data/people/people_integration_service.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/features/settings/people/people_avatar.dart';
import 'package:counter/features/settings/people/people_strings.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class PeopleSourcesSection extends StatefulWidget {
  const PeopleSourcesSection({
    super.key,
    required this.locale,
    required this.people,
    required this.onPersonLinked,
  });

  final String locale;
  final List<LifePerson> people;
  final ValueChanged<LifePerson> onPersonLinked;

  @override
  State<PeopleSourcesSection> createState() => _PeopleSourcesSectionState();
}

class _PeopleSourcesSectionState extends State<PeopleSourcesSection> {
  final PeopleService _service = PeopleService.instance;
  final PeopleIntegrationService _integrations = PeopleIntegrationService.instance;

  List<PeopleSourceStats> _stats = const <PeopleSourceStats>[];
  List<PeopleSourceContact> _contacts = const <PeopleSourceContact>[];
  PeopleSourceProvider? _selectedProvider;
  bool _loading = true;
  bool _contactsLoading = false;
  bool _showSuppressed = false;
  PeopleSourceProvider? _actionProvider;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await Future.wait<void>([
        _integrations.loadStatus(),
        _refreshStats(rebuild: false),
      ]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _refreshStats({bool rebuild = true}) async {
    final stats = await _service.fetchSourceStats();
    if (!mounted) return;
    if (rebuild) {
      setState(() => _stats = stats);
    } else {
      _stats = stats;
    }
  }

  Future<void> _selectProvider(PeopleSourceProvider provider) async {
    setState(() {
      _selectedProvider = provider;
      _contactsLoading = true;
      _contacts = const <PeopleSourceContact>[];
      _error = null;
    });
    await _loadSelectedContacts();
  }

  Future<void> _loadSelectedContacts() async {
    final provider = _selectedProvider;
    if (provider == null) return;
    try {
      final states = <PeopleSourceImportState>{
        PeopleSourceImportState.candidate,
        PeopleSourceImportState.linked,
        if (_showSuppressed) PeopleSourceImportState.ignored,
        if (_showSuppressed) PeopleSourceImportState.blocked,
      };
      final contacts = await _service.fetchSourceContacts(provider, states: states);
      if (!mounted || _selectedProvider != provider) return;
      setState(() {
        _contacts = contacts;
        _contactsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _syncDevice() async {
    final provider = PeopleSourceProvider.deviceContacts;
    setState(() {
      _actionProvider = provider;
      _error = null;
    });
    try {
      await _service.syncDeviceContacts();
      await _refreshStats();
      if (_selectedProvider == provider) await _loadSelectedContacts();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _actionProvider = null);
    }
  }

  Future<void> _importTelegram() async {
    final provider = PeopleSourceProvider.telegram;
    setState(() {
      _actionProvider = provider;
      _error = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Telegram JSON export',
            extensions: <String>['json'],
            mimeTypes: <String>['application/json'],
          ),
        ],
      );
      if (file == null) return;
      await _service.importTelegramExport(await file.readAsString());
      await _refreshStats();
      if (_selectedProvider == provider) await _loadSelectedContacts();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _actionProvider = null);
    }
  }

  Future<void> _connect(PeopleSourceProvider provider) async {
    setState(() => _actionProvider = provider);
    await _integrations.connect(provider);
    if (mounted) setState(() => _actionProvider = null);
  }

  Future<void> _syncCloud(PeopleSourceProvider provider) async {
    setState(() {
      _actionProvider = provider;
      _error = null;
    });
    final ok = await _integrations.syncNow(provider);
    if (ok) {
      await _refreshStats();
      if (_selectedProvider == provider) await _loadSelectedContacts();
    }
    if (mounted) setState(() => _actionProvider = null);
  }

  Future<void> _disconnect(PeopleSourceProvider provider) async {
    setState(() => _actionProvider = provider);
    await _integrations.disconnect(provider);
    if (mounted) setState(() => _actionProvider = null);
  }

  Future<void> _setStateFor(
    PeopleSourceContact contact,
    PeopleSourceImportState state,
  ) async {
    try {
      await _service.setSourceState(contact, state);
      await _refreshStats();
      await _loadSelectedContacts();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _addAsPerson(PeopleSourceContact contact) async {
    try {
      final person = await _service.linkSourceContact(contact);
      widget.onPersonLinked(person);
      await _refreshStats();
      await _loadSelectedContacts();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _linkToExisting(PeopleSourceContact contact) async {
    final candidates = widget.people
        .where((person) =>
            !person.archived &&
            person.relationshipStatus != PersonRelationshipStatus.ignored &&
            person.relationshipStatus != PersonRelationshipStatus.blocked)
        .toList(growable: false);
    if (candidates.isEmpty) {
      await _addAsPerson(contact);
      return;
    }
    final selected = await showDialog<LifePerson>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(peopleT(widget.locale, 'link_to_person')),
        content: SizedBox(
          width: 440,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final person = candidates[index];
              return ListTile(
                leading: PeopleAvatar(
                  name: person.displayName,
                  imageUrl: person.avatarUrl,
                  radius: 20,
                ),
                title: Text(person.displayName),
                subtitle: person.primaryPhone.isNotEmpty
                    ? Text(person.primaryPhone)
                    : (person.primaryEmail.isNotEmpty
                        ? Text(person.primaryEmail)
                        : null),
                onTap: () => Navigator.of(dialogContext).pop(person),
              );
            },
          ),
        ),
        actions: [
          AppButton.ghost(
            label: peopleT(widget.locale, 'cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      final person = await _service.linkSourceContact(
        contact,
        existingPerson: selected,
      );
      widget.onPersonLinked(person);
      await _refreshStats();
      await _loadSelectedContacts();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: AppLoading(),
      );
    }
    final statsByProvider = <PeopleSourceProvider, PeopleSourceStats>{
      for (final stat in _stats) stat.provider: stat,
    };
    return ValueListenableBuilder<PeopleIntegrationState>(
      valueListenable: _integrations.state,
      builder: (context, integrationState, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSettingsSectionCard(
              title: peopleT(widget.locale, 'source_rule_title'),
              child: Text(
                peopleT(widget.locale, 'source_rule_body'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ),
            if (_error != null || integrationState.error != null) ...[
              _ErrorCard(
                text: _sourceErrorText(
                  _error ?? integrationState.error ?? '',
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppSettingsCardGrid(
              children: [
                for (final provider in const <PeopleSourceProvider>[
                  PeopleSourceProvider.deviceContacts,
                  PeopleSourceProvider.googleContacts,
                  PeopleSourceProvider.microsoft,
                  PeopleSourceProvider.vk,
                  PeopleSourceProvider.telegram,
                  PeopleSourceProvider.facebook,
                ])
                  _buildProviderCard(
                    context,
                    provider,
                    statsByProvider[provider],
                    integrationState.connectionFor(provider),
                  ),
              ],
            ),
            if (_selectedProvider != null) ...[
              const SizedBox(height: 20),
              _buildReview(context, _selectedProvider!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    PeopleSourceProvider provider,
    PeopleSourceStats? stats,
    PeopleIntegrationConnection? connection,
  ) {
    final busy = _actionProvider == provider;
    final selected = _selectedProvider == provider;
    final deviceSupported = PeopleDeviceContactsBridge.instance.supported;
    final cloud = provider.usesServerOAuth;
    final connected = connection?.configured == true;
    final serverConfigured = connection?.serverConfigured == true;
    return AppSettingsGridCard(
      leading: Icon(_providerIcon(provider), size: 24),
      title: _providerLabel(provider),
      subtitle: _providerSubtitle(provider, stats, connection),
      trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats != null && stats.total > 0)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(peopleTf(widget.locale, 'source_candidates', stats.candidates)),
                Text(peopleTf(widget.locale, 'source_linked', stats.linked)),
                if (stats.ignored > 0)
                  Text(peopleTf(widget.locale, 'source_ignored', stats.ignored)),
                if (stats.blocked > 0)
                  Text(peopleTf(widget.locale, 'source_blocked', stats.blocked)),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (provider == PeopleSourceProvider.deviceContacts)
                AppButton.secondary(
                  label: deviceSupported
                      ? peopleT(widget.locale, 'sync')
                      : peopleT(widget.locale, 'mobile_only'),
                  icon: Icons.sync_rounded,
                  loading: busy,
                  size: AppButtonSize.s,
                  onPressed: busy || !deviceSupported
                      ? null
                      : () => unawaited(_syncDevice()),
                )
              else if (provider == PeopleSourceProvider.telegram)
                AppButton.secondary(
                  label: peopleT(widget.locale, 'import_export'),
                  icon: Icons.upload_file_rounded,
                  loading: busy,
                  size: AppButtonSize.s,
                  onPressed: busy ? null : () => unawaited(_importTelegram()),
                )
              else if (cloud && !connected)
                AppButton.secondary(
                  label: serverConfigured
                      ? peopleT(widget.locale, 'connect')
                      : peopleT(widget.locale, 'not_configured'),
                  icon: Icons.link_rounded,
                  loading: busy,
                  size: AppButtonSize.s,
                  onPressed: busy || !serverConfigured
                      ? null
                      : () => unawaited(_connect(provider)),
                )
              else if (cloud && connected) ...[
                AppButton.secondary(
                  label: peopleT(widget.locale, 'sync'),
                  icon: Icons.sync_rounded,
                  loading: busy,
                  size: AppButtonSize.s,
                  onPressed: busy ? null : () => unawaited(_syncCloud(provider)),
                ),
                AppButton.ghost(
                  label: peopleT(widget.locale, 'disconnect'),
                  size: AppButtonSize.s,
                  onPressed: busy ? null : () => unawaited(_disconnect(provider)),
                ),
              ],
              if ((stats?.total ?? 0) > 0)
                AppButton.outlined(
                  label: selected
                      ? peopleT(widget.locale, 'reviewing')
                      : peopleT(widget.locale, 'review'),
                  icon: Icons.manage_accounts_rounded,
                  size: AppButtonSize.s,
                  onPressed: selected ? null : () => unawaited(_selectProvider(provider)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context, PeopleSourceProvider provider) {
    return AppSettingsSectionCard(
      title: '${peopleT(widget.locale, 'review')} — ${_providerLabel(provider)}',
      subtitle: peopleT(widget.locale, 'review_hint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(peopleT(widget.locale, 'show_suppressed')),
                  value: _showSuppressed,
                  onChanged: (value) {
                    setState(() {
                      _showSuppressed = value;
                      _contactsLoading = true;
                    });
                    unawaited(_loadSelectedContacts());
                  },
                ),
              ),
              AppButton.ghost(
                label: peopleT(widget.locale, 'close'),
                onPressed: () => setState(() {
                  _selectedProvider = null;
                  _contacts = const <PeopleSourceContact>[];
                }),
              ),
            ],
          ),
          const Divider(),
          if (_contactsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: AppLoading(),
            )
          else if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(peopleT(widget.locale, 'nothing_to_review')),
            )
          else
            for (final contact in _contacts) _buildSourceContact(context, contact),
        ],
      ),
    );
  }

  Widget _buildSourceContact(
    BuildContext context,
    PeopleSourceContact contact,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final suppressed = contact.importState == PeopleSourceImportState.ignored ||
        contact.importState == PeopleSourceImportState.blocked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PeopleAvatar(
            name: contact.displayName,
            imageUrl: contact.avatarUrl,
            dataUri: contact.avatarDataUri,
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (contact.primaryPhone.isNotEmpty)
                  Text(contact.primaryPhone, style: Theme.of(context).textTheme.bodySmall),
                if (contact.primaryEmail.isNotEmpty)
                  Text(contact.primaryEmail, style: Theme.of(context).textTheme.bodySmall),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      _stateLabel(contact.importState),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: suppressed ? scheme.outline : scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (contact.hasBirthday)
                      Text(_sourceBirthday(contact), style: Theme.of(context).textTheme.labelSmall),
                    if (contact.sourceGroup.isNotEmpty)
                      Text(contact.sourceGroup, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (contact.importState == PeopleSourceImportState.candidate)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                AppButton.primary(
                  label: peopleT(widget.locale, 'add'),
                  size: AppButtonSize.s,
                  onPressed: () => unawaited(_addAsPerson(contact)),
                ),
                AppButton.outlined(
                  label: peopleT(widget.locale, 'link'),
                  size: AppButtonSize.s,
                  onPressed: () => unawaited(_linkToExisting(contact)),
                ),
                AppButton.ghost(
                  label: peopleT(widget.locale, 'ignore'),
                  size: AppButtonSize.s,
                  onPressed: () => unawaited(
                    _setStateFor(contact, PeopleSourceImportState.ignored),
                  ),
                ),
                AppButton.ghost(
                  label: peopleT(widget.locale, 'block'),
                  size: AppButtonSize.s,
                  onPressed: () => unawaited(
                    _setStateFor(contact, PeopleSourceImportState.blocked),
                  ),
                ),
              ],
            )
          else if (suppressed)
            AppButton.outlined(
              label: peopleT(widget.locale, 'restore_to_review'),
              size: AppButtonSize.s,
              onPressed: () => unawaited(
                _setStateFor(contact, PeopleSourceImportState.candidate),
              ),
            )
          else
            Text(
              peopleT(widget.locale, 'linked'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  String _providerSubtitle(
    PeopleSourceProvider provider,
    PeopleSourceStats? stats,
    PeopleIntegrationConnection? connection,
  ) {
    if (stats != null && stats.total > 0) {
      return peopleTf(widget.locale, 'source_total', stats.total);
    }
    if (provider.usesServerOAuth) {
      if (connection?.configured == true) {
        final label = connection?.accountLabel?.trim() ?? '';
        return label.isNotEmpty ? label : peopleT(widget.locale, 'connected');
      }
      if (connection?.serverConfigured != true) {
        return peopleT(widget.locale, 'server_credentials_needed');
      }
    }
    if (provider == PeopleSourceProvider.telegram) {
      return peopleT(widget.locale, 'telegram_export_hint');
    }
    return peopleT(widget.locale, 'source_none');
  }

  String _sourceErrorText(String raw) {
    if (raw.contains('permission_denied')) {
      return peopleT(widget.locale, 'contacts_permission_denied');
    }
    if (raw.contains('telegram_export_invalid_json') ||
        raw.contains('telegram_export_no_contacts')) {
      return peopleT(widget.locale, 'telegram_export_invalid');
    }
    if (raw.contains('server_people_integrations_not_deployed')) {
      return peopleT(widget.locale, 'server_not_deployed');
    }
    return raw;
  }

  String _providerLabel(PeopleSourceProvider provider) => switch (provider) {
        PeopleSourceProvider.deviceContacts => peopleT(widget.locale, 'source_device'),
        PeopleSourceProvider.googleContacts => peopleT(widget.locale, 'source_google'),
        PeopleSourceProvider.microsoft => peopleT(widget.locale, 'source_microsoft'),
        PeopleSourceProvider.vk => peopleT(widget.locale, 'source_vk'),
        PeopleSourceProvider.telegram => peopleT(widget.locale, 'source_telegram'),
        PeopleSourceProvider.facebook => peopleT(widget.locale, 'source_facebook'),
        PeopleSourceProvider.manual => peopleT(widget.locale, 'tab_people'),
      };

  IconData _providerIcon(PeopleSourceProvider provider) => switch (provider) {
        PeopleSourceProvider.deviceContacts => Icons.contacts_rounded,
        PeopleSourceProvider.googleContacts => Icons.account_circle_rounded,
        PeopleSourceProvider.microsoft => Icons.business_center_rounded,
        PeopleSourceProvider.vk => Icons.people_outline_rounded,
        PeopleSourceProvider.telegram => Icons.send_rounded,
        PeopleSourceProvider.facebook => Icons.public_rounded,
        PeopleSourceProvider.manual => Icons.person_rounded,
      };

  String _stateLabel(PeopleSourceImportState state) => switch (state) {
        PeopleSourceImportState.unknown => peopleT(widget.locale, 'unknown'),
        PeopleSourceImportState.candidate => peopleT(widget.locale, 'to_review'),
        PeopleSourceImportState.linked => peopleT(widget.locale, 'linked'),
        PeopleSourceImportState.ignored => peopleT(widget.locale, 'ignored'),
        PeopleSourceImportState.blocked => peopleT(widget.locale, 'blocked'),
      };

  String _sourceBirthday(PeopleSourceContact contact) {
    final day = contact.birthdayDay;
    final month = contact.birthdayMonth;
    if (day == null || month == null) return '';
    final year = contact.birthdayYear;
    if (widget.locale.toLowerCase().startsWith('ru')) {
      return year == null
          ? '$day.${month.toString().padLeft(2, '0')}'
          : '$day.${month.toString().padLeft(2, '0')}.$year';
    }
    return year == null ? '$month/$day' : '$month/$day/$year';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
