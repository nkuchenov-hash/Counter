import 'package:counter/core/widgets/app_glass_edge_fade.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
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
    this.alignWithSettingsBody = false,
  });

  final String parentLabel;
  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool alignWithSettingsBody;

  @override
  Size get preferredSize =>
      Size.fromHeight(86 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          label: Text(
            parentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return AppBar(
      toolbarHeight: 86,
      titleSpacing: alignWithSettingsBody ? 0 : 16,
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
      title: alignWithSettingsBody
          ? Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: settingsContentMaxWidth(context),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop
                          ? kShellDesktopContentHorizontalPadding
                          : 16,
                    ),
                    child: header,
                  ),
                ),
              ),
            )
          : header,
      actions: actions,
      bottom: bottom,
    );
  }
}
