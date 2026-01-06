import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/deep_link_handler.dart';

import 'features/auth/presentation/login_page.dart';
import 'features/pets/presentation/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final DeepLinkHandler deepLinkHandler = DeepLinkHandler();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await SupabaseClientManager.initialize();

  // 🔥 ASIGNAR CALLBACK ANTES
  deepLinkHandler.onDeepLink = _handleDeepLinkStatic;

  // 🔥 LUEGO inicializar
  deepLinkHandler.initialize();

  runApp(const MyApp());
}

/// 🔥 FUNCIÓN ESTÁTICA (NO DEPENDE DEL STATE)
void _handleDeepLinkStatic(Uri uri) {
  debugPrint('🔗 Deep link recibido: $uri');

  final nav = navigatorKey.currentState;
  final context = navigatorKey.currentContext;

  if (nav == null || context == null) return;

  // ✅ ÚNICO CALLBACK NECESARIO
  if (uri.toString().contains('auth/callback')) {
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
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
