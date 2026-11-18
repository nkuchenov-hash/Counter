import 'package:counter/core/widgets/app_glass_edge_fade.dart';
import 'package:flutter/material.dart';

/// Back navigation for secondary Settings routes. The parent label is
/// actionable; the current section title stays visible below it.
class AppSettingsBreadcrumbBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppSettingsBreadcrumbBar({
    super.key,
    required this.parentLabel,
    required this.title,
    required this.onBack,
    this.actions,
    this.bottom,
  });

  final String parentLabel;
  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(86 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 86,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      flexibleSpace: AppGlassEdgeFade(
        edge: AppGlassEdge.top,
        surfaceColor: scheme.surfaceContainerLowest,
        blurSigma: 16,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: Text(parentLabel, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.padded,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
