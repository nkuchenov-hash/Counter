part of '../database_service.dart';

bool _profileBool(dynamic value, [bool fallback = false]) {
  if (value == true) return true;
  if (value == false) return false;
  if (value == 1) return true;
  if (value == 0) return false;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}
