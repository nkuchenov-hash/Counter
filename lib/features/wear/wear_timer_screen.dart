import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/app_loading.dart';

String _wearRowSystemId(Map<String, dynamic>? data) {
  if (data == null) return '';
  final rest = (data['backendRestPathId'] ?? '').toString().trim();
  if (rest.isNotEmpty) return rest;
  final id = (data['id'] ?? '').toString().trim();
  if (id.isNotEmpty) return id;
  return '';
}

String _wearFormatElapsed(Duration d) {
  final total = d.inSeconds;
  if (total < 0) return '0:00';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString()}:${s.toString().padLeft(2, '0')}';
}

void _visitWearPickableCategories(CategoryRule r, List<CategoryRule> out) {
  if (r.isArchived) return;
  final id = r.id;
  if (id > 0) out.add(r);
  final ch = r.children;
  if (ch != null) {
    for (final c in ch) {
      _visitWearPickableCategories(c, out);
    }
  }
}

List<CategoryRule> _flattenWearPickableCategories(List<CategoryRule> roots) {
  final out = <CategoryRule>[];
  for (final r in roots) {
    _visitWearPickableCategories(r, out);
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

String _wearCategoryHeadline({
  required Map<String, dynamic>? data,
  required bool running,
  required String locale,
}) {
  if (!running || data == null) {
    return t(locale, 'wear_no_active_task');
  }
  final cid = data['categoryId'] as int?;
  if (cid == null ||
      cid == 0 ||
      cid == CategoryRule.uncategorizedSyntheticId) {
    return t(locale, 'uncategorized');
  }
  final path = DatabaseService.instance.getCategoryPath(cid);
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return t(locale, 'uncategorized');
  }
  return localizeCategoryBreadcrumbPath(trimmed, locale);
}

/// Wear companion: active record stream + category picker on Start.
class WearTimerScreen extends StatefulWidget {
  const WearTimerScreen({super.key});

  @override
  State<WearTimerScreen> createState() => _WearTimerScreenState();
}

class _WearTimerScreenState extends State<WearTimerScreen> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _startWithCategory(int? categoryId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final title = t(currentLocale.value, 'untitled');
      if (categoryId != null) {
        await DatabaseService.instance
            .startTimerWithCategory(title, categoryId: categoryId);
      } else {
        await DatabaseService.instance.startTimer(title);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openCategoryPicker() {
    final locale = currentLocale.value;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StreamBuilder<List<CategoryRule>>(
          stream: DatabaseService.instance.categoryStream,
          initialData: DatabaseService.instance.rules,
          builder: (context, snap) {
            final rules = snap.data ?? const <CategoryRule>[];
            final flat = _flattenWearPickableCategories(rules);
            return AlertDialog(
              title: Text(t(locale, 'wear_choose_category_title')),
              content: SizedBox(
                width: double.maxFinite,
                height: 220,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      title: Text(t(locale, 'wear_start_auto')),
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_startWithCategory(null));
                      },
                    ),
                    const Divider(height: 1),
                    ...flat.map(
                      (r) => ListTile(
                        title: Text(
                          localizeCategoryDbSegment(r.name, locale),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          unawaited(_startWithCategory(r.id));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t(locale, 'cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onStop(Map<String, dynamic>? data) async {
    if (_busy) return;
    final sid = _wearRowSystemId(data);
    setState(() => _busy = true);
    try {
      if (sid.isNotEmpty) {
        await DatabaseService.instance.stopRecord(sid);
      } else {
        await DatabaseService.instance.stopAllRunningRecords();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: DatabaseService.instance.activeRecordStream,
          builder: (context, snap) {
            final data = snap.data;
            final title = (data?['title'] ?? '').toString().trim();
            DateTime? startUtc;
            var running = false;
            if (data != null) {
              final st = data['startTime'] as DateTime?;
              if (st != null &&
                  DatabaseService.isRecordMapActuallyRunning(data)) {
                startUtc = st;
                running = true;
              }
            }
            Duration? elapsed;
            if (startUtc != null) {
              elapsed =
                  DatabaseService.getPlanetaryNow().difference(startUtc);
            }

            final categoryLine = _wearCategoryHeadline(
              data: data,
              running: running,
              locale: locale,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    categoryLine,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (running) ...[
                    const SizedBox(height: 8),
                    Text(
                      t(locale, 'wear_task_label'),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.isNotEmpty ? title : '—',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    running && elapsed != null
                        ? _wearFormatElapsed(elapsed)
                        : '—',
                    style: textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_busy)
                    FilledButton.tonal(
                      onPressed: running
                          ? () => _onStop(data)
                          : _openCategoryPicker,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(168, 52),
                        backgroundColor: running
                            ? scheme.errorContainer
                            : scheme.primaryContainer,
                        foregroundColor: running
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer,
                      ),
                      child: Text(
                        running
                            ? t(locale, 'stop')
                            : t(locale, 'start_timer'),
                      ),
                    )
                  else
                    const SizedBox(
                      height: 52,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: AppLoading(size: AppLoadingSize.small),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
