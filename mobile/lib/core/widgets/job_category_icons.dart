import 'package:flutter/material.dart';
import 'package:quickfix/models/job_model.dart';

/// Single source of truth for `JobCategory` icons and display labels.
///
/// The category grid, job cards and any future category UI must use these
/// helpers so the icon-for-category mapping never disagrees between
/// surfaces (per spec: icons come from one map in `core/widgets/`).
const Map<JobCategory, IconData> kJobCategoryIcons = {
  JobCategory.cleaning: Icons.cleaning_services,
  JobCategory.plumbing: Icons.water_drop,
  JobCategory.electrical: Icons.flash_on,
  JobCategory.carpentry: Icons.chair,
  JobCategory.painting: Icons.format_paint,
  JobCategory.gardening: Icons.landscape_outlined,
  JobCategory.moving: Icons.local_shipping_outlined,
  JobCategory.applianceRepair: Icons.ac_unit,
  JobCategory.tutoring: Icons.school_outlined,
  JobCategory.beauty: Icons.face_outlined,
  JobCategory.other: Icons.handyman,
};

IconData jobCategoryIcon(JobCategory category) =>
    kJobCategoryIcons[category] ?? Icons.category_outlined;

/// "applianceRepair" → "Appliance Repair", "cleaning" → "Cleaning".
String jobCategoryLabel(JobCategory category) {
  final name = category.name;
  return name[0].toUpperCase() +
      name.substring(1).replaceAllMapped(
        RegExp(r'(?<=[a-z])([A-Z])'), (match) => ' ${match[1]}');
}
