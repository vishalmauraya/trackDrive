import 'package:flutter/material.dart';
import '../providers/tracking_provider.dart';

/// Displayed when location permission is denied on app open.
///
/// Prominently informs the user that location access is mandatory to continue,
/// detailing why each permission (foreground & background) is needed, and
/// providing direct action buttons to grant or open system app settings.
class PermissionRequiredView extends StatelessWidget {
  final TrackingProvider provider;

  const PermissionRequiredView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isPermanent = provider.isPermanentlyDenied;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2635),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header with halo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: Colors.orangeAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Location Permission Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Location access is necessary to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description bullets
              _FeatureBullet(
                icon: Icons.my_location,
                title: 'Live GPS & Route Mapping',
                subtitle:
                    'Captures precise vehicle coordinates and renders live driving polylines on the map.',
              ),
              const SizedBox(height: 12),
              _FeatureBullet(
                icon: Icons.speed,
                title: 'Speed & Telemetry Tracking',
                subtitle:
                    'Monitors instantaneous driving speed, heading, and GPS accuracy.',
              ),
              const SizedBox(height: 12),
              _FeatureBullet(
                icon: Icons.security,
                title: 'Background Trip Logging',
                subtitle:
                    'Ensures uninterrupted route recording when the screen is locked or the app is minimized.',
              ),
              const SizedBox(height: 24),

              if (isPermanent) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Permission is permanently denied. Please enable Location in App Settings to proceed.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPermanent
                        ? const Color(0xFF4A9EFF)
                        : const Color(0xFF00C896),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isPermanent
                      ? provider.openAppSettings
                      : provider.requestPermissions,
                  icon: Icon(
                    isPermanent ? Icons.settings : Icons.check_circle_outline,
                    size: 20,
                  ),
                  label: Text(
                    isPermanent ? 'Open App Settings' : 'Grant Location Permission',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF00C896), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
