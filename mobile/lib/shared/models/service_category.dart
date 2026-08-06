import 'package:quickfix/shared/models/job_model.dart';

class ServiceCategory {
  final String id;
  final JobCategory category;
  final String name;
  final String description;
  final String iconPath;
  final bool isActive;
  final int sortOrder;

  const ServiceCategory({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.iconPath,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map, String id) {
    return ServiceCategory(
      id: id,
      category: JobCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => JobCategory.other,
      ),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconPath: map['iconPath'] ?? '',
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'name': name,
      'description': description,
      'iconPath': iconPath,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}

class CategorySeedData {
  static const List<ServiceCategory> defaultCategories = [
    ServiceCategory(
      id: 'cleaning',
      category: JobCategory.cleaning,
      name: 'Cleaning',
      description: 'Home and office cleaning services',
      iconPath: 'icons/cleaning.png',
      sortOrder: 1,
    ),
    ServiceCategory(
      id: 'plumbing',
      category: JobCategory.plumbing,
      name: 'Plumbing',
      description: 'Pipe repair, faucets, water systems',
      iconPath: 'icons/plumbing.png',
      sortOrder: 2,
    ),
    ServiceCategory(
      id: 'electrical',
      category: JobCategory.electrical,
      name: 'Electrical',
      description: 'Wiring, switches, appliance wiring',
      iconPath: 'icons/electrical.png',
      sortOrder: 3,
    ),
    ServiceCategory(
      id: 'carpentry',
      category: JobCategory.carpentry,
      name: 'Carpentry',
      description: 'Woodwork, furniture, structures',
      iconPath: 'icons/carpentry.png',
      sortOrder: 4,
    ),
    ServiceCategory(
      id: 'painting',
      category: JobCategory.painting,
      name: 'Painting',
      description: 'Interior and exterior painting',
      iconPath: 'icons/painting.png',
      sortOrder: 5,
    ),
    ServiceCategory(
      id: 'gardening',
      category: JobCategory.gardening,
      name: 'Gardening',
      description: 'Lawn care, landscaping, plants',
      iconPath: 'icons/gardening.png',
      sortOrder: 6,
    ),
    ServiceCategory(
      id: 'moving',
      category: JobCategory.moving,
      name: 'Moving',
      description: 'Furniture and item moving services',
      iconPath: 'icons/moving.png',
      sortOrder: 7,
    ),
    ServiceCategory(
      id: 'appliance_repair',
      category: JobCategory.applianceRepair,
      name: 'Appliance Repair',
      description: 'AC, fridge, washing machine repair',
      iconPath: 'icons/appliance.png',
      sortOrder: 8,
    ),
    ServiceCategory(
      id: 'tutoring',
      category: JobCategory.tutoring,
      name: 'Tutoring',
      description: 'Academic and skill tutoring',
      iconPath: 'icons/tutoring.png',
      sortOrder: 9,
    ),
    ServiceCategory(
      id: 'beauty',
      category: JobCategory.beauty,
      name: 'Beauty',
      description: 'Salon, grooming, personal care',
      iconPath: 'icons/beauty.png',
      sortOrder: 10,
    ),
    ServiceCategory(
      id: 'other',
      category: JobCategory.other,
      name: 'Other',
      description: 'Other services',
      iconPath: 'icons/other.png',
      sortOrder: 99,
    ),
  ];
}