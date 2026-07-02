import 'package:url_launcher/url_launcher.dart';Future<void> launchUrlFromQuillEditor(String raw) async {
  final u = Uri.tryParse(raw.trim());
  if (u == null || !u.hasScheme) return;
  try {
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}
