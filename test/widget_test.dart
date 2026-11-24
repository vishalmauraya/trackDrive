import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:track_drive/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('TrackDriveApp renders header and tracking controls', (WidgetTester tester) async {
    await tester.pumpWidget(const TrackDriveApp());
    await tester.pump();

    // Verify app title and primary controls are rendered
    expect(find.text('TrackDrive'), findsOneWidget);
    expect(find.text('Start Tracking'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
  });
}
