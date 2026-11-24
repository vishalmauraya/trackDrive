import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionResult {
  final bool foreground;
  final bool background;
  final bool isPermanentlyDenied;

  const PermissionResult({
    required this.foreground,
    required this.background,
    this.isPermanentlyDenied = false,
  });
}

/// Handles runtime permission requests for Android and iOS.
///
/// Follows platform best practices:
/// - Checks if location services are enabled on the device.
/// - Automatically requests foreground permission first (WhenInUse).
/// - If foreground is granted, requests background location permission (Always).
class PermissionService {
  final bool isTestMode;

  PermissionService({this.isTestMode = false});

  /// Check whether foreground location permission is granted.
  Future<bool> hasLocationPermission() async {
    if (isTestMode) return true;
    try {
      final status = await Permission.location.status;
      return status.isGranted;
    } catch (_) {
      // Graceful fallback for desktop/mock testing environments
      return !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
          ? false
          : true;
    }
  }

  /// Check whether background location permission is granted.
  Future<bool> hasBackgroundPermission() async {
    if (isTestMode) return true;
    try {
      final status = await Permission.locationAlways.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Check whether location permission has been permanently denied.
  Future<bool> isPermanentlyDenied() async {
    if (isTestMode) return false;
    try {
      final status = await Permission.location.status;
      return status.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  /// Check if location services (GPS hardware) are turned on.
  Future<bool> isLocationServiceEnabled() async {
    if (isTestMode) return true;
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Automatically invoked on app launch: checks and requests permissions.
  Future<PermissionResult> autoCheckAndRequestOnOpen() async {
    if (isTestMode) {
      return const PermissionResult(
        foreground: true,
        background: true,
        isPermanentlyDenied: false,
      );
    }

    try {
      var fgStatus = await Permission.location.status;

      // If not determined, prompt immediately on open
      if (!fgStatus.isGranted && !fgStatus.isPermanentlyDenied) {
        fgStatus = await Permission.location.request();
      }

      if (!fgStatus.isGranted) {
        return PermissionResult(
          foreground: false,
          background: false,
          isPermanentlyDenied: fgStatus.isPermanentlyDenied,
        );
      }

      // Foreground granted: check & request background location (Android 10+ / iOS)
      var bgStatus = await Permission.locationAlways.status;
      if (!bgStatus.isGranted && !bgStatus.isPermanentlyDenied) {
        bgStatus = await Permission.locationAlways.request();
      }

      return PermissionResult(
        foreground: fgStatus.isGranted,
        background: bgStatus.isGranted,
        isPermanentlyDenied: fgStatus.isPermanentlyDenied,
      );
    } catch (_) {
      // In desktop/mock environments without native location channels
      return const PermissionResult(
        foreground: true,
        background: true,
        isPermanentlyDenied: false,
      );
    }
  }

  /// Explicit request triggered by the user clicking "Grant Permission".
  Future<PermissionResult> requestAllLocationPermissions() async {
    return autoCheckAndRequestOnOpen();
  }

  /// Open app settings if user permanently denied permissions.
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
