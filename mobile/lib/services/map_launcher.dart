import 'package:url_launcher/url_launcher.dart';

/// Abstraction over external-map launching so tests can inject a recorder.
abstract class UrlLauncher {
  /// Opens [url] externally. Returns false when no handler exists.
  Future<bool> open(String url);

  /// Opens a shared location in the Google Maps app. On Android the
  /// `geo:` scheme resolves directly to the installed maps app; the
  /// https URL is the universal fallback (still opens the Google Maps
  /// app when installed, otherwise the browser).
  Future<bool> openLocation(double latitude, double longitude);
}

class MapLauncher implements UrlLauncher {
  const MapLauncher();

  @override
  Future<bool> openLocation(double latitude, double longitude) async {
    final coords = '${latitude.toStringAsFixed(5)},'
        '${longitude.toStringAsFixed(5)}';
    final geoUrl = 'geo:$coords?q=$coords';
    if (await open(geoUrl)) return true;
    return open('https://www.google.com/maps/search/?api=1&query=$coords');
  }

  @override
  Future<bool> open(String url) async {
    final uri = Uri.parse(url);
    try {
      return launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
