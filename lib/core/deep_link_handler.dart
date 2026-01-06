import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Function(Uri)? onDeepLink;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        onDeepLink?.call(uri);
      },
    );

    _handleInitialUri();
  }

  Future<void> _handleInitialUri() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      Future.microtask(() => onDeepLink?.call(uri));
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
