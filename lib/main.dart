import 'package:flutter/material.dart';

import 'api/api_service.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/route_screen.dart';
import 'screens/stations_screen.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  await api.restoreSession();
  runApp(AcessaMetroApp(api: api));
}

class AcessaMetroApp extends StatelessWidget {
  const AcessaMetroApp({super.key, required this.api});
  final ApiService api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AcessaMetrô',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0868E8),
        primary: const Color(0xFF0868E8),
        surface: const Color(0xFFF5F8FA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F8FA),
        foregroundColor: Color(0xFF132640),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE5EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE5EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0868E8), width: 1.5),
        ),
      ),
    ),
    home: api.token == null ? WelcomeScreen(api: api) : AppShell(api: api),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api});
  final ApiService api;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    drawer: _AppDrawer(onNavigate: _selectTab),
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            api: widget.api,
            onNavigate: _selectTab,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          StationsScreen(api: widget.api),
          RouteScreen(api: widget.api),
          IncidentsScreen(api: widget.api),
          AccountScreen(api: widget.api),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Início',
        ),
        NavigationDestination(
          icon: Icon(Icons.train_outlined),
          selectedIcon: Icon(Icons.train),
          label: 'Estações',
        ),
        NavigationDestination(
          icon: Icon(Icons.alt_route_outlined),
          selectedIcon: Icon(Icons.alt_route),
          label: 'Rotas',
        ),
        NavigationDestination(
          icon: Icon(Icons.warning_amber_outlined),
          selectedIcon: Icon(Icons.warning_amber),
          label: 'Denunciar',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Conta',
        ),
      ],
    ),
  );
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
            child: Row(
              children: [
                const Icon(
                  Icons.accessible_forward,
                  color: Color(0xFF0868E8),
                  size: 29,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AcessaMetrô',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar menu',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.home_outlined,
            label: 'Início',
            onTap: () => _go(context, 0),
          ),
          _DrawerItem(
            icon: Icons.train_outlined,
            label: 'Estações',
            onTap: () => _go(context, 1),
          ),
          _DrawerItem(
            icon: Icons.alt_route_outlined,
            label: 'Planejar rota',
            onTap: () => _go(context, 2),
          ),
          _DrawerItem(
            icon: Icons.warning_amber_outlined,
            label: 'Denunciar problema',
            onTap: () => _go(context, 3),
          ),
          const Divider(height: 24),
          _DrawerItem(
            icon: Icons.person_outline,
            label: 'Meu perfil',
            onTap: () => _go(context, 4),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              'AcessaMetrô · 1.0.0',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  void _go(BuildContext context, int index) {
    Navigator.pop(context);
    onNavigate(index);
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: const Color(0xFF263B53)),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    onTap: onTap,
    dense: true,
  );
}
