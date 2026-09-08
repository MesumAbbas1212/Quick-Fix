/// A display language the QuickFix app can be shown in.
///
/// Instances normally come from data sources rather than app code:
/// the `languages` collection in Firestore (admin-curated) and the
/// translation proxy's supported-language list. Adding a language to
/// either source makes it appear in the app without a code change.
class AppLanguage {
  final String code;
  final String nativeName;
  final String englishName;

  const AppLanguage({
    required this.code,
    this.nativeName = '',
    this.englishName = '',
  });

  /// Preferred label: native name first, then English name, then code.
  String get displayName {
    if (nativeName.isNotEmpty) return nativeName;
    if (englishName.isNotEmpty) return englishName;
    return code;
  }

  factory AppLanguage.fromMap(Map<String, dynamic> map) {
    return AppLanguage(
      code: (map['code'] ?? '').toString(),
      nativeName: (map['nativeName'] ?? '').toString(),
      englishName: (map['englishName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'nativeName': nativeName,
      'englishName': englishName,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AppLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'AppLanguage($code)';
}
