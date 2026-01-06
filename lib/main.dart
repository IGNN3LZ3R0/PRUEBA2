import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/deep_link_handler.dart';
import 'services/notification_service.dart'; // 🔥 AÑADIR

import 'features/auth/presentation/login_page.dart';
import 'features/pets/presentation/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final DeepLinkHandler deepLinkHandler = DeepLinkHandler();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await SupabaseClientManager.initialize();

  // 🔥 INICIALIZAR NOTIFICACIONES AQUÍ (como en fitness_tracker)
  await NotificationService().initialize();

  // Inicializar deep link handler
  deepLinkHandler.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<AuthState> _authSubscription;
  bool _processingDeepLink = false;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkHandler();
    _setupAuthListener();
  }

  void _setupDeepLinkHandler() {
    deepLinkHandler.onDeepLink = (Uri uri) async {
      if (_processingDeepLink) return;
      _processingDeepLink = true;

      debugPrint('🔗 Deep link recibido: $uri');
      
      final nav = navigatorKey.currentState;
      final context = navigatorKey.currentContext;

      if (nav == null || context == null) {
        _processingDeepLink = false;
        return;
      }

      try {
        // Manejar diferentes tipos de deep links
        if (uri.toString().contains('auth/callback')) {
          final params = uri.queryParameters;
          final type = params['type'] ?? 'signup';
          final success = params['success'] == 'true';

          debugPrint('📱 Tipo de operación: $type');
          debugPrint('✅ Éxito: $success');

          if (type == 'recovery') {
            // Si viene de recuperación de contraseña
            if (success) {
              // Mostrar mensaje de éxito
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Contraseña actualizada correctamente. Por favor, inicia sesión.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            
            // Siempre redirigir al login después de recuperación
            // (para que el usuario inicie sesión con la nueva contraseña)
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          } else {
            // Login normal (verificación de email, etc.)
            // Esperar un momento para que Supabase procese la sesión
            await Future.delayed(const Duration(seconds: 1));
            
            // Verificar si hay sesión activa
            final session = SupabaseClientManager.instance.client.auth.currentSession;
            
            if (session != null) {
              // Redirigir al home
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bienvenido a PetAdopt'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              // Si no hay sesión, ir al login
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error procesando deep link: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        _processingDeepLink = false;
      }
    };
  }

  void _setupAuthListener() {
    _authSubscription = SupabaseClientManager.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('🔐 Auth event: ${data.event}');
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetAdopt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,

      home: SupabaseClientManager.instance.isAuthenticated
          ? const HomePage()
          : const LoginPage(),

      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
      },
    );
  }
}