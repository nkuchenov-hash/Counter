part of 'viktor_chat_page.dart';

extension _ViktorThreadsUi on _ViktorChatPageState {
  bool get _compactThreads => MediaQuery.sizeOf(context).width < 900;

  String? _messageDay(ViktorDialogueTurn turn) {
    if (turn.messageDay != null) return turn.messageDay;
    final at = turn.sentAtUtc;
    if (at == null) return null;
    return ViktorDateScope.key(
        DatabaseService.instance.applyUserOffset(at));
  }

  String _messageTime(ViktorDialogueTurn turn) {
    final at = turn.sentAtUtc;
    if (at == null) return '';
    final wall = DatabaseService.instance.applyUserOffset(at);
    final time = '${wall.hour.toString().padLeft(2, '0')}:'
        '${wall.minute.toString().padLeft(2, '0')}';
    final zone = turn.messageTimezone;
    return zone == null ? time : '$time · $zone';
  }

  String _dayHeading(BuildContext context, String dayKey) {
    final date = DateTime.tryParse(dayKey);
    return date == null ? dayKey :
        MaterialLocalizations.of(context).formatMediumDate(date);
  }

  void _showConversation(String id) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    unawaited(_selectConversation(id));
  }

  Widget _buildThreadsPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _dialogueStore.activeConversationId;
    return Material(
      color: scheme.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 10, 10),
          child: Row(children: [
            const Expanded(child: Text('Диалоги', style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 20))),
            IconButton(
              key: const Key('viktor_new_chat'),
              tooltip: 'Новый диалог',
              icon: const Icon(Icons.edit_square),
              onPressed: _busy ? null : () {
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.of(context).pop();
                }
                _startNewConversation();
              },
            ),
          ]),
        ),
        Expanded(child: ListView.builder(
          key: const Key('viktor_thread_list'),
          itemCount: _threads.length,
          itemBuilder: (context, index) {
            final thread = _threads[index];
            final selected = active == thread.id;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 2),
              child: Material(
                color: selected ? scheme.surfaceContainerHigh :
                    Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  key: Key('viktor_thread_${thread.id}'),
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(thread.id == 'main'
                      ? Icons.forum_outlined : Icons.chat_bubble_outline,
                      size: 20),
                  title: Text(thread.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16,
                      fontWeight: selected ?
                          FontWeight.w700 : FontWeight.w400)),
                  onTap: _busy ? null : () => _showConversation(thread.id),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }
}
