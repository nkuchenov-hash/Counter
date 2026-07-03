part of '../database_service.dart';

extension TagDisplaySettingsExtension on DatabaseService {
  static String _prefsKeyShowListTagsOnCards(String uid) =>
      'lists_show_tags_on_cards_${uid.trim()}';

  /// Lists inbox: persist tag strip visibility per auth user (device prefs; merged into [UserSettings]).
  Future<void> persistShowListTagsOnCards(bool value) async {
    final aid = _requireAuthUserIdForWrite();
    _settings = _settings.copyWith(showListTagsOnCards: value);
    _settingsController.add(_settings);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyShowListTagsOnCards(aid), value);
    } catch (_) {}
  }
}
