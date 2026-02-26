import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:intellitaxi/features/home/presentation/no_connection_screen.dart';

void main() {
  testWidgets('AppLoadingIndicator renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingIndicator(size: 28, strokeWidth: 3)),
      ),
    );

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('NoConnectionScreen shows recovery UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NoConnectionScreen()));

    expect(find.text('Sin conexión a Internet'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
