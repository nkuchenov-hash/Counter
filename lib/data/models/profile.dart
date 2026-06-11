// Part of lib/data/models.dart — Profile, UserProfile, ProfileUpdate, UserSettings, TagCatalogScope.
// Split per ROADMAP Tier 4.2 (April 2026).
part of '../models.dart';

String tagDisplayModeWireForPatch(UserSettings s) {
  if (s.tagDisplayMode == CategoryDisplayMode.letterChip) {
    return 'text chip';
  }
  final raw = s.tagDisplayModeWireRaw?.trim();
  if (raw != null &&
      raw.isNotEmpty &&
      categoryDisplayModeFromWire(raw) == s.tagDisplayMode) {
    return raw;
  }
  return s.tagDisplayMode.wireValue;
}

// ---------------------------------------------------------------------------
// DATA DNA — VAULT: lib/data/models.dart (@ARCHITECTURE.md §1, @DATA_MAP.md).
// Pure classes and serialization. No database imports.
// PKs: PocketBase row `id` (string) for REST; `record_id` on records is legacy UUID / passive metadata only.
// Other: `category_id` / `plan_id` where applicable; profiles → user_id (String).
// ---------------------------------------------------------------------------

class Profile {
  const Profile({
    required this.id,
    required this.userId,
    this.email,
    this.password,
    this.primaryLanguage,
    this.preferredTimezone,
    this.timezoneOffsetHours,
    this.defaultCategoryId,
    this.biometricEnabled,
  });

  final int id;
  final int userId;
  final String? email;
  final String? password;
  final String? primaryLanguage;
  final String? preferredTimezone;
  final int? timezoneOffsetHours;
  final int? defaultCategoryId;
  final bool? biometricEnabled;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: _jsonInt(json['id']),
    userId: _jsonInt(json['user_id']),
    email: json['email']?.toString(),
    password: json['password']?.toString(),
    primaryLanguage:
        json['primary_language']?.toString() ??
        json['primaryLanguage']?.toString(),
    preferredTimezone:
        json['preferred_timezone']?.toString() ??
        json['preferredTimeZone']?.toString(),
    timezoneOffsetHours: json['timezone_offset'] is int
        ? json['timezone_offset'] as int
        : int.tryParse(json['timezone_offset']?.toString() ?? ''),
    defaultCategoryId: json['default_category_id'] == null
        ? null
        : _jsonInt(json['default_category_id']),
    biometricEnabled:
        json['biometric_enabled'] as bool? ?? json['biometricEnabled'] as bool?,
  );
}

/// NocoDB user profile. Unique user identifier is always user_id in DB and code.
class UserProfile {
  UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.primaryLanguage,
    this.themeMode,
    this.preferredTimezone,
    this.timezoneOffset,
    this.biometricEnabled = false,
    this.updatedAt,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? primaryLanguage;
  final String? themeMode;
  final String? preferredTimezone;
  final double? timezoneOffset;
  final bool biometricEnabled;
  final String? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      email: json['email']?.toString(),
      displayName: json['display_name']?.toString() ?? json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      primaryLanguage: json['primary_language']?.toString() ?? 'ru',
      themeMode: json['theme_mode']?.toString() ?? 'system',
      preferredTimezone: json['preferred_timezone']?.toString(),
      timezoneOffset: (json['timezone_offset'] as num?)?.toDouble(),
      biometricEnabled:
          json['biometric_enabled'] == true ||
          json['biometric_enabled'] == 'true',
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class ProfileUpdate {
  ProfileUpdate.fromSettings(UserSettings s)
    : preferredTimeZone = s.preferredTimeZone,
      timezoneOffsetHours = s.timezoneOffsetHours,
      themeMode = s.themeMode,
      displayName = s.displayName,
      primaryLanguage = s.primaryLanguage.isNotEmpty
          ? s.primaryLanguage
          : s.language,
      tagDisplayMode = tagDisplayModeWireForPatch(s),
      listCompletionBehavior = listCompletionBehaviorWireForPatch(s);
  final String preferredTimeZone;
  final int timezoneOffsetHours;
  final String themeMode;
  final String? displayName;
  final String primaryLanguage;
  final String tagDisplayMode;

  /// PocketBase `profiles.list_completion_behavior` (@DATA_MAP).
  final String listCompletionBehavior;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'preferred_timezone': preferredTimeZone,
    'timezone_offset': timezoneOffsetHours,
    'theme_mode': themeMode,
    'primary_language': primaryLanguage,
    'active_languages': <String>[resolvedUiLanguageCode(primaryLanguage)],
    'tag_display_mode': tagDisplayMode,
    'list_completion_behavior': listCompletionBehavior,
    if (displayName != null && displayName!.trim().isNotEmpty)
      'display_name': displayName!.trim(),
  };
}

