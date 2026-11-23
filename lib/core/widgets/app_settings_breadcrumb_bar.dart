import 'package:counter/core/widgets/app_glass_edge_fade.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:flutter/material.dart';

/// A single-line Settings header: approved frosted circular back action and title.
/// The parent name is an accessibility/tooltip label, not a visible extra row.
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
      Size.fromHeight(72 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop = shellUsesSideNavigation(MediaQuery.sizeOf(context).width);
    // The approved 48dp frosted back control, with no extra breadcrumb row.
    final header = Row(
      children: [
        AppIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: parentLabel,
          onPressed: onBack,
          variant: AppIconButtonVariant.frosted,
          shape: AppIconButtonShape.circular,
          size: AppIconButtonSize.l,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return AppBar(
      toolbarHeight: 72,
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
