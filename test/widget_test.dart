import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_service/main.dart';
import 'package:cafe_service/features/menu/menu_management_page.dart';

void main() {
  testWidgets('service dashboard is shown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServiceDashboard()));

    expect(find.text('Service dashboard'), findsOneWidget);
    expect(find.text('Today’s menu'), findsOneWidget);
    expect(find.text('Manage pantry'), findsOneWidget);
    expect(find.text('Orders'), findsNWidgets(2));
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('menu management page renders with refresh and add item actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MenuManagementPage()));
    await tester.pump();

    expect(find.text('Today’s menu'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

