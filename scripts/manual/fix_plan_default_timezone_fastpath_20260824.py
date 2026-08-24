#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'lib/data/categories/category_default_time.dart'
text = path.read_text(encoding='utf-8')

anchor = """  static bool isDefaultPlanTimezoneFieldMissingError(String? detail) {
    final d = detail?.toLowerCase() ?? '';
    return d.contains('default_plan_timezone');
  }

"""
helper = """  static bool isDefaultPlanTimezoneFieldMissingError(String? detail) {
    final d = detail?.toLowerCase() ?? '';
    return d.contains('default_plan_timezone');
  }

  /// Narrow PATCH for category default scheduling fields.
  /// These settings affect future plan creation only, so do not refetch the
  /// entire category tree after changing one row.
  Future<({bool ok, String? errorDetail})> _patchDefaultPlanScheduleDelta(
    int categoryId,
    Map<String, dynamic> fields,
  ) async {
    if (!_isInitialized || !(currentProfileId?.isNotEmpty ?? false)) {
      return (ok: false, errorDetail: 'not_initialized');
    }
    final existing = getCategoryRuleById(categoryId);
    if (existing == null) {
      return (ok: false, errorDetail: 'category_not_found');
    }
    final pbId = (existing.backendRowId ?? '').trim();
    if (!DatabaseService._isLikelyPocketBaseRowId(pbId)) {
      return (ok: false, errorDetail: 'missing_backend_row_id');
    }

    final body = <String, dynamic>{
      'user_id': _pidForPbFilter,
      'order': existing.order,
      ...fields,
    };
    try {
      await ensurePocketBaseReady();
      await _pb.collection(PbCollections.categories).update(pbId, body: body);

      if (fields.containsKey('default_plan_time')) {
        existing.defaultPlanTime = sanitizeDefaultPlanTime(
          fields['default_plan_time'],
        );
      }
      if (fields.containsKey('default_plan_timezone')) {
        existing.defaultPlanTimezone = sanitizeDefaultPlanTimezone(
          fields['default_plan_timezone'],
        );
      }
      _categoryController.add(List<CategoryRule>.from(_rules));
      return (ok: true, errorDetail: null);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        _emitCategorySyncNotice('category_sync_not_found');
      }
      return (ok: false, errorDetail: e.toString());
    } catch (e) {
      DatabaseService._log('PATCH_CATEGORY_DEFAULT_PLAN_SCHEDULE: $e');
      return (ok: false, errorDetail: e.toString());
    }
  }

"""
if helper not in text:
    if text.count(anchor) != 1:
        raise SystemExit('category_default_time.dart: helper anchor mismatch')
    text = text.replace(anchor, helper, 1)

old = 'final clear = await patchCategoryDelta(categoryId, clearFields);'
new = 'final clear = await _patchDefaultPlanScheduleDelta(categoryId, clearFields);'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('category_default_time.dart: clear patch call mismatch')

old = 'final result = await patchCategoryDelta(categoryId, fields);'
new = 'final result = await _patchDefaultPlanScheduleDelta(categoryId, fields);'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('category_default_time.dart: save patch call mismatch')

path.write_text(text, encoding='utf-8')
print('Applied category default-time targeted PATCH fast path.')
