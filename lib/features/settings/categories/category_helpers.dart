import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

/// Icon palette shared by category appearance + full editor sheets.
const List<IconData> kCategoryIconChoices = <IconData>[
  Icons.folder_rounded,
  Icons.work_rounded,
  Icons.home_rounded,
  Icons.fitness_center_rounded,
  Icons.book_rounded,
  Icons.local_cafe_rounded,
  Icons.school_rounded,
  Icons.music_note_rounded,
  Icons.restaurant_rounded,
  Icons.directions_car_rounded,
  Icons.flight_rounded,
  Icons.child_care_rounded,
  Icons.pets_rounded,
  Icons.code_rounded,
  Icons.eco_rounded,
];

IconData categoryManagerIconFor(CategoryRule rule) {
  final selected = rule.iconCodePoint;
  if (selected != null && selected != Icons.folder_rounded.codePoint) {
    return rule.iconOrDefault;
  }
  final name = rule.name.toLowerCase();
  if (name.contains('здоров') || name.contains('health') ||
      name.contains('жизн') || name.contains('life')) return Icons.favorite_border_rounded;
  if (name.contains('сон') || name.contains('sleep')) return Icons.bedtime_outlined;
  if (name.contains('еда') || name.contains('food')) return Icons.restaurant_rounded;
  if (name.contains('работ') || name.contains('work')) return Icons.work_outline_rounded;
  if (name.contains('финанс') || name.contains('finance')) return Icons.account_balance_wallet_outlined;
  if (name.contains('прогул') || name.contains('walk')) return Icons.directions_walk_rounded;
  if (name.contains('транспорт') || name.contains('перемещ')) return Icons.directions_car_rounded;
  if (name.contains('время') || name.contains('time')) return Icons.schedule_rounded;
  if (name.contains('гигиен') || name.contains('туалет')) return Icons.clean_hands_outlined;
  if (name.contains('спорт') || name.contains('fitness')) return Icons.fitness_center_rounded;
  if (name.contains('дела') || name.contains('tasks')) return Icons.checklist_rounded;
  return rule.iconOrDefault;
}
