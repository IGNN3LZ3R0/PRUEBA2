import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import '../core/supabase_client.dart';
import '../core/constants.dart';

/// Sistema de notificaciones usando flutter_local_notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  int _lastPendingCount = 0;
  List<Map<String, dynamic>> _lastRequests = [];
  
  // Callbacks para notificar cambios
  Function(int count)? onPendingCountChanged;
  Function(Map<String, dynamic> request)? onNewRequest;
  Function(Map<String, dynamic> request)? onRequestStatusChanged;

  bool _isRunning = false;
  bool _isInitialized = false;

  // ========== INICIALIZAR PLUGIN ==========
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configuración Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuración iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      print('✅ NotificationService inicializado correctamente');

      // Solicitar permisos automáticamente
      await requestPermissions();
      
    } catch (e) {
      print('❌ Error inicializando NotificationService: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notificación presionada: ${response.payload}');
  }

  // ========== SOLICITAR PERMISOS ==========
  Future<bool> requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          print('✅ Permisos de notificación concedidos');
          return true;
        }
      }

      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  // ========== MOSTRAR NOTIFICACIÓN DE PRUEBA ==========
  Future<void> showTestNotification(String title, String message, Color color) async {
    if (!_isInitialized) {
      print('⚠️ NotificationService no inicializado. Llamando initialize()...');
      await initialize();
    }

    try {
      // Determinar color según el tipo
      final androidColor = color == Colors.blue
          ? const Color(0xFF2196F3)
          : color == Colors.green
              ? const Color(0xFF4CAF50)
              : color == Colors.red
                  ? const Color(0xFFF44336)
                  : const Color(0xFFFF9800);

      final androidDetails = AndroidNotificationDetails(
        'petadopt_channel',
        'PetAdopt Notifications',
        channelDescription: 'Notificaciones de adopciones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        color: androidColor,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        message,
        notificationDetails,
        payload: 'test_notification',
      );

      print('✅ Notificación de prueba mostrada: $title');
    } catch (e) {
      print('❌ Error mostrando notificación de prueba: $e');
    }
  }

  // ========== MOSTRAR NOTIFICACIÓN DE NUEVA SOLICITUD ==========
  Future<void> showNewRequestNotification(String adoptanteName, String petName) async {
    if (!_isInitialized) await initialize();

    try {
      final androidDetails = AndroidNotificationDetails(
        'petadopt_channel',
        'PetAdopt Notifications',
        channelDescription: 'Notificaciones de adopciones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        color: const Color(0xFF2196F3),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        1,
        '🐾 Nueva solicitud',
        '$adoptanteName quiere adoptar a $petName',
        notificationDetails,
        payload: 'new_request',
      );

      print('✅ Notificación de nueva solicitud mostrada');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ========== MOSTRAR NOTIFICACIÓN DE CAMBIO DE ESTADO ==========
  Future<void> showStatusChangeNotification(String petName, bool isApproved) async {
    if (!_isInitialized) await initialize();

    try {
      final androidDetails = AndroidNotificationDetails(
        'petadopt_channel',
        'PetAdopt Notifications',
        channelDescription: 'Notificaciones de adopciones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        color: isApproved ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        2,
        isApproved ? '✅ ¡Solicitud aprobada!' : '❌ Solicitud rechazada',
        isApproved
            ? 'Tu solicitud para adoptar a $petName fue aprobada'
            : 'Tu solicitud para adoptar a $petName fue rechazada',
        notificationDetails,
        payload: 'status_change',
      );

      print('✅ Notificación de cambio de estado mostrada');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ========== INICIAR SERVICIO ==========
  void start(String userId, bool isRefugio) {
    if (_isRunning) return;
    
    _isRunning = true;
    _lastPendingCount = 0;
    _lastRequests = [];

    print('🔔 Servicio de notificaciones iniciado (polling cada 15s)');

    _checkNotifications(userId, isRefugio);

    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
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

      final response = await SupabaseClientManager.instance.client
          .from(AppConstants.adoptionRequestsTable)
          .select('*')
          .eq(field, userId)
          .order('created_at', ascending: false);

      final requests = response as List<dynamic>;
      final currentRequests = requests.cast<Map<String, dynamic>>();

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
            
            // Mostrar notificación del sistema
            if (isRefugio) {
              await showNewRequestNotification(
                request['adoptante_name'] ?? 'Usuario',
                request['pet_name'] ?? 'mascota',
              );
            }
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
            
            // Mostrar notificación del sistema
            if (!isRefugio) {
              await showStatusChangeNotification(
                request['pet_name'] ?? 'mascota',
                request['status'] == AppConstants.statusApproved,
              );
            }
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