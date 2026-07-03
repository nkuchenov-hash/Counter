part of '../database_service.dart';

extension ProfilePreferencesExtension on DatabaseService {
  Future<void> reloadForDataRegionChange() async {
    if ((currentProfileId?.isNotEmpty ?? false)) {
      unawaited(loadInitialData(currentProfileId!));
    }
  }

  String get dataRegion => _dataRegion;
}
