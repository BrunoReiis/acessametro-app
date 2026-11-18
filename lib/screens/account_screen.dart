import 'package:flutter/material.dart';

import '../api/api_service.dart';
import 'station_detail_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _openLogin() async {
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
    if (loggedIn == true && mounted) setState(() {});
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) setState(() {});
  }

  Future<bool> _ensureLogin() async {
    if (widget.api.token != null) return true;
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
    if (loggedIn == true && mounted) setState(() {});
    return loggedIn == true && mounted;
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FavoriteStationsScreen(api: widget.api),
      ),
    );
  }

  Future<void> _openActivity(ActivityKind kind) async {
    if (!await _ensureLogin() || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileActivityScreen(api: widget.api, kind: kind),
      ),
    );
  }

  void _showPersonalInfo(Map<String, dynamic>? user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informações pessoais'),
        content: user == null
            ? const Text('Entre para consultar seus dados.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nome: ${user['name'] ?? 'Não informado'}'),
                  const SizedBox(height: 8),
                  Text('E-mail: ${user['email'] ?? 'Não informado'}'),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        const Text(
          'Meu perfil',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: Color(0xFF132640),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
          ),
          child: user == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFFE8F2FF),
                      child: Icon(
                        Icons.person_outline,
                        color: Color(0xFF0868E8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Entre para participar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF132640),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Acesse sua conta para enviar relatos e contribuir com a comunidade.',
                      style: TextStyle(height: 1.45, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 17),
                    FilledButton(
                      onPressed: _openLogin,
                      child: const Text('Entrar ou criar conta'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFE8F2FF),
                      child: Text(
                        (user['name'] as String? ?? 'A')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0868E8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] as String? ?? 'Usuário',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF132640),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user['email'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _logout,
                      tooltip: 'Sair da conta',
                      icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _ProfileOption(
          icon: Icons.badge_outlined,
          title: 'Informações pessoais',
          onTap: () => _showPersonalInfo(user),
        ),
        _ProfileOption(
          icon: Icons.favorite_border,
          title: 'Meus favoritos',
          onTap: _openFavorites,
        ),
        _ProfileOption(
          icon: Icons.star_outline,
          title: 'Minhas avaliações',
          onTap: () => _openActivity(ActivityKind.reviews),
        ),
        _ProfileOption(
          icon: Icons.campaign_outlined,
          title: 'Minhas denúncias',
          onTap: () => _openActivity(ActivityKind.incidents),
        ),
        _ProfileOption(
          icon: Icons.info_outline,
          title: 'Sobre o AcessaMetrô',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'AcessaMetrô',
            applicationVersion: '1.0.0',
            applicationLegalese: 'Mobilidade com autonomia.',
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB42332),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const _AccountInfo(
          icon: Icons.accessible_forward,
          title: 'Acessibilidade compartilhada',
          detail: 'Consulte informações e barreiras relatadas nas estações.',
        ),
        const SizedBox(height: 10),
        const _AccountInfo(
          icon: Icons.shield_outlined,
          title: 'Seus dados',
          detail: 'A autenticação é protegida pela API AcessaMetrô.',
        ),
      ],
    );
  }
}

enum ActivityKind { incidents, reviews }

class FavoriteStationsScreen extends StatefulWidget {
  const FavoriteStationsScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<FavoriteStationsScreen> createState() => _FavoriteStationsScreenState();
}

class _FavoriteStationsScreenState extends State<FavoriteStationsScreen> {
  late Future<List<Map<String, dynamic>>> _stations;

  Future<List<Map<String, dynamic>>> _load() async {
    final ids = await widget.api.getFavoriteStationIds();
    if (ids.isEmpty) return [];
    final stations = await widget.api.getStations();
    return stations.where((station) => ids.contains(station['id'])).toList();
  }

