import 'package:flutter/material.dart';

import '../api/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onNavigate});
  final ApiService api;
  final ValueChanged<int> onNavigate;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Object>> _summary;

  Future<List<Object>> _load() => Future.wait<Object>([
    widget.api.getStations(),
    widget.api.getIncidents(),
  ]);

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.api.currentUser?['name'] as String?;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _summary = _load());
        await _summary;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0868E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.train_rounded, color: Colors.white),
              ),
              const SizedBox(width: 11),
              const Text(
                'AcessaMetrô',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF132640),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF102C49), Color(0xFF15578A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8E8D2).withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MOBILIDADE COM AUTONOMIA',
                    style: TextStyle(
                      color: Color(0xFFB8E8D2),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  name == null
                      ? 'Seu caminho,\nmais acessível.'
                      : 'Olá, ${name.split(' ').first}.\nVamos por onde?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Informação da comunidade para planejar melhor cada trajeto.',
                  style: TextStyle(
                    color: Color(0xFFD0E0EC),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 21),
                FilledButton.icon(
                  onPressed: () => widget.onNavigate(1),
                  icon: const Icon(Icons.search, size: 19),
                  label: const Text('Explorar estações'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB8E8D2),
                    foregroundColor: const Color(0xFF102C49),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Rede em foco',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Object>>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final message = snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Não foi possível carregar os dados.';
                return _SummaryMessage(
                  message: message,
                  retry: () => setState(() => _summary = _load()),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final stations = snapshot.data![0] as List<Map<String, dynamic>>;
              final incidents = snapshot.data![1] as List<Map<String, dynamic>>;
              final active = incidents
                  .where(
                    (item) =>
                        item['status'] != 'RESOLVED' &&
                        item['status'] != 'REJECTED',
                  )
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.location_on_outlined,
                      value: '${stations.length}',
                      label: 'estações',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      icon: Icons.campaign_outlined,
                      value: '$active',
                      label: 'relatos ativos',
                      green: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          const Text(
            'Acesso rápido',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: () => widget.onNavigate(2),
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0D7),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFFA96106),
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relatar um problema',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF132640),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Ajude outras pessoas no caminho',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    this.green = false,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool green;
  @override
  Widget build(BuildContext context) => Container(
    height: 116,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          icon,
          color: green ? const Color(0xFF13785C) : const Color(0xFF0868E8),
          size: 21,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF132640),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryMessage extends StatelessWidget {
  const _SummaryMessage({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_outlined, color: Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        IconButton(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tentar novamente',
        ),
      ],
    ),
  );
}
