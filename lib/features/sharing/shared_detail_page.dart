import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:counter/data/people/people_service.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/features/sharing/shared_proposal_sheet.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Explicitly opened, on-demand shared discussion. Personal plans and records
/// remain untouched: proposals modify the shared revision only.
class SharedDetailPage extends StatefulWidget {
  const SharedDetailPage({super.key, required this.shareId});
  final String shareId;

  @override
  State<SharedDetailPage> createState() => _SharedDetailPageState();
}

class _SharedDetailPageState extends State<SharedDetailPage> {
  final _service = ShareService.instance;
  final _composer = TextEditingController();
  ShareDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  bool get _ru => currentLocale.value == 'ru';
  String l(String ru, String en) => _ru ? ru : en;
  String get _myId =>
      DatabaseService.instance.pocketBase.authStore.record?.id ?? '';
  bool get _isOwner => _detail?.share.ownerId == _myId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && !_sending && _detail != null) unawaited(_reload(silent: true));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) setState(() {_loading = true; _error = null;});
    try {
      final data = await _service.detail(widget.shareId);
      if (!mounted) return;
      setState(() {_detail = data; _loading = false; _error = null;});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = '$error';
      });
    }
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_sending) return false;
    setState(() => _sending = true);
    try {
      await action();
      await _reload(silent: true);
      return true;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final message = _composer.text.trim();
    if (message.isEmpty) return;
    final success = await _mutate(() => _service.comment(widget.shareId, message));
    if (success && mounted && _composer.text.trim() == message) _composer.clear();
  }

  Future<void> _invite() async {
    List<LifePerson> people;
    try { people = await PeopleService.instance.fetchPeople(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }
    if (!mounted) return;
    final eligible = people.where((p) => p.primaryEmail.trim().isNotEmpty &&
        !p.archived &&
        p.relationshipStatus != PersonRelationshipStatus.ignored &&
        p.relationshipStatus != PersonRelationshipStatus.blocked).toList();
    final personId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l('Пригласить из Людей', 'Invite from People')),
        content: SizedBox(
          width: 380, height: 320,
          child: eligible.isEmpty
              ? Center(child: Text(l('Добавь контакт с email в разделе «Люди».',
                  'Add a contact with email in People first.')))
              : ListView(
                  children: [
                    for (final p in eligible)
                      ListTile(
                        title: Text(p.displayName),
                        subtitle: Text(p.primaryEmail),
                        onTap: () => Navigator.pop(ctx, p.recordId),
                      ),
                  ],
                ),
        ),
      ),
    );
    if (personId == null) return;
    await _mutate(() => _service.inviteFromPeople(
      shareId: widget.shareId, personRecordId: personId,
    ));
  }

  String _clock(String raw) {
    final utc = DateTime.tryParse(raw)?.toUtc();
    if (utc == null) return '';
    final settings = DatabaseService.instance.settings;
    final wall = wall_clock.toWallClockForLabel(utc,
      settings.timezoneOffsetHours, settings.preferredTimeZone);
    return '${wall.hour.toString().padLeft(2, '0')}:'
        '${wall.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _propose(SharedPlanItem item) async {
    final current = _detail;
    if (current == null) return;
    final draft = await showSharedProposalSheet(context,
      item: item, wallDay: current.share.wallDay, ru: _ru);
    if (draft == null || !mounted) return;
    await _mutate(() => _service.propose(
      widget.shareId,
      revision: current.share.revision,
      sourcePlanId: item.planId,
      title: draft.title,
      startTime: draft.startUtc,
      endTime: draft.endUtc,
      comment: draft.comment,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.share.title ?? l('Общий план', 'Shared plan')),
        actions: [
          if (_isOwner)
            IconButton(tooltip: l('Пригласить', 'Invite'),
              onPressed: _sending ? null : () => unawaited(_invite()),
              icon: const Icon(Icons.person_add_alt_1_rounded)),
          IconButton(tooltip: l('Обновить', 'Refresh'),
              onPressed: () => unawaited(_reload()),
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(_error ?? l('Не удалось загрузить', 'Unable to load')))
              : Column(
                  children: [
                    Expanded(child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(l('Совместный черновик · версия ', 'Shared draft · version ')
                            + '${detail.share.revision}',
                          style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        Text(l('Согласование изменяет общий черновик. '
                          'Личные планы участников пока не меняются.',
                          'Decisions update this shared draft only. '
                          'Personal planners are not yet modified.'),
                          style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 16),
                        for (final item in detail.share.items)
                          Card(child: ListTile(
                            title: Text(item.title),
                            subtitle: Text([
                              if (_clock(item.startTime).isNotEmpty)
                                _clock(item.startTime),
                              if (_clock(item.endTime).isNotEmpty)
                                _clock(item.endTime),
                            ].join(' – ')),
                            trailing: IconButton(
                              tooltip: l('Предложить изменение', 'Suggest change'),
                              onPressed: _sending ? null : () => unawaited(_propose(item)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          )),
                        const SizedBox(height: 20),
                        Text(l('Обсуждение', 'Discussion'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final msg in detail.messages)
                          Card(child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg.authorId == _myId
                                    ? l('Вы', 'You')
                                    : l('Участник', 'Participant'),
                                    style: Theme.of(context).textTheme.labelSmall),
                                if (msg.body.isNotEmpty) Text(msg.body),
                                if (msg.kind == 'proposal') ...[
                                  const SizedBox(height: 4),
                                  Text('${l('Предложено', 'Suggested')}: ${msg.patch}'),
                                  Text(msg.status),
                                  if (_isOwner && msg.status == 'pending')
                                    Wrap(spacing: 8, children: [
                                      AppButton.secondary(
                                        label: l('Принять', 'Accept'),
                                        size: AppButtonSize.s,
                                        onPressed: _sending ? null : () => unawaited(
                                          _mutate(() => _service.decide(
                                            widget.shareId, msg.id, accept: true))),
                                      ),
                                      AppButton.ghost(
                                        label: l('Отклонить', 'Reject'),
                                        size: AppButtonSize.s,
                                        onPressed: _sending ? null : () => unawaited(
                                          _mutate(() => _service.decide(
                                            widget.shareId, msg.id, accept: false))),
                                      ),
                                    ]),
                                ],
                              ],
                            ),
                          )),
                      ],
                    )),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(child: TextField(
                            controller: _composer,
                            minLines: 1, maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l('Сообщение к плану', 'Message about this plan'),
                            ),
                          )),
                          IconButton(
                            tooltip: l('Отправить', 'Send'),
                            onPressed: _sending ? null : () => unawaited(_send()),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }
}
