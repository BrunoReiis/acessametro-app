import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/push_notifications.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, PushTokenProvider? pushTokenProvider})
    : _client = client ?? http.Client(),
      _pushTokenProvider = pushTokenProvider ?? FirebasePushTokenProvider();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://acessametro-api.vercel.app/api',
  );
  static const _tokenKey = 'access_token';
  static const _favoritesKey = 'favorite_station_ids';
  static const _storage = FlutterSecureStorage();
  final http.Client _client;
  final PushTokenProvider _pushTokenProvider;
  final Map<String, Map<String, double>> _coordinateCache = {};
  String? token;
  Map<String, dynamic>? currentUser;
  String? _pushToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<void> restoreSession() async {
    token = await _storage.read(key: _tokenKey);
    if (token == null) return;
    try {
      final response = await _send('GET', '/auth/me');
      currentUser = _map(response['data']);
      await _initializePushNotifications();
    } on ApiException {
      await logout();
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _saveSession(response);
  }

  Future<void> register(String name, String email, String password) async {
    final response = await _send(
      'POST',
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      authenticated: false,
    );
    await _saveSession(response);
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    token = response['token'] as String?;
    currentUser = _map(response['user']);
    if (token == null) {
      throw const ApiException('A API não retornou um token válido.');
    }
    await _storage.write(key: _tokenKey, value: token!);
    await _initializePushNotifications();
  }

  Future<void> logout() async {
    final pushToken = _pushToken;
    if (pushToken != null && token != null) {
      try {
        await _send(
          'DELETE',
          '/notifications/device',
          body: {'token': pushToken},
        );
      } on ApiException catch (error) {
        debugPrint('Could not unregister push device: ${error.message}');
      }
    }
    token = null;
    currentUser = null;
    _pushToken = null;
    await _pushTokenProvider.dispose();
    await _storage.delete(key: _tokenKey);
  }

  Future<void> _initializePushNotifications() async {
    if (token == null) return;
    try {
      _pushToken = await _pushTokenProvider.initialize(
        onTokenRefresh: (refreshedToken) {
          _pushToken = refreshedToken;
          unawaited(_syncPushDevice(refreshedToken));
        },
      );
      final pushToken = _pushToken;
      if (pushToken != null) await _syncPushDevice(pushToken);
    } on Exception catch (error) {
      debugPrint('Could not initialize push notifications: $error');
    }
  }

  Future<void> _syncPushDevice(String pushToken) async {
    if (token == null) return;
    try {
      await _send(
        'PUT',
        '/notifications/device',
        body: {
          'token': pushToken,
          'stationIds': (await getFavoriteStationIds()).toList(),
        },
      );
    } on ApiException catch (error) {
      debugPrint('Could not sync push device: ${error.message}');
    }
  }

  Future<List<Map<String, dynamic>>> getStations({String search = ''}) async {
    final response = await _send(
      'GET',
      '/stations',
      query: search.isEmpty ? null : {'search': search},
    );
    return _list(response['data']);
  }

  Future<Map<String, dynamic>> getTransitRoute({
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
  }) async {
    Future<Map<String, double>> coordinatesFor(
      Map<String, dynamic> station,
    ) async {
      final latitude = station['latitude'];
      final longitude = station['longitude'];
      if (latitude is num &&
          longitude is num &&
          latitude != 0 &&
          longitude != 0) {
        return {
          'latitude': latitude.toDouble(),
          'longitude': longitude.toDouble(),
        };
      }

      final coordinates = await geocodeStation(station);
      if (coordinates == null) {
        throw ApiException(
          'Não foi possível localizar a estação ${station['name'] ?? ''}.',
        );
      }
      return coordinates;
    }

    final originCoordinates = await coordinatesFor(origin);
    final destinationCoordinates = await coordinatesFor(destination);
    try {
      final response = await _send(
        'POST',
        '/routes/transit',
        body: {
          'originId': origin['id'],
          'destinationId': destination['id'],
          'origin': originCoordinates,
          'destination': destinationCoordinates,
        },
      );
      return _map(response['data']);
    } on ApiException catch (error) {
      if (!error.message.startsWith(
        'Rota não encontrada: POST /api/routes/transit',
      )) {
        rethrow;
      }

      final uri = Uri.https('api.transitous.org', '/api/v6/plan', {
        'fromPlace':
            '${originCoordinates['latitude']},${originCoordinates['longitude']}',
        'toPlace':
            '${destinationCoordinates['latitude']},${destinationCoordinates['longitude']}',
        'numItineraries': '3',
        'transitModes': 'SUBWAY,SUBURBAN',
      });
      late final http.Response transitResponse;
      try {
        transitResponse = await _client.get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (!kIsWeb)
              'User-Agent':
                  'AcessaMetroApp/1.0 (https://acessametro-api.vercel.app)',
          },
        );
      } on Exception {
        throw const ApiException(
          'Não foi possível conectar ao serviço de rotas Transitous.',
        );
      }

      if (transitResponse.statusCode < 200 ||
          transitResponse.statusCode >= 300) {
        throw ApiException(
          'O serviço de rotas Transitous respondeu '
          'com erro (${transitResponse.statusCode}).',
        );
      }
      try {
        return _map(jsonDecode(transitResponse.body));
      } on FormatException {
        throw const ApiException(
          'O serviço de rotas Transitous retornou uma resposta inválida.',
        );
      }
    }
  }

  Future<Map<String, double>?> geocodeStation(
    Map<String, dynamic> station,
  ) async {
    final latitude = station['latitude'];
    final longitude = station['longitude'];
    if (latitude is num &&
        longitude is num &&
        latitude != 0 &&
        longitude != 0) {
      return {
        'latitude': latitude.toDouble(),
        'longitude': longitude.toDouble(),
      };
    }

    final name = station['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;
    final cacheKey = station['id'] as String? ?? name;
    if (_coordinateCache.containsKey(cacheKey)) {
      return _coordinateCache[cacheKey];
    }

    final queryName = name.replaceFirst(
      RegExp(r'^estação\s+', caseSensitive: false),
      '',
    );
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': '$queryName, São Paulo, Brasil',
      'limit': '10',
    });
    try {
      final response = await _client.get(
        uri,
        headers: const {'User-Agent': 'AcessaMetroApp/1.0'},
      );
      if (response.statusCode != 200) return null;
      final payload = _map(jsonDecode(response.body));
      final features = payload['features'];
      if (features is! List || features.isEmpty) return null;

      String normalize(String value) {
        const replacements = {
          'á': 'a',
          'à': 'a',
          'â': 'a',
          'ã': 'a',
          'ä': 'a',
          'é': 'e',
          'è': 'e',
          'ê': 'e',
          'ë': 'e',
          'í': 'i',
          'ì': 'i',
          'î': 'i',
          'ï': 'i',
          'ó': 'o',
          'ò': 'o',
          'ô': 'o',
          'õ': 'o',
          'ö': 'o',
          'ú': 'u',
          'ù': 'u',
          'û': 'u',
          'ü': 'u',
          'ç': 'c',
        };
        var normalized = value.toLowerCase();
        for (final replacement in replacements.entries) {
          normalized = normalized.replaceAll(
            replacement.key,
            replacement.value,
          );
        }
        return normalized
            .replaceFirst(RegExp(r'^estacao\s+'), '')
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      final expectedName = normalize(queryName);
      final candidates = <({double latitude, double longitude, int rank})>[];
      for (final rawFeature in features) {
        final feature = _map(rawFeature);
        final properties = _map(feature['properties']);
        final featureName = normalize(properties['name'] as String? ?? '');
        final key = properties['osm_key'];
        final value = properties['osm_value'];
        final isStation =
            (key == 'railway' &&
                const {
                  'station',
                  'halt',
                  'stop',
                  'tram_stop',
                  'subway_entrance',
                  'construction',
                }.contains(value)) ||
            (key == 'building' && value == 'train_station') ||
            properties['public_transport'] == 'station';
        final nameMatches =
            featureName == expectedName ||
            (expectedName.length >= 6 && featureName.contains(expectedName));
        if (properties['countrycode'] != 'BR' || !isStation || !nameMatches) {
          continue;
        }
        final geometry = _map(feature['geometry']);
        final coordinates = geometry['coordinates'];
        if (coordinates is! List || coordinates.length < 2) continue;
        final longitudeValue = coordinates[0];
        final latitudeValue = coordinates[1];
        if (longitudeValue is! num || latitudeValue is! num) continue;
        final latitude = latitudeValue.toDouble();
        final longitude = longitudeValue.toDouble();
        if (latitude == 0 ||
            longitude == 0 ||
            latitude < -24.5 ||
            latitude > -22.5 ||
            longitude < -47.8 ||
            longitude > -45) {
          continue;
        }
        final exact = featureName == expectedName;
        final primaryType =
            key == 'railway' &&
            const {'station', 'halt', 'stop', 'tram_stop'}.contains(value);
        candidates.add((
          latitude: latitude,
          longitude: longitude,
          rank: (exact ? 10 : 0) + (primaryType ? 3 : 1),
        ));
      }
      if (candidates.isEmpty) return null;

      final bestRank = candidates
          .map((candidate) => candidate.rank)
          .reduce((a, b) => a > b ? a : b);
      final bestCandidates = candidates
          .where((candidate) => candidate.rank == bestRank)
          .toList();
      final result = {
        'latitude':
            bestCandidates
                .map((candidate) => candidate.latitude)
                .reduce((a, b) => a + b) /
            bestCandidates.length,
        'longitude':
            bestCandidates
                .map((candidate) => candidate.longitude)
                .reduce((a, b) => a + b) /
            bestCandidates.length,
      };
      for (final candidate in bestCandidates) {
        final northSouthKm = (candidate.latitude - result['latitude']!) * 111;
        final eastWestKm =
            (candidate.longitude - result['longitude']!) * 111 * 0.92;
        if (northSouthKm * northSouthKm + eastWestKm * eastWestKm >
            0.75 * 0.75) {
          return null;
        }
      }
      _coordinateCache[cacheKey] = result;
      return result;
    } on Exception {
      return null;
    }
  }

  Future<Map<String, dynamic>> getStation(String id) async =>
      _map((await _send('GET', '/stations/$id'))['data']);

  Future<List<Map<String, dynamic>>> getIncidents() async =>
      _list((await _send('GET', '/incidents'))['data']);

  Future<void> updateIncidentStatus({
    required String incidentId,
    required String status,
  }) async {
    await _send(
      'PATCH',
      '/incidents/$incidentId/status',
      body: {'status': status},
    );
  }

  Future<List<Map<String, dynamic>>> getReviews() async =>
      _list((await _send('GET', '/reviews'))['data']);

  Future<void> createIncident({
    required String title,
    required String description,
    required String category,
    required String stationId,
  }) async {
    await _send(
      'POST',
      '/incidents',
      body: {
        'title': title,
        'description': description,
        'category': category,
        'stationId': stationId,
      },
    );
  }

  Future<void> createReview({
    required String stationId,
    required int rating,
    String? comment,
  }) async {
    await _send(
      'POST',
      '/reviews',
      body: {
        'stationId': stationId,
        'rating': rating,
        'comment': comment,
        'tags': <String>[],
      },
    );
  }

  Future<Set<String>> getFavoriteStationIds() async {
    final encoded = await _storage.read(key: _favoritesKey);
    if (encoded == null) return <String>{};
    try {
      return (jsonDecode(encoded) as List).whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<Set<String>> toggleFavoriteStation(String stationId) async {
    final favorites = await getFavoriteStationIds();
    if (!favorites.add(stationId)) favorites.remove(stationId);
    await _storage.write(
      key: _favoritesKey,
      value: jsonEncode(favorites.toList()),
    );
    final pushToken = _pushToken;
    if (pushToken != null) await _syncPushDevice(pushToken);
    return favorites;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    late final http.Response response;
    try {
      final uri = _uri(path, query);
      switch (method) {
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
        case 'PUT':
          response = await _client.put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
        default:
          response = await _client.get(uri, headers: headers);
      }
    } on Exception {
      throw const ApiException(
        'Não foi possível conectar à API. Verifique o endereço e tente novamente.',
      );
    }
    Map<String, dynamic> payload;
    try {
      payload = _map(jsonDecode(response.body));
    } on FormatException {
      throw ApiException('Resposta inválida da API (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        payload['message'] as String? ?? 'Erro ao comunicar com a API.',
      );
    }
    return payload;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(Object? value) =>
      value is List ? value.map(_map).toList() : const [];
}
