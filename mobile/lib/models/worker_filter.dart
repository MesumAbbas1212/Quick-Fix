import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';

/// Immutable, in-memory browse criteria. Dynamic language values carry their
/// catalog names as well as codes, so legacy worker names can be matched without
/// a hard-coded language/translation dictionary. Nothing is written to Firestore.
class WorkerFilter {
  final Set<JobCategory> categories;
  final double minPrice;
  final double? maxPrice;
  final double? maxDistanceKm;
  final double minimumRating;
  final Set<String> ranks;
  final bool onlyAvailable;
  final Set<AppLanguage> languages;

  WorkerFilter({Iterable<JobCategory> categories = const [], this.minPrice = 0,
    this.maxPrice, this.maxDistanceKm, this.minimumRating = 0,
    Iterable<String> ranks = const [], this.onlyAvailable = false,
    Iterable<AppLanguage> languages = const [],
  }) : assert(minPrice >= 0 && minPrice.isFinite),
       assert(maxPrice == null || (maxPrice.isFinite && maxPrice >= minPrice)),
       assert(maxDistanceKm == null || (maxDistanceKm >= 1 && maxDistanceKm <= 50)),
       assert(minimumRating >= 0 && minimumRating <= 5),
       categories = Set.unmodifiable(categories), ranks = Set.unmodifiable(ranks),
       languages = Set.unmodifiable(languages);

  bool get isDefault => categories.isEmpty && minPrice == 0 && maxPrice == null &&
      maxDistanceKm == null && minimumRating == 0 && ranks.isEmpty && !onlyAvailable && languages.isEmpty;

  WorkerFilter copyWith({Iterable<JobCategory>? categories, double? minPrice,
    double? maxPrice, bool clearMaxPrice = false, double? maxDistanceKm,
    bool clearDistance = false, double? minimumRating, Iterable<String>? ranks,
    bool? onlyAvailable, Iterable<AppLanguage>? languages,
  }) => WorkerFilter(categories: categories ?? this.categories, minPrice: minPrice ?? this.minPrice,
    maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
    maxDistanceKm: clearDistance ? null : maxDistanceKm ?? this.maxDistanceKm,
    minimumRating: minimumRating ?? this.minimumRating, ranks: ranks ?? this.ranks,
    onlyAvailable: onlyAvailable ?? this.onlyAvailable, languages: languages ?? this.languages);

  static bool _same<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);
  @override
  bool operator ==(Object other) => other is WorkerFilter && _same(categories, other.categories) &&
      minPrice == other.minPrice && maxPrice == other.maxPrice && maxDistanceKm == other.maxDistanceKm &&
      minimumRating == other.minimumRating && _same(ranks, other.ranks) && onlyAvailable == other.onlyAvailable &&
      _same(languages, other.languages);
  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(categories), minPrice, maxPrice, maxDistanceKm,
    minimumRating, Object.hashAllUnordered(ranks), onlyAvailable, Object.hashAllUnordered(languages));
}
