import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/deck/deck_screen.dart';
import 'screens/profiles/profiles_screen.dart';
import 'screens/connections/connections_screen.dart';
import 'screens/settings/settings_dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/connection_service.dart';
import 'services/obs_service.dart';
import 'services/deck_execution_service.dart';
import 'services/profile_service.dart';
import 'theme/astradeck_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();

  runApp(AstraDeckApp(storageService: storageService));
}

class AstraDeckApp extends StatelessWidget {
  final StorageService storageService;

  const AstraDeckApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService(storageService)),
        ChangeNotifierProvider(create: (_) => ConnectionService(storageService)),
        ChangeNotifierProvider(create: (_) => ObsService(storageService)),
        ChangeNotifierProxyProvider2<ConnectionService, ObsService, DeckExecutionService>(
          create: (ctx) => DeckExecutionService(ctx.read<ConnectionService>(), ctx.read<ObsService>()),
          update: (ctx, conn, obs, prev) => prev ?? DeckExecutionService(conn, obs),
        ),
        ChangeNotifierProvider(create: (_) => ProfileService(storageService)),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settingsService, _) {
          final settings = settingsService.settings;
          return MaterialApp(
            title: 'AstraDeck',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AstraDeckTheme.getLightTheme(settings.accentColor),
            darkTheme: AstraDeckTheme.getDarkTheme(settings.accentColor),
            home: const MainNavigationShell(),
          );
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _destinations = const [
    DeckScreen(),
    ProfilesScreen(),
    ConnectionsScreen(),
    SettingsDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _destinations,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Deck',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Profiles',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering),
            selectedIcon: Icon(Icons.wifi_tethering_rounded),
            label: 'Connections',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
