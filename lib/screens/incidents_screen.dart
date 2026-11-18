import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../utils/station_search.dart';
import 'account_screen.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  late Future<List<Map<String, dynamic>>> _incidents;
  @override
  void initState() {
    super.initState();
    _incidents = widget.api.getIncidents();
  }

  Future<void> _report() async {
    if (widget.api.token == null) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      );
      if (loggedIn != true || !mounted) return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => IncidentReportScreen(api: widget.api)),
    );
    if (created == true && mounted) {
      setState(() {
        _incidents = widget.api.getIncidents();
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatos',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF132640),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Condições compartilhadas pela comunidade',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _report,
            tooltip: 'Fazer um relato',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 18),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _incidents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 90),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Não foi possível carregar os relatos.';
            return _IncidentMessage(
              message: message,
              retry: () => setState(() {
                _incidents = widget.api.getIncidents();
              }),
            );
          }
          final incidents = snapshot.data ?? [];
          if (incidents.isEmpty) {
            return const _IncidentMessage(
              message:
                  'Ainda não há relatos. Seja a primeira pessoa a compartilhar uma informação.',
            );
          }
          return Column(
            children: [
              for (final incident in incidents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _IncidentTile(
                    incident: incident,
                    api: widget.api,
                    isAdmin: widget.api.currentUser?['role'] == 'ADMIN',
                    onStatusChanged: () {
                      if (mounted) {
                        setState(() {
                          _incidents = widget.api.getIncidents();
                        });
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _report,
        icon: const Icon(Icons.add),
        label: const Text('Relatar um problema'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ],
  );
}

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key, required this.api, this.stationId});
  final ApiService api;
  final String? stationId;
  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late Future<List<Map<String, dynamic>>> _stations;
  String? _stationId;
  String _category = 'ACCESSIBILITY';
  bool _sending = false;
  static const _categories = <String, String>{
    'ACCESSIBILITY': 'Acessibilidade',
    'ELEVATOR': 'Elevador',
    'ESCALATOR': 'Escada rolante',
    'SAFETY': 'Segurança',
    'OTHER': 'Outro',
  };
  @override
  void initState() {
    super.initState();
    _stationId = widget.stationId;
    _stations = widget.api.getStations();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _stationId == null) return;
    setState(() => _sending = true);
    try {
      await widget.api.createIncident(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        stationId: _stationId!,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Novo relato')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text(
            'O que aconteceu?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sua informação ajuda outras pessoas a planejar o trajeto.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 23),
          const _FieldLabel('Estação'),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _stations,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Não foi possível carregar estações. Tente novamente mais tarde.',
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final stations = snapshot.data!;
              Map<String, dynamic>? selectedStation;
              for (final station in stations) {
                if (station['id'] == _stationId) {
                  selectedStation = station;
                  break;
                }
              }
              return Autocomplete<Map<String, dynamic>>(
                initialValue: TextEditingValue(
                  text: selectedStation?['name'] as String? ?? '',
                ),
                displayStringForOption: (station) =>
                    station['name'] as String? ?? 'Estação',
                optionsBuilder: (value) =>
                    filterStations(stations, value.text).take(12),
                onSelected: (station) =>
                    setState(() => _stationId = station['id'] as String),
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) =>
                        TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                          decoration: const InputDecoration(
                            hintText: 'Digite o nome ou a linha',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) {
                            if (_stationId != null) {
                              setState(() => _stationId = null);
                            }
                          },
                          validator: (_) => _stationId == null
                              ? 'Selecione uma estação nas sugestões.'
                              : null,
                        ),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final station in options)
                            ListTile(
                              title: Text(
                                station['name'] as String? ?? 'Estação',
                              ),
                              subtitle: station['line'] is String
                                  ? Text(station['line'] as String)
                                  : null,
                              onTap: () => onSelected(station),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 17),
          const _FieldLabel('Tipo de ocorrência'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(),
            items: _categories.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'OTHER'),
          ),
          const SizedBox(height: 17),
          const _FieldLabel('Título'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _title,
            maxLength: 150,
            decoration: const InputDecoration(
              hintText: 'Ex.: Elevador fora de serviço',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Informe ao menos 3 caracteres.'
                : null,
          ),
          const SizedBox(height: 9),
          const _FieldLabel('Descrição'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Conte o que outras pessoas precisam saber.',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Descreva a situação com pelo menos 10 caracteres.'
                : null,
          ),
          const SizedBox(height: 13),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar relato'),
          ),
        ],
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF263B53),
    ),
  );
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.incident,
    required this.api,
    required this.isAdmin,
    required this.onStatusChanged,
  });
  final Map<String, dynamic> incident;
  final ApiService api;
  final bool isAdmin;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context) => _IncidentTileContent(
    incident: incident,
    api: api,
    isAdmin: isAdmin,
    onStatusChanged: onStatusChanged,
  );
}

class _IncidentTileContent extends StatefulWidget {
  const _IncidentTileContent({
    required this.incident,
    required this.api,
    required this.isAdmin,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> incident;
  final ApiService api;
  final bool isAdmin;
  final VoidCallback onStatusChanged;

  @override
  State<_IncidentTileContent> createState() => _IncidentTileContentState();
}

class _IncidentTileContentState extends State<_IncidentTileContent> {
  bool _updatingStatus = false;

  Future<void> _updateStatus(String status) async {
    final incidentId = widget.incident['id'] as String?;
    if (incidentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível identificar o relato.')),
      );
      return;
    }

    setState(() => _updatingStatus = true);
    try {
      await widget.api.updateIncidentStatus(
        incidentId: incidentId,
        status: status,
      );
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status do relato atualizado.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final station = incident['station'] is Map
        ? incident['station'] as Map
        : const {};
    final status = incident['status'] as String? ?? 'PENDING';
    final (label, color, background) = switch (status) {
      'RESOLVED' => (
        'Resolvido',
        const Color(0xFF16734F),
        const Color(0xFFE5F5ED),
      ),
      'IN_PROGRESS' => (
        'Em andamento',
        const Color(0xFF9A6200),
        const Color(0xFFFFF2D8),
      ),
      'REJECTED' => (
        'Encerrado',
        const Color(0xFF64748B),
        const Color(0xFFF0F3F6),
      ),
      _ => ('Pendente', const Color(0xFF0868E8), const Color(0xFFE8F2FF)),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  station['name'] as String? ?? 'Estação',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0868E8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 10),
          Text(
            incident['title'] as String? ?? 'Relato',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            incident['description'] as String? ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _updatingStatus
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Ajustar status do relato',
                      onSelected: _updateStatus,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'PENDING',
                          child: Text('Pendente'),
                        ),
                        PopupMenuItem(
                          value: 'IN_PROGRESS',
                          child: Text('Em andamento'),
                        ),
                        PopupMenuItem(
                          value: 'RESOLVED',
                          child: Text('Resolvido'),
                        ),
                        PopupMenuItem(
                          value: 'REJECTED',
                          child: Text('Encerrado'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 7),
                            Text('Ajustar status'),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncidentMessage extends StatelessWidget {
  const _IncidentMessage({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 65),
    child: Column(
      children: [
        const Icon(Icons.campaign_outlined, size: 38, color: Color(0xFF94A3B8)),
        const SizedBox(height: 13),
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
