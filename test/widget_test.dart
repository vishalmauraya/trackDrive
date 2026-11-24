import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:track_drive/main.dart';
import 'package:track_drive/providers/tracking_provider.dart';
import 'package:track_drive/services/api_service.dart';
import 'package:track_drive/services/connectivity_service.dart';
import 'package:track_drive/services/database_service.dart';
import 'package:track_drive/services/location_service.dart';
import 'package:track_drive/services/sync_service.dart';
import 'package:track_drive/widgets/permission_required_view.dart';

class _MockConnectivityService extends ConnectivityService {
  @override
  Stream<bool> get onlineStatusStream => Stream.value(true);

  @override
  Future<bool> isCurrentlyOnline() async => true;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('TrackDriveApp renders header and tracking dashboard when permissions granted',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TrackDriveApp());
    await tester.pump();

    // Verify app title and primary controls are rendered
    expect(find.text('TrackDrive'), findsOneWidget);
    expect(find.text('Start Tracking'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets('PermissionRequiredView displays required copy and action buttons when permission is denied',
      (WidgetTester tester) async {
    final db = DatabaseService();
    final api = ApiService();
    final conn = _MockConnectivityService();
    final location = LocationService();
    final sync = SyncService(db: db, api: api, connectivity: conn);

    final provider = TrackingProvider(
      locationService: location,
      databaseService: db,
      connectivityService: conn,
      syncService: sync,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionRequiredView(provider: provider),
        ),
      ),
    );

    // Verify blocking permission view is shown with all required text and controls
    expect(find.text('Location Permission Required'), findsOneWidget);
    expect(find.text('Location access is necessary to continue'), findsOneWidget);
    expect(find.text('Grant Location Permission'), findsOneWidget);
    expect(find.text('Continue with Simulated GPS (Demo Mode)'), findsOneWidget);
  });
}
