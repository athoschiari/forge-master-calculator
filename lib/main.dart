import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repository/storage.dart';
import 'screens/dashboard.dart';
import 'screens/gear_screen.dart';
import 'screens/mounts_screen.dart';
import 'screens/optimizer_screen.dart';
import 'screens/pets_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.open();
  final appState = await AppState.load(storage);
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const ForgeMasterApp(),
    ),
  );
}

class ForgeMasterApp extends StatelessWidget {
  const ForgeMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge Master Optimizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}

/// A navigation destination and the screen it shows.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Responsive shell: a NavigationRail on wide screens, a NavigationBar on narrow
/// ones. Screens are kept alive in an IndexedStack so state (search text, edited
/// candidate) survives tab switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<_Destination> _destinations = [
    _Destination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Gear', Icons.shield_outlined, Icons.shield),
    _Destination('Pets', Icons.pets_outlined, Icons.pets),
    _Destination('Mounts', Icons.two_wheeler_outlined, Icons.two_wheeler),
    _Destination('Optimizer', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _Destination('Planner', Icons.trending_up_outlined, Icons.trending_up),
    _Destination('Settings', Icons.settings_outlined, Icons.settings),
  ];

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      Dashboard(onNavigate: _go),
      const GearScreen(),
      const PetsScreen(),
      const MountsScreen(),
      const OptimizerScreen(),
      const PlannerScreen(),
      const SettingsScreen(),
    ];
    final body = IndexedStack(index: _index, children: screens);
    final wide = MediaQuery.of(context).size.width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.local_fire_department, size: 28),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
