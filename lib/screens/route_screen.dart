import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_service.dart';

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
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _stations = widget.api.getStations();
  }

  void _showRoute(List<Map<String, dynamic>> stations) {
    if (_originId == null ||
        _destinationId == null ||
        _originId == _destinationId) {
      return;
    }
    _origin = stations.firstWhere((station) => station['id'] == _originId);
    _destination = stations.firstWhere(
      (station) => station['id'] == _destinationId,
    );
    final label = '${_origin?['name']} → ${_destination?['name']}';
    setState(() {
      _recent.remove(label);
      _recent.insert(0, label);
      if (_recent.length > 3) _recent.removeLast();
    });
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
                onChanged: (value) => setState(() {
                  _originId = value;
                  _origin = null;
                }),
              ),
              const SizedBox(height: 13),
              _StationSelector(
                label: 'Estação de destino',
                value: _destinationId,
                stations: stations,
                onChanged: (value) => setState(() {
                  _destinationId = value;
                  _destination = null;
                }),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _originId == null ||
                        _destinationId == null ||
                        _originId == _destinationId
                    ? null
                    : () => _showRoute(stations),
                icon: const Icon(Icons.alt_route),
                label: const Text('Mostrar trajeto'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_origin != null && _destination != null) ...[
                const SizedBox(height: 21),
                _RouteResult(
                  origin: _origin!,
                  destination: _destination!,
                  onMap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NetworkMapScreen(
                        api: widget.api,
                        focusStations: [_origin!, _destination!],
                      ),
                    ),
                  ),
                ),
              ],
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 25),
                const Text(
                  'Rotas recentes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF132640),
                  ),
                ),
                const SizedBox(height: 9),
                for (final item in _recent)
                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF0868E8),
                    ),
                    title: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<Map<String, dynamic>> stations;
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
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Selecione uma estação'),
        items: stations
            .map(
              (station) => DropdownMenuItem(
                value: station['id'] as String,
                child: Text(
                  station['name'] as String? ?? 'Estação',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _RouteResult extends StatelessWidget {
  const _RouteResult({
    required this.origin,
    required this.destination,
    required this.onMap,
  });
  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final originLine = origin['line'] as String?;
    final destinationLine = destination['line'] as String?;
    final sameLine = originLine != null && originLine == destinationLine;
    final stations = [origin, destination];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Seu percurso',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF132640),
          ),
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            children: [
              for (var index = 0; index < stations.length; index++) ...[
                if (index == 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 11),
                        child: Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      index == 0 ? Icons.trip_origin : Icons.location_on,
                      color: index == 0
                          ? const Color(0xFF0868E8)
                          : const Color(0xFF138361),
                      size: 21,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stations[index]['name'] as String? ?? 'Estação',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF132640),
                            ),
                          ),
                          Text(
                            stations[index]['line'] as String? ??
                                'Linha não informada',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  sameLine
                      ? 'Mesma linha cadastrada. A sequência e o tempo não estão disponíveis.'
                      : 'A API ainda não informa conexões ou tempo entre linhas.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        OutlinedButton.icon(
          onPressed: onMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Ver no mapa'),
        ),
      ],
    );
  }
}

class NetworkMapScreen extends StatefulWidget {
  const NetworkMapScreen({
    super.key,
    required this.api,
    this.focusStations = const [],
  });
  final ApiService api;
  final List<Map<String, dynamic>> focusStations;
  @override
  State<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends State<NetworkMapScreen> {
  late Future<List<Map<String, dynamic>>> _stations;
  @override
  void initState() {
    super.initState();
    _stations = widget.api.getStations();
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
                'Ainda não há coordenadas cadastradas para exibir as estações no mapa.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final first = points.first;
        final focusIds = widget.focusStations
            .map((station) => station['id'])
            .toSet();
        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    (first['latitude'] as num).toDouble(),
                    (first['longitude'] as num).toDouble(),
                  ),
                  initialZoom: points.length == 1 ? 14 : 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.acessametro.acessametro_app',
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
                '${points.length} estações com localização · A linha do trajeto não é calculada pela API.',
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
