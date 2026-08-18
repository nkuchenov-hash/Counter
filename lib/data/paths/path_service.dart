part of '../database_service.dart';

Map<String, dynamic> _pathRecordData(RecordModel record) => <String, dynamic>{
      'id': record.id,
      ...record.data,
    };

extension PathServiceExtension on DatabaseService {
  String _pathOwnerIdOrThrow() {
    final ownerId = _pb.authStore.record?.id.trim() ?? '';
    if (ownerId.isEmpty) throw AuthenticatedUserIdRequiredException();
    return ownerId;
  }

  Future<List<Map<String, dynamic>>> fetchOwnedPathRows() async {
    await ensurePocketBaseReady();
    final ownerId = _pathOwnerIdOrThrow();
    final records = await _pb.collection(PbCollections.paths).getFullList(
          filter: 'user_id = "${_escapeForPbFilter(ownerId)}" && archived = false',
          sort: 'category_link,path_id',
        );
    return records.map(_pathRecordData).toList(growable: false);
  }

  Future<Map<String, dynamic>?> fetchOwnedPathRowByBusinessId(
    String pathId,
  ) async {
    await ensurePocketBaseReady();
    final ownerId = _pathOwnerIdOrThrow();
    final cleanPathId = pathId.trim();
    if (cleanPathId.isEmpty) return null;
    try {
      final record = await _pb.collection(PbCollections.paths).getFirstListItem(
            'user_id = "${_escapeForPbFilter(ownerId)}" && '
            'path_id = "${_escapeForPbFilter(cleanPathId)}"',
          );
      return _pathRecordData(record);
    } on ClientException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchOwnedPathRevisionRow({
    required String pathId,
    required String revisionRecordId,
  }) async {
    await ensurePocketBaseReady();
    final ownerId = _pathOwnerIdOrThrow();
    final cleanPathId = pathId.trim();
    final cleanRevisionRecordId = revisionRecordId.trim();
    if (cleanPathId.isEmpty || cleanRevisionRecordId.isEmpty) return null;
    try {
      final record = await _pb
          .collection(PbCollections.pathRevisions)
          .getFirstListItem(
            'id = "${_escapeForPbFilter(cleanRevisionRecordId)}" && '
            'user_id = "${_escapeForPbFilter(ownerId)}" && '
            'path_id = "${_escapeForPbFilter(cleanPathId)}"',
          );
      return _pathRecordData(record);
    } on ClientException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOwnedPath({
    required String pathId,
    required String categoryPocketBaseId,
    required String title,
    required String activeRevisionRecordId,
  }) async {
    await ensurePocketBaseReady();
    final ownerId = _pathOwnerIdOrThrow();
    final categoryId = categoryPocketBaseId.trim();
    final revisionId = activeRevisionRecordId.trim();
    if (!DatabaseService._isLikelyPocketBaseRowId(categoryId)) {
      throw ArgumentError.value(
        categoryPocketBaseId,
        'categoryPocketBaseId',
        'Expected a PocketBase categories row id.',
      );
    }
    if (!DatabaseService._isLikelyPocketBaseRowId(revisionId)) {
      throw ArgumentError.value(
        activeRevisionRecordId,
        'activeRevisionRecordId',
        'Expected a PocketBase path_revisions row id.',
      );
    }
    final record = await _pb.collection(PbCollections.paths).create(
      body: <String, dynamic>{
        'user_id': ownerId,
        'path_id': pathId.trim(),
        'category_link': categoryId,
        'title': title.trim(),
        'active_revision_link': revisionId,
        'archived': false,
      },
    );
    return _pathRecordData(record);
  }

  Future<Map<String, dynamic>> createOwnedPathRevision({
    required String pathId,
    required String revisionId,
    required int version,
    required String lifecycle,
    required String goal,
    required List<Map<String, dynamic>> stages,
    required String source,
    String? parentRevisionId,
  }) async {
    await ensurePocketBaseReady();
    final ownerId = _pathOwnerIdOrThrow();
    final record = await _pb.collection(PbCollections.pathRevisions).create(
      body: <String, dynamic>{
        'user_id': ownerId,
        'path_id': pathId.trim(),
        'revision_id': revisionId.trim(),
        'version': version,
        'lifecycle': lifecycle,
        'goal': goal.trim(),
        'content': <String, dynamic>{'stages': stages},
        'source': source,
        'parent_revision_id': parentRevisionId?.trim() ?? '',
      },
    );
    return _pathRecordData(record);
  }

  Future<void> setOwnedPathActiveRevision({
    required String pathRecordId,
    required String revisionRecordId,
    required String title,
  }) async {
    await ensurePocketBaseReady();
    _pathOwnerIdOrThrow();
    final revisionId = revisionRecordId.trim();
    if (!DatabaseService._isLikelyPocketBaseRowId(revisionId)) {
      throw ArgumentError.value(
        revisionRecordId,
        'revisionRecordId',
        'Expected a PocketBase path_revisions row id.',
      );
    }
    await _pb.collection(PbCollections.paths).update(
      pathRecordId.trim(),
      body: <String, dynamic>{
        'active_revision_link': revisionId,
        'title': title.trim(),
      },
    );
  }

  Future<void> deleteOwnedPathRevision(String revisionRecordId) async {
    await ensurePocketBaseReady();
    _pathOwnerIdOrThrow();
    final id = revisionRecordId.trim();
    if (id.isEmpty) return;
    await _pb.collection(PbCollections.pathRevisions).delete(id);
  }
}
