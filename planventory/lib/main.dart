import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/config.dart';
import 'routes/routes.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'screens/main_shell.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configuration
  AppConfig.init(environment: Environment.development);
  AppLogger.info('App starting...', tag: 'Main');

  // Initialize database for current platform
  await DatabaseService.initializeDatabaseFactory();

  // Set preferred orientations (optional, good for tablets)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Run the app
  runApp(const PlanVentoryApp());
}

/// Main application widget
class PlanVentoryApp extends StatelessWidget {
  const PlanVentoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProxyProvider2<InventoryProvider, EventProvider, AppStateProvider>(
          create: (context) => AppStateProvider(
            inventoryProvider: context.read<InventoryProvider>(),
            eventProvider: context.read<EventProvider>(),
          ),
          update: (context, inventory, events, previous) => 
            previous ?? AppStateProvider(
              inventoryProvider: inventory,
              eventProvider: events,
            ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          if (themeProvider.isLoading) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,

            // Theme from provider
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,

            // Routing
            initialRoute: AppRoutes.home,
            onGenerateRoute: AppRouter.generateRoute,

            // Home - using MainShell for bottom navigation
            home: const MainShell(),
          );
        },
      ),
    );
  }
}
