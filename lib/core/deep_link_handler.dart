import 'dart:async';
import 'package:uni_links/uni_links.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  StreamSubscription? _sub;
  
  // Callback cuando se recibe un deep link
  Function(Uri)? onDeepLink;

  /// Inicializar listener de deep links
  void initialize() {
    print('🔗 Inicializando Deep Link Handler...');
    
    // Manejar el link inicial (cuando la app se abre desde un link)
    _handleInitialUri();
    
    // Escuchar links mientras la app está abierta
    _sub = uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          print('✅ Deep link recibido: $uri');
          onDeepLink?.call(uri);
        }
      },
      onError: (err) {
        print('❌ Error en deep link: $err');
      },
    );
  }

  /// Manejar link inicial
  Future<void> _handleInitialUri() async {
    try {
      final uri = await getInitialUri();
      if (uri != null) {
        print('✅ Link inicial detectado: $uri');
        onDeepLink?.call(uri);
      }
    } catch (e) {
      print('❌ Error al obtener link inicial: $e');
    }
  }

  /// Limpiar listener
  void dispose() {
    _sub?.cancel();
  }
}