  Future<void> _removeFavorite(Map<String, dynamic> station) async {
    try {
      await widget.api.toggleFavoriteStation(station['id'] as String);
      if (mounted) {
        setState(() {
          _stations = _load();
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Não foi possível remover a estação dos favoritos.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void initState() {
    super.initState();
    _stations = _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meus favoritos'),
      actions: [
        IconButton(
          tooltip: 'Atualizar favoritos',
          onPressed: () {
            setState(() {
              _stations = _load();
            });
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _stations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Não foi possível carregar os favoritos.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final stations = snapshot.data ?? [];
        if (stations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Estações salvas como favoritas aparecerão aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final station in stations)
              ListTile(
                leading: const Icon(
                  Icons.train_outlined,
                  color: Color(0xFF0868E8),
                ),
                title: Text(station['name'] as String? ?? 'Estação'),
                subtitle: Text(
                  station['line'] as String? ?? 'Linha não informada',
                ),
                trailing: IconButton(
                  tooltip:
                      'Remover ${station['name'] ?? 'estação'} dos favoritos',
                  onPressed: () => _removeFavorite(station),
                  icon: const Icon(Icons.favorite, color: Color(0xFFE14D62)),
                ),
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => StationDetailScreen(
                        api: widget.api,
                        stationId: station['id'] as String,
                      ),
                    ),
                  );
                  if (mounted) setState(() => _stations = _load());
                },
              ),
          ],
        );
      },
    ),
  );
}

class ProfileActivityScreen extends StatefulWidget {
  const ProfileActivityScreen({
    super.key,
    required this.api,
    required this.kind,
  });
  final ApiService api;
  final ActivityKind kind;
  @override
  State<ProfileActivityScreen> createState() => _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends State<ProfileActivityScreen> {
  late Future<List<Map<String, dynamic>>> _items;

  Future<List<Map<String, dynamic>>> _load() async {
    final userId = widget.api.currentUser?['id'];
    if (widget.kind == ActivityKind.incidents) {
      final items = await widget.api.getIncidents();
      return items.where((item) => item['userId'] == userId).toList();
    }
    final items = await widget.api.getReviews();
    return items.where((item) => item['userId'] == userId).toList();
  }

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  @override
  Widget build(BuildContext context) {
    final isIncident = widget.kind == ActivityKind.incidents;
    return Scaffold(
      appBar: AppBar(
        title: Text(isIncident ? 'Minhas denúncias' : 'Minhas avaliações'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Não foi possível carregar sua atividade.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                isIncident
                    ? 'Você ainda não enviou denúncias.'
                    : 'Você ainda não avaliou estações.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final station = item['station'] is Map
                  ? item['station'] as Map
                  : const {};
              return Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: Icon(
                    isIncident ? Icons.campaign_outlined : Icons.star_outline,
                    color: const Color(0xFF0868E8),
                  ),
                  title: Text(
                    item['title'] as String? ??
                        station['name'] as String? ??
                        'Atividade',
                  ),
                  subtitle: Text(station['name'] as String? ?? ''),
                  trailing: isIncident
                      ? Text(_statusLabel(item['status'] as String?))
                      : Text('${item['rating'] ?? 0}/5'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(String? status) => switch (status) {
    'RESOLVED' => 'Resolvido',
    'IN_PROGRESS' => 'Em andamento',
    'REJECTED' => 'Encerrado',
    _ => 'Pendente',
  };
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: const Color(0xFF263B53)),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 19,
      color: Color(0xFF94A3B8),
    ),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
    dense: true,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _sending = false;
  bool _obscurePassword = true;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      if (_registering) {
        await widget.api.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await widget.api.login(_email.text.trim(), _password.text);
      }
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
    appBar: AppBar(title: Text(_registering ? 'Criar conta' : 'Entrar')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 15, 22, 30),
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 29,
              color: Color(0xFF0868E8),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _registering
                ? 'Faça parte da\ncomunidade.'
                : 'Bem-vindo\nde volta.',
            style: const TextStyle(
              fontSize: 30,
              height: 1.13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF132640),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _registering
                ? 'Compartilhe informações que tornam o transporte melhor para todo mundo.'
                : 'Entre para contribuir e enviar relatos de acessibilidade.',
            style: const TextStyle(height: 1.45, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          if (_registering) ...[
            const _AuthLabel('Nome'),
            const SizedBox(height: 7),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Seu nome'),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 2 ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 15),
          ],
          const _AuthLabel('E-mail'),
          const SizedBox(height: 7),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(hintText: 'voce@email.com'),
            validator: (value) => value == null || !value.contains('@')
                ? 'Informe um e-mail válido.'
                : null,
          ),
          const SizedBox(height: 15),
          const _AuthLabel('Senha'),
          const SizedBox(height: 7),
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            autofillHints: [
              _registering ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              hintText: 'Pelo menos 6 caracteres',
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => (value?.length ?? 0) < 6
                ? 'A senha precisa ter ao menos 6 caracteres.'
                : null,
          ),
          const SizedBox(height: 23),
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
                : Text(_registering ? 'Criar conta' : 'Entrar'),
          ),
          const SizedBox(height: 11),
          TextButton(
            onPressed: _sending
                ? null
                : () => setState(() => _registering = !_registering),
            child: Text(
              _registering ? 'Já tenho uma conta' : 'Criar uma conta',
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthLabel extends StatelessWidget {
  const _AuthLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF263B53),
    ),
  );
}

class _AccountInfo extends StatelessWidget {
  const _AccountInfo({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF13785C)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF132640),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
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
