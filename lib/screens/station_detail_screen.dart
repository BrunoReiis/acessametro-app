import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../services/accessibility_notifications.dart';
import '../utils/accessibility_data.dart';
import 'account_screen.dart';
import 'incidents_screen.dart';
import 'route_screen.dart';

class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.notifications,
  });
  final ApiService api;
  final String stationId;
  final AccessibilityNotificationService? notifications;

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  late Future<Map<String, dynamic>> _station;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _station = widget.api.getStation(widget.stationId);
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final favorites = await widget.api.getFavoriteStationIds();
    if (mounted) {
      setState(() => _favorite = favorites.contains(widget.stationId));
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final favorites = await widget.api.toggleFavoriteStation(
        widget.stationId,
      );
      final added = favorites.contains(widget.stationId);
      if (mounted) setState(() => _favorite = added);
      if (!added) return;

      final station = await widget.api.getStation(widget.stationId);
      if (!mounted) return;
      final incidents = _maps(station['incidents']);
      final activeIncidents = activeAccessibilityIncidents(incidents);
      if (activeIncidents.isEmpty) return;

      final notified =
          await (widget.notifications ??
                  LocalAccessibilityNotificationService())
              .notifyStationIssues(
                stationId: widget.stationId,
                stationName: station['name'] as String? ?? 'Estação',
                incidents: activeIncidents,
              );
      if (!notified && mounted) {
        _showMessage(
          'Favorito salvo. Ative as notificações do app para receber este aviso.',
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      _showMessage(
        error is ApiException
            ? error.message
            : 'Não foi possível verificar os problemas da estação.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureLogin() async {
    if (widget.api.token != null) return true;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
    return result == true && mounted;
  }

  Future<void> _report() async {
    if (!await _ensureLogin() || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            IncidentReportScreen(api: widget.api, stationId: widget.stationId),
      ),
    );
    if (mounted) {
      setState(() => _station = widget.api.getStation(widget.stationId));
    }
  }

  Future<void> _review() async {
    if (!await _ensureLogin() || !mounted) return;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReviewDialog(api: widget.api, stationId: widget.stationId),
    );
    if (submitted == true && mounted) {
      setState(() => _station = widget.api.getStation(widget.stationId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalhes da estação'),
      actions: [
        IconButton(
          onPressed: _toggleFavorite,
          tooltip: _favorite
              ? 'Remover dos favoritos'
              : 'Adicionar aos favoritos',
          icon: Icon(
            _favorite ? Icons.favorite : Icons.favorite_border,
            color: _favorite ? const Color(0xFFE14D62) : null,
          ),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _station,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DetailError(
            message: snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Não foi possível carregar esta estação.',
            retry: () => setState(
              () => _station = widget.api.getStation(widget.stationId),
            ),
          );
        }
        final station = snapshot.data!;
        final incidents = _maps(station['incidents']);
        final reviews = _maps(station['reviews']);
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              _StationHero(
                station: station,
                incidents: incidents,
                reviews: reviews,
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Color(0xFF0868E8),
                unselectedLabelColor: Color(0xFF64748B),
                tabs: [
                  Tab(text: 'Visão geral'),
                  Tab(text: 'Acessibilidade'),
                  Tab(text: 'Incidentes'),
                  Tab(text: 'Avaliações'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(
                      station: station,
                      incidents: incidents,
                      reviews: reviews,
                      onMap: () => _showMap(station),
                    ),
                    _AccessibilityTab(station: station),
                    _IncidentsTab(incidents: incidents, onReport: _report),
                    _ReviewsTab(reviews: reviews, onReview: _review),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showMap(station),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Ver no mapa'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _report,
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Denunciar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  void _showMap(Map<String, dynamic> station) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NetworkMapScreen(api: widget.api, focusStations: [station]),
      ),
    );
  }

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class _StationHero extends StatelessWidget {
  const _StationHero({
    required this.station,
    required this.incidents,
    required this.reviews,
  });
  final Map<String, dynamic> station;
  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    final line = station['line'] as String? ?? 'Linha não informada';
    final ratings = reviews
        .map((review) => review['rating'])
        .whereType<num>()
        .toList();
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;
    return Container(
      height: 174,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102C49), Color(0xFF15578A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: 10,
            child: Icon(
              Icons.train_rounded,
              size: 105,
              color: Colors.white.withValues(alpha: .1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line,
                style: const TextStyle(
                  color: Color(0xFFB8E8D2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                station['name'] as String? ?? 'Estação',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _HeroTag(
                    icon: Icons.star,
                    text: average == null
                        ? 'Sem avaliações'
                        : '${average.toStringAsFixed(1)} (${ratings.length})',
                  ),
                  const SizedBox(width: 8),
                  _HeroTag(
                    icon: Icons.campaign_outlined,
                    text: '${incidents.length} relatos',
                  ),
                  if (station['zone'] is String &&
                      (station['zone'] as String).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _HeroTag(
                      icon: Icons.place_outlined,
                      text: station['zone'] as String,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.station,
    required this.incidents,
    required this.reviews,
    required this.onMap,
  });
  final Map<String, dynamic> station;
  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'Informações da estação',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF132640),
        ),
      ),
      const SizedBox(height: 10),
      _InfoRow(
        icon: Icons.train_outlined,
        label: 'Linha',
        value: station['line'] as String? ?? 'Não informada',
      ),
      _InfoRow(
        icon: Icons.place_outlined,
        label: 'Região',
        value: station['zone'] as String? ?? 'Não informada',
      ),
      _InfoRow(
        icon: Icons.accessible_forward,
        label: 'Acessibilidade',
        value: accessibilitySummary(station['accessibility']),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onMap,
        icon: const Icon(Icons.map_outlined),
        label: const Text('Localizar estação'),
      ),
      const SizedBox(height: 16),
      Text(
        '${incidents.length} incidentes · ${reviews.length} avaliações',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      ),
    ],
  );
}

class _AccessibilityTab extends StatelessWidget {
  const _AccessibilityTab({required this.station});
  final Map<String, dynamic> station;
  @override
  Widget build(BuildContext context) {
    final items = parseAccessibilityFeatures(station['accessibility']);
    if (items.isEmpty) {
      return const _EmptyTab(
        icon: Icons.accessible_forward,
        title: 'Dados não informados',
        message:
            'Ainda não há recursos de acessibilidade cadastrados para esta estação.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Recursos de acessibilidade',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF132640),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Os mesmos valores foram cadastrados para todas as estações e não '
          'foram verificados individualmente.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 9),
        for (final item in items)
          _InfoRow(
            icon: _accessibilityIcon(item),
            label: item,
            value: 'Status cadastrado',
          ),
      ],
    );
  }

  IconData _accessibilityIcon(String item) {
    final value = item.toLowerCase();
    if (value.contains('elevador')) return Icons.elevator_outlined;
    if (value.contains('rampa')) return Icons.accessible_forward;
    if (value.contains('piso') || value.contains('tátil')) {
      return Icons.blind_outlined;
    }
    if (value.contains('banheiro')) return Icons.wc_outlined;
    return Icons.accessible_outlined;
  }
}

class _IncidentsTab extends StatelessWidget {
  const _IncidentsTab({required this.incidents, required this.onReport});
  final List<Map<String, dynamic>> incidents;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return _EmptyTab(
        icon: Icons.campaign_outlined,
        title: 'Sem incidentes recentes',
        message: 'Nenhum relato cadastrado para esta estação.',
        action: OutlinedButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.add),
          label: const Text('Fazer um relato'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 9),
          child: Text(
            '${incidents.length} incidentes recentes',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
        ),
        for (final incident in incidents) _IncidentCard(incident: incident),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Denunciar problema'),
        ),
      ],
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews, required this.onReview});
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) {
    final average = reviews.isEmpty
        ? null
        : reviews
                  .map((review) => review['rating'])
                  .whereType<num>()
                  .reduce((a, b) => a + b) /
              reviews.length;
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        if (average != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 0, 3, 13),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFF4B400)),
                const SizedBox(width: 5),
                Text(
                  '${average.toStringAsFixed(1)} de 5',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${reviews.length})',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        if (reviews.isEmpty)
          const _EmptyTab(
            icon: Icons.star_outline,
            title: 'Sem avaliações ainda',
            message: 'Conte como foi sua experiência nesta estação.',
          ),
        for (final review in reviews) _ReviewCard(review: review),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReview,
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Avaliar estação'),
        ),
      ],
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});
  final Map<String, dynamic> incident;
  @override
  Widget build(BuildContext context) {
    final status = incident['status'] as String? ?? 'PENDING';
    final color = switch (status) {
      'RESOLVED' => const Color(0xFF138361),
      'IN_PROGRESS' => const Color(0xFFB47700),
      'REJECTED' => const Color(0xFF64748B),
      _ => const Color(0xFF0868E8),
    };
    final label = switch (status) {
      'RESOLVED' => 'Resolvido',
      'IN_PROGRESS' => 'Em andamento',
      'REJECTED' => 'Encerrado',
      _ => 'Pendente',
    };
    final category = switch (incident['category']) {
      'ELEVATOR' => 'Elevador',
      'ESCALATOR' => 'Escada rolante',
      'ACCESSIBILITY' => 'Acessibilidade',
      'SAFETY' => 'Segurança',
      _ => 'Outro',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            incident['title'] as String? ?? 'Relato',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            incident['description'] as String? ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Map<String, dynamic> review;
  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review['authorName'] as String? ?? 'Passageiro',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF132640),
                ),
              ),
              const Spacer(),
              ...List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 15,
                  color: const Color(0xFFF4B400),
                ),
              ),
            ],
          ),
          if (review['comment'] is String &&
              (review['comment'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review['comment'] as String,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0868E8), size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF132640),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 37, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_outlined,
            size: 36,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.api, required this.stationId});
  final ApiService api;
  final String stationId;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _sending = false;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.api.createReview(
        stationId: widget.stationId,
        rating: _rating,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Avaliar estação'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => IconButton(
              onPressed: _sending
                  ? null
                  : () => setState(() => _rating = index + 1),
              tooltip: '${index + 1} estrelas',
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFF4B400),
              ),
            ),
          ),
        ),
        TextField(
          controller: _comment,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Conte sua experiência (opcional)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _sending ? null : _submit,
        child: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enviar'),
      ),
    ],
  );
}
