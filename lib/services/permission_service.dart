import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permission requests for Android and iOS.
///
/// Follows platform best practices:
/// - Checks if location services are enabled on the device.
/// - Requests foreground permission first (WhenInUse).
/// - If foreground is granted, requests background location permission (Always).
class PermissionService {
  /// Check whether foreground location permission is granted.
  Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Check whether background location permission is granted.
  Future<bool> hasBackgroundPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Check if location services (GPS hardware) are turned on.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Requests foreground location permission first, followed by background
  /// location permission if foreground was granted.
  ///
  /// Returns a record: (foregroundGranted, backgroundGranted)
  Future<({bool foreground, bool background})> requestAllLocationPermissions() async {
    // 1. Check & request foreground location
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    if (!status.isGranted) {
      return (foreground: false, background: false);
    }

    // 2. Request background location (Android 10+ requires foreground first)
    var bgStatus = await Permission.locationAlways.status;
    if (!bgStatus.isGranted) {
      bgStatus = await Permission.locationAlways.request();
    }

    return (
      foreground: status.isGranted,
      background: bgStatus.isGranted,
    );
  }

  /// Open app settings if user permanently denied permissions.
  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
