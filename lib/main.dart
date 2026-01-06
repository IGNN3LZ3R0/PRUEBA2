import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/deep_link_handler.dart'; // ✅ NUEVO
import 'features/auth/presentation/login_page.dart';
import 'features/pets/presentation/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // 2. Inicializar Supabase
  await SupabaseClientManager.initialize();

  // 3. ✅ NUEVO: Inicializar Deep Links
  DeepLinkHandler().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // ✅ NUEVO: Manejar deep links
    DeepLinkHandler().onDeepLink = (Uri uri) {
      print('🔗 Deep link recibido en MyApp: $uri');
      
      // Si viene de auth callback
      if (uri.toString().contains('auth/callback')) {
        print('✅ Redirigiendo al Home...');
        
        // Esperar un momento para que la UI esté lista
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
          
          // Mostrar mensaje de bienvenida
          Future.delayed(const Duration(milliseconds: 300), () {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ ¡Bienvenido a PetAdopt!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        });
      }
    };
  }

  @override
  void dispose() {
    DeepLinkHandler().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetAdopt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,

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