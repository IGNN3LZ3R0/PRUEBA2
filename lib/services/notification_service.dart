import 'dart:async';
import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import '../core/constants.dart';

/// Sistema de notificaciones ULTRA SIMPLE
/// - Sin plugins externos
/// - Sin configuraciones complejas
/// - Solo polling cada 15 segundos
/// - Alertas visuales dentro de la app
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  Timer? _timer;
  int _lastPendingCount = 0;
  List<Map<String, dynamic>> _lastRequests = [];
  
  // Callbacks para notificar cambios
  Function(int count)? onPendingCountChanged;
  Function(Map<String, dynamic> request)? onNewRequest;
  Function(Map<String, dynamic> request)? onRequestStatusChanged;

  bool _isRunning = false;

  // ========== INICIAR SERVICIO ==========
  void start(String userId, bool isRefugio) {
    if (_isRunning) return;
    
    _isRunning = true;
    _lastPendingCount = 0;
    _lastRequests = [];

    print('🔔 Servicio de notificaciones iniciado (polling cada 15s)');

    // Verificar inmediatamente
    _checkNotifications(userId, isRefugio);

    // Luego cada 15 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkNotifications(userId, isRefugio);
    });
  }

  // ========== DETENER SERVICIO ==========
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('🔴 Servicio de notificaciones detenido');
  }

  // ========== VERIFICAR NOTIFICACIONES ==========
  Future<void> _checkNotifications(String userId, bool isRefugio) async {
    try {
      final field = isRefugio ? 'refugio_id' : 'adoptante_id';

      // Obtener solicitudes pendientes
      final response = await SupabaseClientManager.instance.client
          .from(AppConstants.adoptionRequestsTable)
          .select('*')
          .eq(field, userId)
          .order('created_at', ascending: false);

      final requests = response as List<dynamic>;
      final currentRequests = requests.cast<Map<String, dynamic>>();

      // Contar pendientes
      final pendingCount = currentRequests
          .where((r) => r['status'] == AppConstants.statusPending)
          .length;

      // 1. DETECTAR NUEVAS SOLICITUDES
      if (currentRequests.isNotEmpty && _lastRequests.isNotEmpty) {
        for (var request in currentRequests) {
          final isNew = !_lastRequests.any((old) => old['id'] == request['id']);
          
          if (isNew && request['status'] == AppConstants.statusPending) {
            print('🆕 Nueva solicitud detectada: ${request['pet_name']}');
            onNewRequest?.call(request);
          }
        }
      }

      // 2. DETECTAR CAMBIOS DE ESTADO
      if (_lastRequests.isNotEmpty) {
        for (var request in currentRequests) {
          final oldRequest = _lastRequests.firstWhere(
            (old) => old['id'] == request['id'],
            orElse: () => <String, dynamic>{},
          );

          if (oldRequest.isNotEmpty && 
              oldRequest['status'] != request['status'] &&
              request['status'] != AppConstants.statusPending) {
            print('🔄 Estado cambiado: ${request['pet_name']} → ${request['status']}');
            onRequestStatusChanged?.call(request);
          }
        }
      }

      // 3. ACTUALIZAR CONTADOR
      if (pendingCount != _lastPendingCount) {
        print('📊 Pendientes: $_lastPendingCount → $pendingCount');
        onPendingCountChanged?.call(pendingCount);
      }

      _lastPendingCount = pendingCount;
      _lastRequests = currentRequests;

    } catch (e) {
      print('❌ Error verificando notificaciones: $e');
    }
  }

  // ========== OBTENER CONTADOR ACTUAL ==========
  Future<int> getPendingCount(String userId, bool isRefugio) async {
    try {
      final field = isRefugio ? 'refugio_id' : 'adoptante_id';

      final response = await SupabaseClientManager.instance.client
          .from(AppConstants.adoptionRequestsTable)
          .select('id')
          .eq(field, userId)
          .eq('status', AppConstants.statusPending);

      return (response as List).length;
    } catch (e) {
      print('❌ Error obteniendo contador: $e');
      return 0;
    }
  }

  // ========== VERIFICAR SI HAY CAMBIOS MANUALES ==========
  Future<void> checkNow(String userId, bool isRefugio) async {
    await _checkNotifications(userId, isRefugio);
  }
}

// ========== WIDGET: Badge de Notificaciones ==========
class NotificationBadge extends StatefulWidget {
  final Widget child;
  final String userId;
  final bool isRefugio;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.userId,
    required this.isRefugio,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _setupListener();
  }

  Future<void> _loadCount() async {
    final count = await NotificationService()
        .getPendingCount(widget.userId, widget.isRefugio);
    if (mounted) {
      setState(() => _count = count);
    }
  }

  void _setupListener() {
    NotificationService().onPendingCountChanged = (count) {
      if (mounted) {
        setState(() => _count = count);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return widget.child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Center(
              child: Text(
                _count > 9 ? '9+' : _count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ========== WIDGET: Alerta Visual In-App ==========
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> 
    with SingleTickerProviderStateMixin {
  
  final List<_NotificationItem> _notifications = [];
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Escuchar nuevas solicitudes
    NotificationService().onNewRequest = (request) {
      if (mounted) {
        _showNotification(
          title: '🐾 Nueva solicitud',
          message: '${request['adoptante_name']} quiere adoptar a ${request['pet_name']}',
          color: Colors.blue,
        );
      }
    };

    // Escuchar cambios de estado
    NotificationService().onRequestStatusChanged = (request) {
      if (mounted) {
        final status = request['status'];
        if (status == AppConstants.statusApproved) {
          _showNotification(
            title: '✅ ¡Solicitud Aprobada!',
            message: 'Tu solicitud para adoptar a ${request['pet_name']} fue aprobada',
            color: Colors.green,
          );
        } else if (status == AppConstants.statusRejected) {
          _showNotification(
            title: '❌ Solicitud Rechazada',
            message: 'Tu solicitud para adoptar a ${request['pet_name']} fue rechazada',
            color: Colors.red,
          );
        }
      }
    };
  }

  void _showNotification({
    required String title,
    required String message,
    required Color color,
  }) {
    final item = _NotificationItem(
      title: title,
      message: message,
      color: color,
      timestamp: DateTime.now(),
    );

    setState(() {
      _notifications.add(item);
    });

    // Auto-remover después de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _notifications.remove(item);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Overlay de notificaciones
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              children: _notifications.map((item) {
                return _NotificationCard(item: item);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationItem {
  final String title;
  final String message;
  final Color color;
  final DateTime timestamp;

  _NotificationItem({
    required this.title,
    required this.message,
    required this.color,
    required this.timestamp,
  });
}

class _NotificationCard extends StatefulWidget {
  final _NotificationItem item;

  const _NotificationCard({required this.item});

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.item.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.notifications_active,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}