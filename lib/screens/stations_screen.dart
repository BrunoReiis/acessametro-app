import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_service.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<Map<String, dynamic>>> _stations;
  @override
  void initState() {
    super.initState();
    _stations = widget.api.getStations();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchStations(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(
          () => _stations = widget.api.getStations(search: value.trim()),
        );
      }
    });
  }

  Future<void> _details(Map<String, dynamic> station) async {
    try {
      final details = await widget.api.getStation(station['id'] as String);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _StationDetails(station: details),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
    children: [
      const Text(
        'Estações',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: Color(0xFF132640),
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Encontre informações de acessibilidade',
        style: TextStyle(color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 19),
      TextField(
        controller: _search,
        onChanged: _searchStations,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar estação ou linha',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          suffixIcon: IconButton(
            tooltip: 'Limpar busca',
            onPressed: () {
              _search.clear();
              _searchStations('');
            },
            icon: const Icon(Icons.close, size: 19),
          ),
        ),
      ),
      const SizedBox(height: 15),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _stations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Não foi possível carregar as estações.';
            return _LoadMessage(
              message: message,
              retry: () => setState(
                () => _stations = widget.api.getStations(
                  search: _search.text.trim(),
                ),
              ),
            );
          }
          final stations = snapshot.data ?? [];
          if (stations.isEmpty) {
            return const _LoadMessage(message: 'Nenhuma estação encontrada.');
          }
          return Column(
            children: [
              for (final station in stations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StationTile(
                    station: station,
                    onTap: () => _details(station),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _StationTile extends StatelessWidget {
  const _StationTile({required this.station, required this.onTap});
  final Map<String, dynamic> station;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final line = station['line'] as String?;
    final zone = station['zone'] as String?;
    final accessibility = station['accessibility'] as String?;
    final detail = [
      line,
      zone,
    ].where((value) => value != null && value.isNotEmpty).join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.train_outlined,
                  color: Color(0xFF0868E8),
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station['name'] as String? ?? 'Estação',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF132640),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail.isEmpty ? 'Informações da estação' : detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (accessibility != null && accessibility.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        accessibility,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFF34705D),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationDetails extends StatelessWidget {
  const _StationDetails({required this.station});
  final Map<String, dynamic> station;
  @override
  Widget build(BuildContext context) {
    final reviews = station['reviews'] is List
        ? station['reviews'] as List
        : const [];
    final incidents = station['incidents'] is List
        ? station['incidents'] as List
        : const [];
    final ratings = reviews
        .map((review) => (review as Map)['rating'])
        .whereType<num>()
        .toList();
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;
    final routeInfo = [
      station['line'],
      station['zone'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station['name'] as String? ?? 'Estação',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF132640),
              ),
            ),
            const SizedBox(height: 5),
            Text(routeInfo, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.accessible_forward,
              title: 'Acessibilidade',
              detail:
                  station['accessibility'] as String? ??
                  'Ainda sem informações registradas.',
            ),
            const SizedBox(height: 15),
            _DetailRow(
              icon: Icons.star_outline,
              title: 'Avaliação',
              detail: average == null
                  ? 'Sem avaliações'
                  : '${average.toStringAsFixed(1)} de 5 · ${ratings.length} avaliações',
            ),
            const SizedBox(height: 15),
            _DetailRow(
              icon: Icons.campaign_outlined,
              title: 'Relatos',
              detail: '${incidents.length} ocorrências registradas',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF0868E8)),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LoadMessage extends StatelessWidget {
  const _LoadMessage({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
    child: Column(
      children: [
        const Icon(Icons.train_outlined, size: 34, color: Color(0xFF94A3B8)),
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