/// Wire for `profiles.list_completion_behavior` / Lists UI (@DATA_MAP).
String listCompletionBehaviorWireForPatch(UserSettings s) {
  final w = s.listCompletionBehavior.trim().toLowerCase();
  if (w == 'stay' || w == 'bottom' || w == 'hide' || w == 'archive') {
    return w;
  }
  return 'hide';
}

/// Which PocketBase `tags.domain` rows a surface may show (@DATA_MAP).
enum TagCatalogScope {
  /// Legacy rows and `domain == 'plan'`.
  plan,

  /// `domain == 'list'` only.
  list,
}

extension TagCatalogScopeMatch on TagCatalogScope {
  bool matchesTag(Tag t) {
    final d = t.domain.trim().toLowerCase();
    switch (this) {
      case TagCatalogScope.list:
        return d == 'list';
      case TagCatalogScope.plan:
        return d.isEmpty || d == 'plan';
    }
  }
}

class UserSettings {
  UserSettings({
    required this.userId,
    this.language = 'en',
    this.preferredTimeZone = 'UTC',
    this.timezoneOffsetHours = 0,
    this.activeLanguages,
    this.primaryLanguage = 'en',
    this.defaultCategoryId,
    this.hasSeeded = false,
    this.themeMode = 'system',
    this.dataRegion,
    this.biometricEnabled = false,
    this.isAdmin = false,
    this.displayName,
    this.tagDisplayMode = CategoryDisplayMode.letterChip,
    this.tagDisplayModeWireRaw,

    /// PocketBase `list_completion_behavior`: stay | bottom | hide | archive.
    this.listCompletionBehavior = 'hide',

    /// Lists inbox: show `domain: list` tags on backlog cards. Device prefs per user (no PB column in Strike 25.4).
    this.showListTagsOnCards = true,
  });

  final String userId;
  final String language;
  final String preferredTimeZone;
  final int timezoneOffsetHours;
  final List<String>? activeLanguages;
  final String primaryLanguage;
  final int? defaultCategoryId;
  final bool hasSeeded;
  final String themeMode;
  final String? dataRegion;

  /// Shown in Profile / shell; persisted as profiles.display_name (@DATA_MAP.md).
  final String? displayName;

  /// Local biometric lock on app launch. Stored in profiles; never stored in cloud as biometric data.
  final bool biometricEnabled;

  /// Admin-only flag from `profiles.is_admin`. Read-only in client UI.
  final bool isAdmin;

  /// Minimalist chip style for categories/tags (Timeline, Planning). `profiles.tag_display_mode`.
  final CategoryDisplayMode tagDisplayMode;

  /// Exact string last read from PocketBase for [tagDisplayMode] (Select option spelling).
  final String? tagDisplayModeWireRaw;

  /// Lists checked-item UX (`profiles.list_completion_behavior`).
  final String listCompletionBehavior;

  /// Lists / backlog cards: render tag strip when true (persisted via device prefs keyed by user id).
  final bool showListTagsOnCards;

