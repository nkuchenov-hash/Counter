// ignore_for_file: avoid_print
part of 'database_service.dart';

/// Thrown when profile fetch returns 404 or 422 (invalid session / UUID mismatch).
class _ProfileFetchFailedException implements Exception {
  _ProfileFetchFailedException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
  @override
  String toString() => message ?? 'Profile fetch failed: $statusCode';
}

/// PocketBase **profiles** auth row id (for PATCH settings); set on profile load.
String? _profilePbRecordId;

bool _profileHydratedFromPb = false;
String? _profileHydrationError;

String _maskEmailForLog(String? raw) {
  final e = raw?.trim() ?? '';
  if (e.isEmpty) return '-';
  final at = e.indexOf('@');
  if (at <= 0) return '***';
  final local = e.substring(0, at);
  final domain = e.substring(at);
  if (local.length <= 1) return '*$domain';
  return '${local[0]}***$domain';
}

String? _authRecordEmail() {
  try {
    final pb = DatabaseService.instance.pocketBase;
    final e = pb.authStore.record?.data['email']?.toString().trim();
    return (e != null && e.isNotEmpty) ? e : null;
  } catch (_) {
    return null;
  }
}

String _dataRegion = 'global';

UserSettings _settings = UserSettings(userId: '');

final StreamController<UserSettings> _settingsController =
    StreamController<UserSettings>.broadcast();

/// Last [fetchTagsForCurrentUser] result (`sort_order` then name). Updated on every fetch; not broadcast.
List<Tag> _userTagsCatalogCache = [];

/// Planning **Sort by Tags** grouping refreshes when tag order changes in Tag Manager (no plan list tick).
final StreamController<void> _tagsCatalogRefreshController =
    StreamController<void>.broadcast();

const String _dataRegionKey = 'data_region';
const String _profileTzLabelKey = 'profile_preferred_timezone';
const String _profileTzOffsetKey = 'profile_timezone_offset_hours';
const String _profileThemeModeKey = 'profile_theme_mode';
const String _profilePrimaryLangKey = 'profile_primary_language';

String? _lastProfileBootLogKey;
DateTime? _lastProfileBootLogAt;
String? _lastProfileHydratedLogKey;
DateTime? _lastProfileHydratedLogAt;
const Duration _profileDiagLogDebounce = Duration(seconds: 8);

extension ProfileServiceExtension on DatabaseService {
  UserSettings get settings => _settings;
  bool get profileHydratedFromPb => _profileHydratedFromPb;
  String? get profileHydrationError => _profileHydrationError;

  static String resolveProfileDisplayLabelFor({UserSettings? settings}) {
    final s = settings ?? _settings;
    final dn = s.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final name = s.accountName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = s.profileEmail?.trim() ?? _authRecordEmail() ?? '';
    if (email.isNotEmpty) {
      if (email.contains('@')) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) return local;
      }
      return email;
    }
    return '';
  }

  String get resolvedProfileDisplayLabel =>
      ProfileServiceExtension.resolveProfileDisplayLabelFor();
}
