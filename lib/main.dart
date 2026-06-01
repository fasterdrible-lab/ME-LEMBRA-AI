import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'services/notification_service.dart';
import 'services/sos_listener_service.dart';
import 'services/sos_protection_service.dart';
import 'services/volume_sos_service.dart';
import 'features/adult/adult_screen.dart';
import 'features/child/child_monitor_screen.dart';
import 'features/child/child_screen.dart';
import 'features/elderly/elderly_screen.dart';
import 'features/family/family_screen.dart';
import 'features/maps/map_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'config_screen.dart';
import 'history_screen.dart';
import 'services/settings_service.dart';
import 'features/vehicle/vehicle_screen.dart';

bool _onboardingVisto = false;
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase já inicializado pelo google-services.json nativo
  }
  await NotificationService.init();
  final prefs = await SharedPreferences.getInstance();
  _onboardingVisto = prefs.getBool('onboarding_visto') ?? false;
  final modoEscuro = await SettingsService.getModoEscuro();
  themeModeNotifier.value = modoEscuro ? ThemeMode.dark : ThemeMode.light;

  // Restaura serviços persistentes ativados pelo usuário
  await SosProtectionService.restoreIfEnabled();
  await VolumeSosService.restoreIfEnabled();

  runApp(const MeLembraApp());
}

class MeLembraApp extends StatelessWidget {
  const MeLembraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF7B5EA7),
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF7B5EA7),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF7B5EA7),
            scaffoldBackgroundColor: const Color(0xFF1C1C1E),
            cardColor: const Color(0xFF2C2C2E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF3D2B5E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFF3A3A3C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/adult': (context) => const AdultScreen(),
        '/child': (context) => const ChildScreen(),
        '/child-monitor': (context) => const ChildMonitorScreen(),
        '/elderly': (context) => const ElderlyScreen(),
        '/family': (context) => const FamilyScreen(),
        '/history': (context) => const HistoryScreen(),
        '/vehicles': (context) => const VehicleScreen(),
        '/map': (context) => const MapScreen(),
        '/config': (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Configurações'),
                backgroundColor: const Color(0xFF7B5EA7),
                foregroundColor: Colors.white,
              ),
              body: const ConfigScreen(),
            ),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90D9)),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            SosListenerService.start();
            return const HomeScreen();
          }
          SosListenerService.stop();
          if (!_onboardingVisto) {
            return const OnboardingScreen();
          }
          return const LoginScreen();
        },
      ),
    );
      },
    );
  }
}