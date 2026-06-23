import 'package:flutter/material.dart';

/// Category presentation resolved by the Brain at the shell boundary.
class PlanCategoryPresentation {
  const PlanCategoryPresentation({
    required this.color,
    this.icon,
    this.breadcrumbPath = '',
  });

  final Color color;
  final IconData? icon;
  final String breadcrumbPath;
}

/// Injected once after [DatabaseService] bootstrap — keeps core cards free of Brain imports.
abstract final class PlanCategoryLookup {
  static PlanCategoryPresentation Function(int categoryId)? resolve;
}
