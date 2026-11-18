import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../utils/accessibility_data.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late Future<List<Map<String, dynamic>>> _stations;
  String? _originId;
  String? _destinationId;
  Map<String, dynamic>? _origin;
  Map<String, dynamic>? _destination;
  Map<String, dynamic>? _route;
  String? _routeError;
  bool _isLoadingRoute = false;
  bool _originInputMatchesSelection = true;
  bool _destinationInputMatchesSelection = true;
  int _routeRequestId = 0;
  final List<({String label, String originId, String destinationId})> _recent =
      [];

  @override
  void initState() {
    super.initState();
    _stations = widget.api.getStations();
  }

  Future<void> _showRoute(List<Map<String, dynamic>> stations) async {
    if (_originId == null ||
        _destinationId == null ||
        _originId == _destinationId) {
      return;
    }
    final origin = stations.firstWhere((station) => station['id'] == _originId);
    final destination = stations.firstWhere(
      (station) => station['id'] == _destinationId,
    );
    final originId = _originId!;
    final destinationId = _destinationId!;
    final requestId = ++_routeRequestId;
    final label = '${origin['name']} → ${destination['name']}';
    setState(() {
      _origin = origin;
      _destination = destination;
      _route = null;
      _routeError = null;
      _isLoadingRoute = true;
      _recent.removeWhere((item) => item.label == label);
      _recent.insert(0, (
        label: label,
        originId: originId,
        destinationId: destinationId,
      ));
      if (_recent.length > 3) _recent.removeLast();
    });

    try {
      final route = await widget.api.getTransitRoute(
        origin: origin,
        destination: destination,
      );
      if (mounted && requestId == _routeRequestId) {
        setState(() => _route = route);
      }
    } on ApiException catch (error) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _routeError = error.message);
      }
    } catch (_) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _routeError = 'Não foi possível calcular o trajeto.');
      }
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
    children: [
      const Text(
        'Planejar rota',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: Color(0xFF132640),
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Escolha as estações do seu trajeto',
        style: TextStyle(color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 20),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _stations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _RouteMessage(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Não foi possível carregar as estações.',
              retry: () => setState(() => _stations = widget.api.getStations()),
            );
          }
          final stations = snapshot.data ?? [];
          if (stations.length < 2) {
            return const _RouteMessage(
              message:
                  'Cadastre pelo menos duas estações para planejar um trajeto.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StationSelector(
                label: 'Estação de origem',
                value: _originId,
                stations: stations,
                onQueryChanged: (matchesSelection) {
                  if (_originInputMatchesSelection == matchesSelection) return;
                  setState(() {
                    _routeRequestId++;
                    _isLoadingRoute = false;
                    _originInputMatchesSelection = matchesSelection;
                    _origin = null;
                    _destination = null;
                    _route = null;
                    _routeError = null;
                  });
                },
                onChanged: (value) => setState(() {
                  _routeRequestId++;
                  _isLoadingRoute = false;
                  _originId = value;
                  _originInputMatchesSelection = value != null;
                  _origin = null;
                  _route = null;
                  _routeError = null;
                }),
              ),
              const SizedBox(height: 13),
              _StationSelector(
                label: 'Estação de destino',
                value: _destinationId,
                stations: stations,
                onQueryChanged: (matchesSelection) {
                  if (_destinationInputMatchesSelection == matchesSelection) {
                    return;
                  }
                  setState(() {
                    _routeRequestId++;
                    _isLoadingRoute = false;
                    _destinationInputMatchesSelection = matchesSelection;
                    _origin = null;
                    _destination = null;
                    _route = null;
                    _routeError = null;
                  });
                },
                onChanged: (value) => setState(() {
                  _routeRequestId++;
                  _isLoadingRoute = false;
                  _destinationId = value;
                  _destinationInputMatchesSelection = value != null;
                  _destination = null;
                  _route = null;
                  _routeError = null;
                }),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _isLoadingRoute ||
                        !_originInputMatchesSelection ||
                        !_destinationInputMatchesSelection ||
                        _originId == null ||
                        _destinationId == null ||
                        _originId == _destinationId
                    ? null
                    : () => _showRoute(stations),
                icon: _isLoadingRoute
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route),
                label: Text(
                  _isLoadingRoute ? 'Calculando rota...' : 'Mostrar trajeto',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_origin != null && _destination != null) ...[
                const SizedBox(height: 21),
                _RouteResult(
                  origin: _origin!,
                  destination: _destination!,
                  route: _route,
                  isLoading: _isLoadingRoute,
                  errorMessage: _routeError,
                  onRetry: () => _showRoute(stations),
                  onMap: (routeLegs) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NetworkMapScreen(
                        api: widget.api,
                        focusStations: [_origin!, _destination!],
                        routeLegs: routeLegs,
                      ),
                    ),
                  ),
                ),
              ],
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 25),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Rotas recentes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF132640),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_recent.clear),
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                for (final item in _recent)
                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF0868E8),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remover rota recente',
                      onPressed: () => setState(() => _recent.remove(item)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      setState(() {
                        _originId = item.originId;
                        _destinationId = item.destinationId;
                        _originInputMatchesSelection = true;
                        _destinationInputMatchesSelection = true;
                      });
                      _showRoute(stations);
                    },
                  ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _StationSelector extends StatelessWidget {
  const _StationSelector({
    required this.label,
    required this.value,
    required this.stations,
    required this.onQueryChanged,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<Map<String, dynamic>> stations;
  final ValueChanged<bool> onQueryChanged;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF263B53),
        ),
      ),
      const SizedBox(height: 7),
      Autocomplete<Map<String, dynamic>>(
        key: ValueKey('${label}_$value'),
        initialValue: TextEditingValue(
          text:
              stations
                  .where((station) => station['id'] == value)
                  .map((station) => station['name'] as String? ?? '')
                  .firstOrNull ??
              '',
        ),
        displayStringForOption: (station) =>
            station['name'] as String? ?? 'Estação',
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) return const [];
          return stations.where((station) {
            final name = station['name'] as String? ?? '';
            final line = station['line'] as String? ?? '';
            return name.toLowerCase().contains(query) ||
                line.toLowerCase().contains(query);
          });
        },
        onSelected: (station) => onChanged(station['id'] as String),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          final selectedName = stations
              .where((station) => station['id'] == value)
              .map((station) => station['name'] as String? ?? '')
              .firstOrNull;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (query) => onQueryChanged(
              selectedName != null &&
                  query.trim().toLowerCase() ==
                      selectedName.trim().toLowerCase(),
            ),
            decoration: InputDecoration(
              hintText: 'Digite para buscar estação ou linha',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar estação',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged(false);
                      },
                      icon: const Icon(Icons.close, size: 19),
                    ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final station = options.elementAt(index);
                  return ListTile(
                    title: Text(station['name'] as String? ?? 'Estação'),
                    subtitle: station['line'] is String
                        ? Text(station['line'] as String)
                        : null,
                    onTap: () => onSelected(station),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _RouteResult extends StatelessWidget {
  const _RouteResult({
    required this.origin,
    required this.destination,
    required this.route,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onMap,
  });
  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;
  final Map<String, dynamic>? route;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<List<Map<String, dynamic>>> onMap;

  @override
  Widget build(BuildContext context) {
    final stations = [origin, destination];
    final rawItineraries = route?['itineraries'];
    final itineraries = rawItineraries is List
        ? rawItineraries
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : const <Map<String, dynamic>>[];
    final firstItinerary = itineraries.isEmpty ? null : itineraries.first;
    final routeLegs = firstItinerary?['legs'] is List
        ? (firstItinerary!['legs'] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .where(
                (leg) => const {'SUBWAY', 'SUBURBAN'}.contains(leg['mode']),
              )
              .toList()
        : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Resultado da rota',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF132640),
          ),
        ),
        const SizedBox(height: 8),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Color(0xFF0868E8),
                unselectedLabelColor: Color(0xFF64748B),
                tabs: [
                  Tab(text: 'Percurso'),
                  Tab(text: 'Acessibilidade'),
                ],
              ),
              SizedBox(
                height: 300,
                child: TabBarView(
                  children: [
                    _RoutePathTab(
                      itineraries: itineraries,
                      isLoading: isLoading,
                      errorMessage: errorMessage,
                      onRetry: onRetry,
                    ),
                    _RouteAccessibilityTab(stations: stations),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: routeLegs.isEmpty ? null : () => onMap(routeLegs),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Ver estações no mapa'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse('https://transitous.org/sources/')),
                child: const Text('Dados de transporte: Transitous'),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Text('Mapa: OpenStreetMap'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutePathTab extends StatelessWidget {
  const _RoutePathTab({
    required this.itineraries,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });
  final List<Map<String, dynamic>> itineraries;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (itineraries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nenhum itinerário de transporte público foi encontrado para este trajeto e horário.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final itinerary = itineraries.first;
    final durationSeconds = itinerary['duration'];
    final durationMinutes = durationSeconds is num
        ? (durationSeconds / 60).ceil()
        : null;
    final legs = itinerary['legs'] is List
        ? (itinerary['legs'] as List).whereType<Map>().toList()
        : const <Map>[];
    final transitLegs = legs
        .map(Map<String, dynamic>.from)
        .where((leg) => const {'SUBWAY', 'SUBURBAN'}.contains(leg['mode']))
        .toList();
    final stops = _buildStationSequence(transitLegs);
    if (stops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nenhum trajeto de metrô ou trem foi encontrado para este horário.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (durationMinutes != null) ...[
                Text(
                  'Duração estimada: $durationMinutes min',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF132640),
                  ),
                ),
                if (itinerary['transfers'] is num)
                  Text(
                    '${itinerary['transfers']} baldeações',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                const Divider(height: 24),
              ],
              for (var index = 0; index < stops.length; index++)
                _StationSequenceTile(
                  index: index + 1,
                  station: stops[index],
                  isLast: index == stops.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StationSequenceTile extends StatelessWidget {
  const _StationSequenceTile({
    required this.index,
    required this.station,
    required this.isLast,
  });
  final int index;
  final ({String name, String note}) station;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFFFF1C2),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 22,
                    color: const Color(0xFFFFC43D),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF132640),
                    ),
                  ),
                  if (station.note.isNotEmpty)
                    Text(
                      station.note,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<({String name, String note})> _buildStationSequence(
  List<Map<String, dynamic>> transitLegs,
) {
  final stops = <({String name, String note})>[];
  for (var legIndex = 0; legIndex < transitLegs.length; legIndex++) {
    final leg = transitLegs[legIndex];
    final from = _asMap(leg['from'])['name'] as String?;
    final to = _asMap(leg['to'])['name'] as String?;
    final line =
        leg['displayName'] as String? ??
        leg['routeShortName'] as String? ??
        leg['routeLongName'] as String? ??
        _transitModeLabel(leg['mode'] as String?);
    final intermediateStops = leg['intermediateStops'];
    final names = <String>[
      if (from != null && from.isNotEmpty) from,
      if (intermediateStops is List)
        for (final stop in intermediateStops)
          if (_asMap(stop)['name'] is String &&
              (_asMap(stop)['name'] as String).isNotEmpty)
            _asMap(stop)['name'] as String,
      if (to != null && to.isNotEmpty) to,
    ];

    for (var stopIndex = 0; stopIndex < names.length; stopIndex++) {
      final name = names[stopIndex];
      if (stops.isNotEmpty && stops.last.name == name) {
        continue;
      }

      final isBoarding = stopIndex == 0 && stops.isEmpty;
      final isLastStop = stopIndex == names.length - 1;
      final isTransfer = isLastStop && legIndex < transitLegs.length - 1;
      final note = isBoarding
          ? 'Embarque · $line'
          : isTransfer
          ? 'Baldeação · $line'
          : isLastStop
          ? 'Desembarque · $line'
          : '';
      stops.add((name: name, note: note));
    }
  }
  return stops;
}

String _transitModeLabel(String? mode) => switch (mode) {
  'SUBWAY' => 'Metrô',
  'SUBURBAN' => 'Trem',
  _ => 'Transporte público',
};

Polyline? _routePolyline(Map<String, dynamic> leg) {
  final geometry = _asMap(leg['legGeometry']);
  final encoded = geometry['points'];
  final precision = geometry['precision'];
  if (encoded is! String || precision is! num || precision <= 0) return null;

  final points = _decodeTransitousPolyline(encoded, precision.toInt());
  if (points.length < 2) return null;

  final colorValue = leg['routeColor'] as String?;
  final color =
      colorValue != null && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(colorValue)
      ? Color(int.parse('FF$colorValue', radix: 16))
      : const Color(0xFF0868E8);
  return Polyline(points: points, color: color, strokeWidth: 5);
}

List<LatLng> _decodeTransitousPolyline(String encoded, int precision) {
  if (precision < 1 || precision > 8) return const [];
  final factor = _pow10(precision);
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  final points = <LatLng>[];

  int decodeValue() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('Invalid encoded polyline');
      }
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('Invalid encoded polyline');
      }
      result |= (value & 0x1f) << shift;
      shift += 5;
      if (value < 0x20) break;
    }
    return (result & 1) == 1 ? ~(result >> 1) : result >> 1;
  }

  try {
    while (index < encoded.length) {
      latitude += decodeValue();
      longitude += decodeValue();
      final latitudeDegrees = latitude / factor;
      final longitudeDegrees = longitude / factor;
      if (latitudeDegrees < -24.5 ||
          latitudeDegrees > -22.5 ||
          longitudeDegrees < -47.8 ||
          longitudeDegrees > -45) {
        return const [];
      }
      points.add(LatLng(latitudeDegrees, longitudeDegrees));
    }
  } on FormatException {
    return const [];
  }
  return points;
}

int _pow10(int exponent) {
  var value = 1;
  for (var index = 0; index < exponent; index++) {
    value *= 10;
  }
  return value;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class _RouteAccessibilityTab extends StatelessWidget {
  const _RouteAccessibilityTab({required this.stations});
  final List<Map<String, dynamic>> stations;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: 10),
    children: [
      for (final station in stations)
        _RouteStationAccessibility(station: station),
    ],
  );
}

class _RouteStationAccessibility extends StatelessWidget {
  const _RouteStationAccessibility({required this.station});
  final Map<String, dynamic> station;

  @override
  Widget build(BuildContext context) {
    final features = parseAccessibilityFeatures(station['accessibility']);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station['name'] as String? ?? 'Estação',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            station['line'] as String? ?? 'Linha não informada',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          if (features.isEmpty)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF9A6200)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A API ainda não informou recursos de acessibilidade para esta estação.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            const Text(
              'Os mesmos valores foram cadastrados para todas as estações e '
              'não foram verificados individualmente.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final feature in features)
                  Chip(
                    avatar: const Icon(
                      Icons.accessible_forward,
                      size: 16,
                      color: Color(0xFF13785C),
                    ),
                    label: Text(feature),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class NetworkMapScreen extends StatefulWidget {
  const NetworkMapScreen({
    super.key,
    required this.api,
    this.focusStations = const [],
    this.routeLegs = const [],
  });
  final ApiService api;
  final List<Map<String, dynamic>> focusStations;
  final List<Map<String, dynamic>> routeLegs;
  @override
  State<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends State<NetworkMapScreen> {
  late Future<List<Map<String, dynamic>>> _stations;

  @override
  void initState() {
    super.initState();
    _stations = _loadStations();
  }

  Future<List<Map<String, dynamic>>> _loadStations() async {
    final stations = await widget.api.getStations();
    final routeStops = <Map<String, dynamic>>[];
    if (widget.focusStations.isNotEmpty) {
      routeStops.add(widget.focusStations.first);
    }

    for (final leg in widget.routeLegs) {
      final from = _asMap(leg['from']);
      if (from.isNotEmpty) routeStops.add(_mapStop(from));
      final intermediateStops = leg['intermediateStops'];
      if (intermediateStops is List) {
        for (final stop in intermediateStops) {
          final map = _asMap(stop);
          if (map.isNotEmpty) routeStops.add(_mapStop(map));
        }
      }
      final to = _asMap(leg['to']);
      if (to.isNotEmpty) routeStops.add(_mapStop(to));
    }
    if (widget.focusStations.length > 1) {
      routeStops.add(widget.focusStations.last);
    }

    final uniqueStops = <Map<String, dynamic>>[];
    final seenNames = <String>{};
    for (final stop in routeStops) {
      final name = stop['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final normalizedName = _normalizeStationName(name);
      if (!seenNames.add(normalizedName)) continue;

      final matchingStation = stations.where(
        (station) =>
            _normalizeStationName(station['name'] as String? ?? '') ==
            normalizedName,
      );
      final station = matchingStation.firstOrNull;
      final preferred = station != null && _hasCoordinates(station)
          ? station
          : stop;
      Map<String, dynamic> withCoordinates = preferred;
      if (!_hasCoordinates(preferred)) {
        final coordinates = await widget.api.geocodeStation(preferred);
        if (coordinates == null) continue;
        withCoordinates = {...preferred, ...coordinates};
      }
      if (_hasCoordinates(withCoordinates)) uniqueStops.add(withCoordinates);
    }
    return uniqueStops;
  }

  Map<String, dynamic> _mapStop(Map<String, dynamic> stop) => {
    'id': stop['stopId'] as String? ?? stop['name'] as String?,
    'name': stop['name'],
    'latitude': stop['lat'],
    'longitude': stop['lon'],
  };

  String _normalizeStationName(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^esta[cç][aã]o\s+', caseSensitive: false), '')
      .toLowerCase();

  bool _hasCoordinates(Map<String, dynamic> station) {
    final latitude = station['latitude'];
    final longitude = station['longitude'];
    return latitude is num &&
        longitude is num &&
        latitude != 0 &&
        longitude != 0 &&
        latitude >= -24.5 &&
        latitude <= -22.5 &&
        longitude >= -47.8 &&
        longitude <= -45;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mapa das estações')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _stations,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Falha ao carregar o mapa.',
            ),
          );
        }
        final stations = snapshot.data!;
        final points = stations
            .where(
              (station) =>
                  station['latitude'] is num && station['longitude'] is num,
            )
            .toList();
        if (points.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Não foi possível obter coordenadas confiáveis para as estações selecionadas.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final focusIds = widget.focusStations
            .map((station) => station['id'])
            .toSet();
        final focusedPoints = points
            .where((station) => focusIds.contains(station['id']))
            .toList();
        final centerPoints = focusedPoints.isEmpty ? points : focusedPoints;
        final center = LatLng(
          centerPoints
                  .map((station) => (station['latitude'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              centerPoints.length,
          centerPoints
                  .map((station) => (station['longitude'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              centerPoints.length,
        );
        final routePoints = <LatLng>[
          ...points.map(
            (station) => LatLng(
              (station['latitude'] as num).toDouble(),
              (station['longitude'] as num).toDouble(),
            ),
          ),
          for (final leg in widget.routeLegs) ...?_routePolyline(leg)?.points,
        ];
        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  initialCameraFit: routePoints.length > 1
                      ? CameraFit.coordinates(
                          coordinates: routePoints,
                          padding: const EdgeInsets.all(48),
                          maxZoom: 15,
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.acessametro.acessametro_app',
                  ),
                  if (widget.routeLegs.isNotEmpty)
                    PolylineLayer(
                      polylines: widget.routeLegs
                          .map(_routePolyline)
                          .whereType<Polyline>()
                          .toList(),
                    ),
                  MarkerLayer(
                    markers: points.map((station) {
                      final isFocused = focusIds.contains(station['id']);
                      return Marker(
                        point: LatLng(
                          (station['latitude'] as num).toDouble(),
                          (station['longitude'] as num).toDouble(),
                        ),
                        width: 48,
                        height: 56,
                        child: Tooltip(
                          message: station['name'] as String? ?? 'Estação',
                          child: Icon(
                            Icons.location_on,
                            size: 43,
                            color: isFocused
                                ? const Color(0xFF138361)
                                : const Color(0xFF0868E8),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                      TextSourceAttribution('Transitous'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              color: Colors.white,
              child: Text(
                '${points.length} estações do trajeto · Toque e arraste para explorar o mapa.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 16),
    child: Column(
      children: [
        const Icon(Icons.alt_route, size: 35, color: Color(0xFF94A3B8)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
      ],
    ),
  );
}
