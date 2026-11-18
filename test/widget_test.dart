// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:acessametro_app/api/api_service.dart';
import 'package:acessametro_app/main.dart';
import 'package:acessametro_app/screens/account_screen.dart';
import 'package:acessametro_app/screens/incidents_screen.dart';
import 'package:acessametro_app/screens/station_detail_screen.dart';
import 'package:acessametro_app/screens/stations_screen.dart';
import 'package:acessametro_app/services/accessibility_notifications.dart';
import 'package:acessametro_app/services/push_notifications.dart';
import 'package:acessametro_app/utils/accessibility_data.dart';
import 'package:acessametro_app/utils/station_search.dart';

void main() {
  test(
    'registers the push token and keeps favorite stations in sync',
    () async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final storedValues = <String, String>{};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(storageChannel, (call) async {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        final key = arguments['key'] as String?;
        switch (call.method) {
          case 'read':
            return storedValues[key];
          case 'write':
            storedValues[key!] = arguments['value'] as String;
            return null;
          case 'delete':
            storedValues.remove(key);
            return null;
          default:
            throw MissingPluginException('Unsupported method: ${call.method}');
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(storageChannel, null),
      );

      final syncedStationIds = <List<String>>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'test-jwt-token',
              'user': {'id': 'user-1', 'email': 'user@example.com'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/notifications/device')) {
          expect(request.method, 'PUT');
          expect(request.headers['authorization'], 'Bearer test-jwt-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'test-fcm-token-12345678901234567890');
          syncedStationIds.add(List<String>.from(body['stationIds'] as List));
          return http.Response(
            '{"success":true,"data":{"id":"device-1","stationIds":[]}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('Unexpected request: ${request.method} ${request.url.path}');
      });
      final api = ApiService(
        client: client,
        pushTokenProvider: _FakePushTokenProvider(
          'test-fcm-token-12345678901234567890',
        ),
      );

      await api.login('user@example.com', 'password');
      await api.toggleFavoriteStation('station-luz');

      expect(syncedStationIds, [
        <String>[],
        ['station-luz'],
      ]);
    },
  );

  testWidgets('admin can update an incident status', (tester) async {
    var statusUpdated = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/incidents')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'incident-1',
                'title': 'Elevador parado',
                'description': 'O elevador está fora de serviço.',
                'status': statusUpdated ? 'IN_PROGRESS' : 'PENDING',
                'station': {'name': 'Luz'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PATCH' &&
          request.url.path.endsWith('/incidents/incident-1/status')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'IN_PROGRESS');
        statusUpdated = true;
        return http.Response(
          '{"success":true,"data":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      fail('Unexpected request: ${request.method} ${request.url.path}');
    });
    final api = ApiService(client: client)
      ..token = 'admin-token'
      ..currentUser = {'role': 'ADMIN'};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IncidentsScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustar status'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajustar status do relato'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em andamento').last);
    await tester.pumpAndSettle();

    expect(statusUpdated, isTrue);
    expect(find.text('Em andamento'), findsOneWidget);
  });

  test('only active accessibility incidents trigger a station alert', () {
    final incidents = activeAccessibilityIncidents([
      {'category': 'ELEVATOR', 'status': 'PENDING'},
      {'category': 'ESCALATOR', 'status': 'IN_PROGRESS'},
      {'category': 'ACCESSIBILITY', 'status': 'RESOLVED'},
      {'category': 'SAFETY', 'status': 'PENDING'},
      {'category': 'OTHER', 'status': 'IN_PROGRESS'},
    ]);

    expect(incidents, [
      {'category': 'ELEVATOR', 'status': 'PENDING'},
      {'category': 'ESCALATOR', 'status': 'IN_PROGRESS'},
    ]);
  });

  testWidgets('loads and removes a station from favorites', (tester) async {
    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final storedValues = <String, String>{
      'favorite_station_ids': '["station-luz"]',
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      final arguments = Map<Object?, Object?>.from(call.arguments as Map);
      final key = arguments['key'] as String?;
      switch (call.method) {
        case 'read':
          return storedValues[key];
        case 'write':
          storedValues[key!] = arguments['value'] as String;
          return null;
        default:
          throw MissingPluginException('Unsupported method: ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(storageChannel, null));

    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/stations'));
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {'id': 'station-luz', 'name': 'Luz', 'line': 'Linha 1 - Azul'},
            {'id': 'station-se', 'name': 'Sé', 'line': 'Linha 1 - Azul'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FavoriteStationsScreen(api: ApiService(client: client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Luz'), findsOneWidget);
    expect(find.text('Sé'), findsNothing);
    await tester.tap(find.byTooltip('Remover Luz dos favoritos'));
    await tester.pumpAndSettle();

    expect(
      find.text('Estações salvas como favoritas aparecerão aqui.'),
      findsOneWidget,
    );
    expect(storedValues['favorite_station_ids'], '[]');
  });

  testWidgets(
    'notifies when favoriting a station with active accessibility issues',
    (tester) async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final storedValues = <String, String>{};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(storageChannel, (call) async {
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        final key = arguments['key'] as String?;
        switch (call.method) {
          case 'read':
            return storedValues[key];
          case 'write':
            storedValues[key!] = arguments['value'] as String;
            return null;
          default:
            throw MissingPluginException('Unsupported method: ${call.method}');
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(storageChannel, null),
      );

      final notifications = _RecordingAccessibilityNotifications();
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/stations/station-se'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'station-se',
              'name': 'Sé',
              'line': 'Linha 1 - Azul',
              'incidents': [
                {
                  'category': 'ELEVATOR',
                  'status': 'IN_PROGRESS',
                  'title': 'Elevador fora de serviço',
                },
                {
                  'category': 'SAFETY',
                  'status': 'PENDING',
                  'title': 'Relato de segurança',
                },
              ],
              'reviews': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: StationDetailScreen(
            api: ApiService(client: client),
            stationId: 'station-se',
            notifications: notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Adicionar aos favoritos'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
      expect(notifications.stationName, 'Sé');
      expect(notifications.incidents, [
        {
          'category': 'ELEVATOR',
          'status': 'IN_PROGRESS',
          'title': 'Elevador fora de serviço',
        },
      ]);
    },
  );

  test('searches stations by name or line without accent sensitivity', () {
    final stations = [
      {'id': 'se', 'name': 'Sé', 'line': 'Linha 1 - Azul'},
      {'id': 'luz', 'name': 'Luz', 'line': 'Linha 1 - Azul'},
      {'id': 'pinheiros', 'name': 'Pinheiros', 'line': 'Linha 4 - Amarela'},
    ];

    expect(filterStations(stations, 'se'), [stations.first]);
    expect(filterStations(stations, 'linha 4'), [stations.last]);
    expect(filterStations(stations, 'nao encontrada'), isEmpty);
  });

  testWidgets('filters the station list while typing', (tester) async {
    final stations = [
      {'id': 'pinheiros', 'name': 'Pinheiros', 'line': 'Linha 4 - Amarela'},
      {'id': 'luz', 'name': 'Luz', 'line': 'Linha 1 - Azul'},
    ];
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': stations}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationsScreen(api: ApiService(client: client)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'luz');
    await tester.pumpAndSettle();

    expect(find.text('Luz'), findsOneWidget);
    expect(find.text('Pinheiros'), findsNothing);
  });

  testWidgets('allows typing and choosing a station for an incident', (
    tester,
  ) async {
    final stations = [
      {'id': 'pinheiros', 'name': 'Pinheiros', 'line': 'Linha 4 - Amarela'},
    ];
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': stations}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentReportScreen(api: ApiService(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'pin');
    await tester.pumpAndSettle();

    expect(find.text('Pinheiros'), findsOneWidget);
    await tester.tap(find.text('Pinheiros'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Pinheiros',
    );
  });

  test('ignores accessibility placeholders', () {
    expect(parseAccessibilityFeatures('Consultar'), isEmpty);
    expect(parseAccessibilityFeatures('Elevadores, Piso tátil'), [
      'Elevadores',
      'Piso tátil',
    ]);
    expect(accessibilitySummary(null), 'Ainda sem informações cadastradas.');
  });

  test('parses structured accessibility records', () {
    expect(
      parseAccessibilityFeatures(
        jsonEncode({
          'station': 'Sé',
          'accessibility': {
            'elevator': true,
            'ramp': true,
            'tactileFloor': true,
            'braille': true,
            'accessibleRestroom': true,
            'visualAnnouncements': true,
            'audioAnnouncements': true,
            'wheelchairAccess': true,
            'sensoryRoom': false,
          },
        }),
      ),
      [
        'Elevador',
        'Rampa',
        'Piso tátil',
        'Sinalização em braille',
        'Banheiro acessível',
        'Avisos visuais',
        'Avisos sonoros',
        'Acesso para cadeira de rodas',
        'Sala sensorial — não disponível',
      ],
    );
  });

  test('geocodes a station using a matching railway feature', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'photon.komoot.io');
      return http.Response(
        jsonEncode({
          'features': [
            {
              'properties': {
                'name': 'Ana Rosa',
                'countrycode': 'BR',
                'osm_key': 'railway',
                'osm_value': 'station',
              },
              'geometry': {
                'coordinates': [-46.638379, -23.5814424],
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final coordinates = await ApiService(client: client).geocodeStation({
      'id': 'ana-rosa-verde',
      'name': 'Ana Rosa',
      'latitude': 0,
      'longitude': 0,
    });

    expect(coordinates, {'latitude': -23.5814424, 'longitude': -46.638379});
  });

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

  testWidgets('plans a route between stations returned by the API', (
    tester,
  ) async {
    final stations = [
      {
        'id': 'station-pinheiros',
        'name': 'Pinheiros',
        'line': 'Linha 4 - Amarela',
        'latitude': -23.5661,
        'longitude': -46.7011,
      },
      {
        'id': 'station-luz',
        'name': 'Luz',
        'line': 'Linha 1 - Azul',
        'latitude': -23.5364,
        'longitude': -46.6338,
      },
      {
        'id': 'station-unrelated',
        'name': 'Estação Jabaquara',
        'line': 'Linha 1 - Azul',
        'latitude': -23.6462,
        'longitude': -46.641,
      },
    ];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stations')) {
        return http.Response(
          jsonEncode({'success': true, 'data': stations}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/routes/transit')) {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'originId': 'station-pinheiros',
          'destinationId': 'station-luz',
          'origin': {'latitude': -23.5661, 'longitude': -46.7011},
          'destination': {'latitude': -23.5364, 'longitude': -46.6338},
        });
        return http.Response(
          '{"success":false,"message":"Rota não encontrada: POST /api/routes/transit"}',
          404,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.host == 'api.transitous.org') {
        expect(request.url.path, '/api/v6/plan');
        expect(request.url.queryParameters['fromPlace'], '-23.5661,-46.7011');
        expect(request.url.queryParameters['toPlace'], '-23.5364,-46.6338');
        expect(request.url.queryParameters['transitModes'], 'SUBWAY,SUBURBAN');
        return http.Response(
          jsonEncode({
            'itineraries': [
              {
                'duration': 1080,
                'transfers': 1,
                'legs': [
                  {
                    'mode': 'SUBWAY',
                    'from': {'name': 'Pinheiros'},
                    'to': {
                      'name': 'República',
                      'lat': -23.5448,
                      'lon': -46.6427,
                    },
                    'duration': 900,
                    'displayName': 'METRÔ L4',
                    'legGeometry': {'points': 'muhar}nA?', 'precision': 6},
                    'intermediateStops': [
                      {'name': 'Faria Lima', 'lat': -23.5677, 'lon': -46.6938},
                      {
                        'name': 'Fradique Coutinho',
                        'lat': -23.5669,
                        'lon': -46.6842,
                      },
                      {
                        'name': 'Oscar Freire',
                        'lat': -23.5616,
                        'lon': -46.6725,
                      },
                      {'name': 'Paulista', 'lat': -23.5558, 'lon': -46.6609},
                      {
                        'name': 'Higienópolis-Mackenzie',
                        'lat': -23.5482,
                        'lon': -46.6525,
                      },
                    ],
                  },
                  {
                    'mode': 'SUBWAY',
                    'from': {
                      'name': 'República',
                      'lat': -23.5448,
                      'lon': -46.6427,
                    },
                    'to': {'name': 'Luz', 'lat': -23.5364, 'lon': -46.6338},
                    'duration': 180,
                    'displayName': 'METRÔ L1',
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '{"success":true,"data":[]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(AcessaMetroApp(api: ApiService(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar sem conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotas'));
    await tester.pumpAndSettle();

    final stationSelectors = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Digite para buscar estação ou linha',
    );
    await tester.enterText(stationSelectors.first, 'Pinheiros');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pinheiros').last);
    await tester.pumpAndSettle();
    await tester.enterText(stationSelectors.last, 'Luz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar trajeto'));
    await tester.pumpAndSettle();

    expect(find.text('Resultado da rota'), findsOneWidget);
    expect(find.text('Percurso'), findsOneWidget);
    expect(find.text('Acessibilidade'), findsOneWidget);
    expect(find.text('Duração estimada: 18 min'), findsOneWidget);
    expect(find.text('Pinheiros'), findsWidgets);
    expect(find.text('Faria Lima'), findsOneWidget);
    expect(find.text('Fradique Coutinho'), findsOneWidget);
    expect(find.text('Oscar Freire'), findsOneWidget);
    expect(find.text('Paulista'), findsWidgets);
    expect(find.text('Higienópolis-Mackenzie'), findsOneWidget);
    expect(find.text('República'), findsOneWidget);
    expect(find.text('Luz'), findsWidgets);
    expect(find.text('Embarque · METRÔ L4'), findsOneWidget);
    expect(find.text('Baldeação · METRÔ L4'), findsOneWidget);
    expect(find.text('Desembarque · METRÔ L1'), findsOneWidget);
    expect(find.textContaining('Transitous'), findsOneWidget);

    await tester.tap(find.text('Acessibilidade'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'A API ainda não informou recursos de acessibilidade',
      ),
      findsNWidgets(2),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver estações no mapa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('8 estações do trajeto'), findsOneWidget);
    expect(find.byTooltip('Estação Jabaquara'), findsNothing);
  });
}

class _RecordingAccessibilityNotifications
    implements AccessibilityNotificationService {
  String? stationId;
  String? stationName;
  List<Map<String, dynamic>> incidents = [];

  @override
  Future<bool> notifyStationIssues({
    required String stationId,
    required String stationName,
    required List<Map<String, dynamic>> incidents,
  }) async {
    this.stationId = stationId;
    this.stationName = stationName;
    this.incidents = incidents;
    return true;
  }
}

class _FakePushTokenProvider implements PushTokenProvider {
  _FakePushTokenProvider(this.token);

  final String token;

  @override
  Future<String?> initialize({
    required void Function(String token) onTokenRefresh,
  }) async => token;

  @override
  Future<void> dispose() async {}
}
