import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/deck/deck_screen.dart';
import 'screens/profiles/profiles_screen.dart';
import 'screens/connections/connections_screen.dart';
import 'screens/settings/settings_dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/connection_service.dart';
import 'services/deck_execution_service.dart';
import 'services/profile_service.dart';
import 'services/live_state_service.dart';
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
        ChangeNotifierProvider(create: (_) => LiveStateService()),
        ChangeNotifierProvider(create: (_) => ProfileService(storageService)),
        ChangeNotifierProxyProvider3<ConnectionService, LiveStateService, ProfileService, DeckExecutionService>(
          create: (ctx) => DeckExecutionService(
            ctx.read<ConnectionService>(),
            ctx.read<LiveStateService>(),
            ctx.read<ProfileService>(),
          ),
          update: (ctx, conn, liveState, profiles, prev) =>
              prev ?? DeckExecutionService(conn, liveState, profiles),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settingsService, _) {
          final settings = settingsService.settings;
          return MaterialApp(
            title: 'AstraDeck',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AstraDeckTheme.getTheme(
              preset: settings.themePreset,
              accentOverride: settings.accentColor,
              mode: ThemeMode.light,
            ),
            darkTheme: AstraDeckTheme.getTheme(
              preset: settings.themePreset,
              accentOverride: settings.accentColor,
              mode: ThemeMode.dark,
            ),
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
    final themeBundle = AstraThemeBundle.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _destinations,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: themeBundle.navBarBg,
          border: Border(
            top: BorderSide(
              color: themeBundle.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: _currentIndex,
            indicatorColor: theme.colorScheme.primary.withValues(alpha: themeBundle.isDark ? 0.22 : 0.15),
            onDestinationSelected: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Deck',
              ),
              NavigationDestination(
                icon: Icon(Icons.layers_outlined),
                selectedIcon: Icon(Icons.layers_rounded),
                label: 'Profiles',
              ),
              NavigationDestination(
                icon: Icon(Icons.wifi_tethering_outlined),
                selectedIcon: Icon(Icons.wifi_tethering_rounded),
                label: 'Connections',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