  /// Single UI language: derived from [primaryLanguage] / [language] (multi-active UI removed).
  List<String> get effectiveActiveLanguages => <String>[
    resolvedUiLanguageCode(
      primaryLanguage.trim().isNotEmpty ? primaryLanguage : language,
    ),
  ];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'language': language,
    'preferredTimeZone': preferredTimeZone.isEmpty ? 'UTC' : preferredTimeZone,
    'timezoneOffsetHours': timezoneOffsetHours,
    if (activeLanguages != null && activeLanguages!.isNotEmpty)
      'activeLanguages': activeLanguages,
    if (primaryLanguage.isNotEmpty) 'primaryLanguage': primaryLanguage,
    if (defaultCategoryId != null) 'defaultCategoryId': defaultCategoryId,
    'hasSeeded': hasSeeded,
    'themeMode': themeMode,
    if (dataRegion != null && dataRegion!.isNotEmpty) 'dataRegion': dataRegion,
    if (displayName != null && displayName!.trim().isNotEmpty)
      'displayName': displayName!.trim(),
    'tagDisplayMode': tagDisplayMode.wireValue,
    'listCompletionBehavior': listCompletionBehavior,
    'showListTagsOnCards': showListTagsOnCards,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final tz = json['preferredTimeZone'] as String?;
    final preferredTimeZone = (tz == null || tz.trim().isEmpty) ? 'UTC' : tz;
    final offsetRaw = json['timezoneOffsetHours'];
    final offset = offsetRaw is int
        ? offsetRaw
        : int.tryParse(offsetRaw?.toString() ?? '') ?? 0;
    final raw = json['activeLanguages'];
    List<String>? activeLanguages;
    if (raw is List) {
      activeLanguages = raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (activeLanguages.isEmpty) activeLanguages = null;
    }
    final tagWire = json['tag_display_mode'] ?? json['tagDisplayMode'];
    final tagWireStr = tagWire?.toString().trim();
    final rawListBeh =
        json['list_completion_behavior'] ?? json['listCompletionBehavior'];
    final listBehRaw = rawListBeh == null
        ? ''
        : rawListBeh.toString().trim().toLowerCase();
    final listBeh =
        (listBehRaw == 'stay' ||
            listBehRaw == 'bottom' ||
            listBehRaw == 'hide' ||
            listBehRaw == 'archive')
        ? listBehRaw
        : (listBehRaw.isEmpty ? 'stay' : 'hide');
    final tagsShowRaw =
        json['lists_show_tags_on_cards'] ??
        json['showListTagsOnCards'] ??
        json['show_list_tags_on_cards'];
    var showListTagsOnCards = true;
    if (tagsShowRaw != null) {
      if (tagsShowRaw is bool) {
        showListTagsOnCards = tagsShowRaw;
      } else {
        final s = tagsShowRaw.toString().trim().toLowerCase();
        if (s == 'false' || s == '0') {
          showListTagsOnCards = false;
        } else if (s == 'true' || s == '1') {
          showListTagsOnCards = true;
        }
      }
    }
    return UserSettings(
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
      language: json['language'] as String? ?? 'en',
      preferredTimeZone: preferredTimeZone,
      timezoneOffsetHours: offset,
      activeLanguages: activeLanguages,
      primaryLanguage: json['primaryLanguage'] as String? ?? 'en',
      defaultCategoryId: json['defaultCategoryId'] == null
          ? null
          : _jsonInt(json['defaultCategoryId']),
      hasSeeded: json['hasSeeded'] as bool? ?? false,
      themeMode: json['themeMode'] as String? ?? 'system',
      dataRegion: json['dataRegion'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      isAdmin: _jsonBool(json['is_admin'] ?? json['isAdmin']),
      displayName:
          json['displayName'] as String? ?? json['display_name'] as String?,
      tagDisplayMode: categoryDisplayModeFromWire(tagWireStr),
      tagDisplayModeWireRaw: (tagWireStr != null && tagWireStr.isNotEmpty)
          ? tagWireStr
          : null,
      listCompletionBehavior: listBeh,
      showListTagsOnCards: showListTagsOnCards,
    );
  }

  UserSettings copyWith({
    String? userId,
    String? language,
    String? preferredTimeZone,
    int? timezoneOffsetHours,
    List<String>? activeLanguages,
    String? primaryLanguage,
    int? defaultCategoryId,
    bool? hasSeeded,
    String? themeMode,
    String? dataRegion,
    bool? biometricEnabled,
    bool? isAdmin,
    String? displayName,
    CategoryDisplayMode? tagDisplayMode,
    String? tagDisplayModeWireRaw,
    String? listCompletionBehavior,
    bool? showListTagsOnCards,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      language: language ?? this.language,
      preferredTimeZone: preferredTimeZone ?? this.preferredTimeZone,
      timezoneOffsetHours: timezoneOffsetHours ?? this.timezoneOffsetHours,
      activeLanguages: activeLanguages ?? this.activeLanguages,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      hasSeeded: hasSeeded ?? this.hasSeeded,
      themeMode: themeMode ?? this.themeMode,
      dataRegion: dataRegion ?? this.dataRegion,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isAdmin: isAdmin ?? this.isAdmin,
      displayName: displayName ?? this.displayName,
      tagDisplayMode: tagDisplayMode ?? this.tagDisplayMode,
      tagDisplayModeWireRaw: tagDisplayMode != null
          ? null
          : (tagDisplayModeWireRaw ?? this.tagDisplayModeWireRaw),
      listCompletionBehavior:
          listCompletionBehavior ?? this.listCompletionBehavior,
      showListTagsOnCards: showListTagsOnCards ?? this.showListTagsOnCards,
    );
  }
}

/// Tag row. Business PK is [tagId] (`tag_id`); [wrapperRowId] optional legacy table row id.
