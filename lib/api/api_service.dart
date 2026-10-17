import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://acessametro-api.vercel.app/api',
  );
  static const _tokenKey = 'access_token';
  static const _favoritesKey = 'favorite_station_ids';
  static const _storage = FlutterSecureStorage();
  final http.Client _client;
  String? token;
  Map<String, dynamic>? currentUser;

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
  }

  Future<void> logout() async {
    token = null;
    currentUser = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<List<Map<String, dynamic>>> getStations({String search = ''}) async {
    final response = await _send(
      'GET',
      '/stations',
      query: search.isEmpty ? null : {'search': search},
    );
    return _list(response['data']);
  }

  Future<Map<String, dynamic>> getStation(String id) async =>
      _map((await _send('GET', '/stations/$id'))['data']);

  Future<List<Map<String, dynamic>>> getIncidents() async =>
      _list((await _send('GET', '/incidents'))['data']);

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
      response = method == 'POST'
          ? await _client.post(uri, headers: headers, body: jsonEncode(body))
          : await _client.get(uri, headers: headers);
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
