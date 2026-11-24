import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracking_provider.dart';
import 'screens/tracking_screen.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/sync_service.dart';

void main() {
  runApp(const TrackDriveApp());
}

class TrackDriveApp extends StatelessWidget {
  const TrackDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrackingProvider>(
      create: (_) {
        final db = DatabaseService();
        final api = ApiService();
        final conn = ConnectivityService();
        final location = LocationService();
        final sync = SyncService(db: db, api: api, connectivity: conn);
        final provider = TrackingProvider(
          locationService: location,
          databaseService: db,
          connectivityService: conn,
          syncService: sync,
        );
        // Boot async init without blocking the widget tree.
        provider.init();
        return provider;
      },
      child: MaterialApp(
        title: 'TrackDrive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F1923),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00C896),
            secondary: Color(0xFF4A9EFF),
          ),
        ),
        home: const TrackingScreen(),
      ),
    );
  }
}
