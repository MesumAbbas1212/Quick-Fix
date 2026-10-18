import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/settings/permission_explainer_screen.dart';

/// Permission reads never trigger the OS dialog. Passive browse loads should
/// call hasLocationAccess and offer an explicit opt-in instead of pushing a
/// permission route from a preloaded shell tab.
Future<bool> hasLocationAccess(LocationService service) async {
  try {
    final status = await service.getPermissionStatus().timeout(const Duration(seconds: 3));
    return status == LocationPermission.always || status == LocationPermission.whileInUse;
  } catch (_) { return false; }
}

Future<bool> explainLocationAccess(BuildContext context, {
  required LocationService locationService, required String purpose,
}) async {
  if (await hasLocationAccess(locationService)) return true;
  if (!context.mounted) return false;
  return await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) =>
    PermissionExplainerScreen(purpose: purpose, locationService: locationService))) ?? false;
}
