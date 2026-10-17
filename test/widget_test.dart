// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:acessametro_app/api/api_service.dart';
import 'package:acessametro_app/main.dart';

void main() {
  testWidgets('opens the home screen from welcome as a guest', (tester) async {
    final client = MockClient(
      (_) async => http.Response(
        '{"success":true,"data":[]}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(AcessaMetroApp(api: ApiService(client: client)));
    await tester.pumpAndSettle();

    expect(find.text('Explorar sem conta'), findsOneWidget);
    await tester.tap(find.text('Explorar sem conta'));
    await tester.pumpAndSettle();

    expect(find.text('AcessaMetrô'), findsOneWidget);
    expect(find.text('Estações'), findsOneWidget);
    expect(find.text('Rotas'), findsOneWidget);
    expect(find.text('Denunciar'), findsOneWidget);
    expect(find.text('Seu caminho,\nmais acessível.'), findsOneWidget);
  });
}
