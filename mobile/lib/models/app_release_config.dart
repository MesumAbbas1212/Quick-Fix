class AppReleaseConfig {
  final int minBuild;
  final int latestBuild;
  final String message;
  final String storeUrl;
  const AppReleaseConfig({required this.minBuild, required this.latestBuild, required this.message, required this.storeUrl});

  static Uri? safeStoreUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443)) return null;
    if (uri.host == 'play.google.com' && uri.path == '/store/apps/details' && (uri.queryParameters['id']?.isNotEmpty ?? false)) return uri;
    if (uri.host == 'apps.apple.com' && RegExp(r'/id\d+(?:/|$)').hasMatch(uri.path)) return uri;
    return null;
  }
  static AppReleaseConfig? fromMap(Map<String, dynamic> map) {
    int? build(Object? value) => value is num && value.isFinite && value >= 0 && value == value.roundToDouble() ? value.toInt() : null;
    final minimum = build(map['minBuild']);
    final latest = build(map['latestBuild']);
    final url = map['storeUrl'];
    if (minimum == null || latest == null || latest < minimum || url is! String || safeStoreUri(url) == null) return null;
    final message = map['message'];
    return AppReleaseConfig(minBuild: minimum, latestBuild: latest, storeUrl: url,
      message: message is String && message.trim().isNotEmpty ? message.trim() : 'Install the latest QuickFix release to continue safely.');
  }
}

class AppReleaseDecision {
  final AppReleaseConfig? config;
  final int currentBuild;
  final int? previousBuild;
  const AppReleaseDecision({this.config, required this.currentBuild, this.previousBuild});
  bool get requiresUpdate => config != null && currentBuild < config!.minBuild;
  bool get hasSoftUpdate => config != null && !requiresUpdate && currentBuild < config!.latestBuild;
}
