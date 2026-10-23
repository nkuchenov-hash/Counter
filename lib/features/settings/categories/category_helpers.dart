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

const List<IconData> kCategoryMoreIconChoices = <IconData>[
  ...kCategoryIconChoices,
  Icons.favorite_rounded, Icons.favorite_border_rounded,
  Icons.bedtime_outlined, Icons.bed_rounded, Icons.clean_hands_outlined,
  Icons.directions_walk_rounded, Icons.directions_run_rounded,
  Icons.checklist_rounded, Icons.schedule_rounded, Icons.access_time_rounded,
  Icons.account_balance_wallet_outlined, Icons.shopping_bag_outlined,
  Icons.shopping_cart_outlined, Icons.laptop_mac_rounded,
  Icons.desktop_windows_rounded, Icons.phone_iphone_rounded,
  Icons.menu_book_outlined, Icons.auto_stories_rounded,
  Icons.lightbulb_outline_rounded, Icons.psychology_outlined,
  Icons.local_hospital_outlined, Icons.medical_services_outlined,
  Icons.directions_bike_rounded, Icons.train_rounded,
  Icons.nightlight_rounded, Icons.wb_sunny_outlined,
  Icons.park_outlined, Icons.celebration_outlined,
  Icons.movie_outlined, Icons.camera_alt_outlined, Icons.savings_outlined,
  Icons.card_giftcard_outlined, Icons.groups_outlined,
  Icons.person_outline_rounded, Icons.star_outline_rounded,
  Icons.public_rounded, Icons.location_on_outlined,
  Icons.key_rounded, Icons.settings_outlined,
];
