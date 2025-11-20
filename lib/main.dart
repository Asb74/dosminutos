import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/arbitros_screen.dart';
import 'screens/equipos_screen.dart';
import 'screens/historial_partidos_screen.dart';
import 'screens/home_screen.dart';
import 'screens/jugadores_equipo_screen.dart';
import 'screens/jugadores_equipos_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maestros_screen.dart';
import 'screens/nuevo_partido_screen.dart';
import 'screens/staff_equipo_screen.dart';
import 'screens/staff_equipos_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/temporadas_screen.dart';
import 'screens/clubes_screen.dart';

const primaryYellow = Color(0xFFFFC727);
const black = Colors.black;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DosMinutosApp());
}

class DosMinutosApp extends StatelessWidget {
  const DosMinutosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryYellow,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryYellow,
      onPrimary: black,
      secondary: black,
      onSecondary: Colors.white,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFF7D1),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryYellow,
        foregroundColor: black,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: black,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    return MaterialApp(
      title: 'Dos Minutos',
      theme: baseTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/nuevoPartido': (context) => const NuevoPartidoScreen(),
        '/historial': (context) => const HistorialPartidosScreen(),
        '/equipos': (context) => const EquiposScreen(),
        '/maestros': (context) => const MaestrosScreen(),
        '/arbitros': (context) => const ArbitrosScreen(),
        '/staff': (context) => const StaffEquiposScreen(),
        '/temporadas': (context) => const TemporadasScreen(),
        '/clubes': (context) => const ClubesScreen(),
      },
    );
  }
}
