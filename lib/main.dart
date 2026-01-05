import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/pets/presentation/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // 2. Inicializar Supabase
  await SupabaseClientManager.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetAdopt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Verificar si el usuario ya está autenticado
      home: SupabaseClientManager.instance.isAuthenticated
          ? const HomePage()
          : const LoginPage(),

      // Rutas
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
