part of '../database_service.dart';

extension RecordGhostCleanupExtension on DatabaseService {
  void _pruneRecord404DeadletterUsingCache() {
    if (_recordRestDefinitive404Keys.isEmpty) return;
    final alive = <String>{};
    for (final r in _cachedFlatRecords) {
      final pk = CategoryServiceExtension.recordsTablePk(r).trim();
      final biz = (r['record_id'] ?? '').toString().trim();
      if (pk.isNotEmpty) alive.add(pk);
      if (biz.isNotEmpty) alive.add(biz);
    }
    final before = _recordRestDefinitive404Keys.length;
    _recordRestDefinitive404Keys.removeWhere((k) => alive.contains(k));
    if (before != _recordRestDefinitive404Keys.length) {
      DatabaseService._log(
        'RECORDS_404_DEADLETTER: dropped key(s) that match live server rows again (before=$before after=${_recordRestDefinitive404Keys.length})',
      );
    }
  }
}
