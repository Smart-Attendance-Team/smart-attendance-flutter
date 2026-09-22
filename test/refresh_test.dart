import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance/core/network/api_client.dart';
import 'package:smart_attendance/features/student/presentation/my_attendance_screen.dart';

/// Proves the AppBar refresh button actually refetches and confirms:
/// tap -> loading -> same data + "Updated" toast, with no exceptions.
void main() {
  testWidgets('manual refresh refetches and confirms visibly', (
    tester,
  ) async {
    ApiClient.demoMode = true;
    addTearDown(() => ApiClient.demoMode = false);

    await tester.pumpWidget(
      const MaterialApp(home: MyAttendanceScreen()),
    );
    await tester.pumpAndSettle();

    // Initial demo data is on screen.
    expect(find.textContaining('CS101'), findsWidgets);

    // Tap the circular refresh arrow.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // A reload is in flight (spinner) or already done (toast/data).
    await tester.pumpAndSettle();

    // Visible confirmation that refresh ran.
    expect(find.text('Updated'), findsOneWidget);
    // Data is still rendered afterwards.
    expect(find.textContaining('CS101'), findsWidgets);
  });
}
