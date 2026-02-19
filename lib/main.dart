import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sci_tercen_client/sci_client_service_factory.dart' show ServiceFactory;
import 'package:sci_tercen_client/sci_service_factory_web.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'presentation/providers/app_state_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Mock/Real switching ---
  // Default: real mode (USE_MOCKS=false). Set USE_MOCKS=true for local dev.
  const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);

  ServiceFactory? factory;
  String? taskId;

  if (!useMocks) {
    try {
      taskId = Uri.base.queryParameters['taskId'];
      if (taskId == null || taskId.isEmpty) {
        runApp(_buildErrorApp('Missing taskId parameter'));
        return;
      }
      print('DASCombat: initializing Tercen ServiceFactory...');
      factory = await createServiceFactoryForWebApp();
      print('DASCombat: ServiceFactory initialized, taskId=$taskId');
    } catch (e) {
      print('DASCombat: Tercen init failed: $e');
    }
  }

  setupServiceLocator(
    useMocks: factory == null,
    factory: factory,
    taskId: taskId,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(DasCombatFitApp(prefs: prefs));
}

Widget _buildErrorApp(String message) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 18),
        ),
      ),
    ),
  );
}

class DasCombatFitApp extends StatelessWidget {
  final SharedPreferences prefs;

  const DasCombatFitApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'DASCombat Fit',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
