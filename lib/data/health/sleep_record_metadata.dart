import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';

extension SleepRecordMetadataExtension on DatabaseService {
  Future<bool> writeSleepRecordMetadata({
    required String recordKey,
    required String source,
    required String externalId,
    required String sourceName,
    required List<Map<String, dynamic>> stages,
    bool recoveredFromSegments = false,
  }) async {
    final key = recordKey.trim();
    if (key.isEmpty) return false;
    try {
      await ensurePocketBaseReady();
      var pocketRowId = key;
      if (pocketRowId.length != 15) {
        final rows = await fetchRecords(forceNetwork: true);
        for (final row in rows) {
          final businessId = (row['record_id'] ?? '').toString().trim();
          if (businessId != key) continue;
          final candidate =
              (row['_pb_record_id'] ?? row['id'] ?? '').toString().trim();
          if (candidate.isNotEmpty) pocketRowId = candidate;
          break;
        }
      }
      if (pocketRowId.isEmpty) return false;
      await pocketBase.collection(PbCollections.records).update(
        pocketRowId,
        body: <String, dynamic>{
          'external_source': source,
          'external_id': externalId,
          'external_kind': 'sleep',
          'sleep_source': source,
          'sleep_external_id': externalId,
          'sleep_source_name': sourceName,
          'sleep_stages': stages,
          'sleep_recovered_from_segments': recoveredFromSegments,
          'sleep_segment_points': stages.length,
        },
      );
      await fetchRecords(forceNetwork: true);
      return true;
    } catch (_) {
      // Metadata enrichment must never make the base sleep interval disappear.
      // A later foreground/background sync retries after migrations are present.
      return false;
    }
  }
}
