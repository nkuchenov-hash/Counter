import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/features/sharing/shared_detail_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Incoming invitations live inside existing People, not a second contact app.
class SharedInboxSection extends StatefulWidget {
  const SharedInboxSection({super.key});
  @override
  State<SharedInboxSection> createState() => _SharedInboxSectionState();
}

class _SharedInboxSectionState extends State<SharedInboxSection> {
  List<SharedObject> _shares = const [];
  bool _loading = true;
  String? _error;
  String? _pendingId;

  bool get _ru => currentLocale.value == 'ru';
  String l(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {_loading = true; _error = null;});
    try {
      final shares = await ShareService.instance.list();
      if (mounted) setState(() {_shares = shares; _loading = false;});
    } catch (error) {
      if (mounted) setState(() {_error = '$error'; _loading = false;});
    }
  }

  Future<void> _answer(SharedObject share, bool accept) async {
    setState(() => _pendingId = share.id);
    try {
      await ShareService.instance.respond(share.id, accept: accept);
      if (!mounted) return;
      setState(() {
        _shares = _shares.map((s) => s.id == share.id
            ? SharedObject(
                id: s.id, title: s.title, ownerId: s.ownerId,
                wallDay: s.wallDay, revision: s.revision,
                status: accept ? 'accepted' : 'declined', items: s.items,
              ) : s).toList();
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _pendingId = null);
    }
  }

  Future<void> _open(SharedObject share) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SharedDetailPage(shareId: share.id),
    ));
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _shares.isEmpty) return const Center(
      child: Padding(padding: EdgeInsets.all(32),
        child: CircularProgressIndicator()),
    );
    if (_error != null && _shares.isEmpty) {
      return Column(children: [
        Text(_error!),
        AppButton.secondary(
          label: l('Повторить', 'Retry'), onPressed: () => unawaited(_refresh())),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(l('Общие планы и приглашения', 'Shares and invitations'),
              style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: l('Обновить', 'Refresh'),
            onPressed: _loading ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        const SizedBox(height: 8),
        if (_shares.isEmpty)
          Text(l('Пока никто не поделился с тобой планом.',
              'No shared plans yet.'))
        else
          for (final share in _shares)
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(share.title,
                    style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('${share.wallDay} · ${share.status}',
                    style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  if (share.status == 'invited')
                    Wrap(spacing: 8, children: [
                      AppButton.primary(
                        label: l('Принять', 'Accept'),
                        size: AppButtonSize.s,
                        onPressed: _pendingId != null ? null :
                            () => unawaited(_answer(share, true))),
                      AppButton.secondary(
                        label: l('Отклонить', 'Decline'),
                        size: AppButtonSize.s,
                        onPressed: _pendingId != null ? null :
                            () => unawaited(_answer(share, false))),
                    ])
                  else if (share.status == 'accepted' || share.status == 'owner')
                    AppButton.secondary(
                      label: l('Открыть', 'Open'),
                      size: AppButtonSize.s,
                      onPressed: () => unawaited(_open(share))),
                ],
              ),
            )),
      ],
    );
  }
}
