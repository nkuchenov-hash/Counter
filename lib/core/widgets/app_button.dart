import 'package:flutter/material.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outlined,
  ghost,
  destructive,
}

enum AppButtonSize { s, m, l }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.m,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.fullWidth,
  }) : variant = AppButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool? fullWidth;

  double get _height => switch (size) {
        AppButtonSize.s => 36,
        AppButtonSize.m => 44,
        AppButtonSize.l => 52,
      };

  EdgeInsetsGeometry get _padding => switch (size) {
        AppButtonSize.s => const EdgeInsets.symmetric(horizontal: 12),
        AppButtonSize.m => const EdgeInsets.symmetric(horizontal: 16),
        AppButtonSize.l => const EdgeInsets.symmetric(horizontal: 20),
      };

  double get _iconSize => switch (size) {
        AppButtonSize.s => 16,
        AppButtonSize.m => 18,
        AppButtonSize.l => 20,
      };

  TextStyle? _textStyle(BuildContext context) => switch (size) {
        AppButtonSize.s => Theme.of(context).textTheme.labelMedium,
        AppButtonSize.m => Theme.of(context).textTheme.labelLarge,
        AppButtonSize.l => Theme.of(context).textTheme.titleSmall,
      }
          ?.copyWith(fontWeight: FontWeight.w700);

  ButtonStyle _baseStyle(BuildContext context) => ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, _height)),
        padding: WidgetStatePropertyAll(_padding),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: WidgetStatePropertyAll(_textStyle(context)),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = loading || onPressed == null;
    final stretch = fullWidth ?? expand;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.destructive => scheme.onError,
      AppButtonVariant.secondary ||
      AppButtonVariant.outlined ||
      AppButtonVariant.ghost => scheme.primary,
    };
    final child = loading
        ? SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: _iconSize),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              );
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          style: _baseStyle(context),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          style: _baseStyle(context),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          style: _baseStyle(context),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          style: _baseStyle(context),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.destructive => FilledButton(
          style: _baseStyle(context).merge(
            FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
              disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
    };
    return stretch ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppFormDialogField {
  const AppFormDialogField({
    required this.keyName,
    required this.label,
    this.initialValue = '',
    this.autofocus = false,
    this.keyboardType,
    this.validator,
  });

  final String keyName;
  final String label;
  final String initialValue;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
}

Future<Map<String, String>?> showAppFormDialog({
  required BuildContext context,
  required String title,
  required String cancelLabel,
  required String submitLabel,
  required List<AppFormDialogField> fields,
}) async {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{
    for (final field in fields)
      field.keyName: TextEditingController(text: field.initialValue),
  };
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 620,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  TextFormField(
                    controller: controllers[fields[i].keyName],
                    autofocus: fields[i].autofocus,
                    keyboardType: fields[i].keyboardType,
                    decoration: InputDecoration(labelText: fields[i].label),
                    validator: fields[i].validator,
                  ),
                  if (i != fields.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton.ghost(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppButton.primary(
          label: submitLabel,
          icon: Icons.add_rounded,
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.of(dialogContext).pop({
              for (final field in fields)
                field.keyName: controllers[field.keyName]!.text.trim(),
            });
          },
        ),
      ],
    ),
  );
  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}
