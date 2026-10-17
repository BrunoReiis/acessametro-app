import 'package:flutter/material.dart';

import 'api/api_service.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/stations_screen.dart';

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
    home: AppShell(api: api),
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
  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(api: widget.api, onNavigate: _selectTab),
          StationsScreen(api: widget.api),
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
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: 'Relatos',
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
