import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/data/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_page.dart';
import '../data/pet_repository.dart';
import '../data/models.dart';
import 'pet_detail_page.dart';
import 'create_pet_page.dart';
import 'widgets/pet_card.dart';
import '../../chat/presentation/chat_page.dart';
import '../../map/presentation/map_page.dart';
import '../../adoptions/presentation/my_requests_page.dart';
import '../../adoptions/presentation/shelter_dashboard_page.dart';
import '../../../services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _petRepository = PetRepository();
  final _authRepository = AuthRepository();

  List<PetModel> _pets = [];
  List<PetModel> _filteredPets = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  UserModel? _currentUser;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndPets();
    _startNotifications();
  }

  @override
  void dispose() {
    NotificationService().stop();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndPets() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseClientManager.instance.userId;
      if (userId != null) {
        _currentUser = await _authRepository.getUserProfile(userId);
      }
      await _loadPets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startNotifications() async {
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser != null) {
      NotificationService().start(
        _currentUser!.id,
        _currentUser!.isRefugio,
      );

      NotificationService().onNewRequest = (request) {
        if (mounted) {
          _showNotificationSnackBar(
            title: '🐾 Nueva solicitud',
            message: '${request['adoptante_name']} quiere adoptar a tu mascota',
            backgroundColor: Colors.blue,
          );
        }
      };

      NotificationService().onRequestStatusChanged = (request) {
        if (mounted) {
          final status = request['status'];
          final isApproved = status == AppConstants.statusApproved;
          
          _showNotificationSnackBar(
            title: isApproved ? '✅ ¡Solicitud aprobada!' : '❌ Solicitud rechazada',
            message: isApproved 
                ? 'Tu solicitud de adopción ha sido aprobada'
                : 'Tu solicitud de adopción ha sido rechazada',
            backgroundColor: isApproved ? Colors.green : Colors.red,
          );
        }
      };
    }
  }

  void _showNotificationSnackBar({
    required String title,
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // 🆕 NUEVO: Método para simular notificaciones de prueba
  void _simularNotificacionPrueba() {
    if (_currentUser == null) return;

    // Simular diferentes tipos de notificaciones
    final tiposNotificaciones = [
      {
        'title': '🐕 Nueva solicitud de adopción',
        'message': 'María quiere adoptar a "Max"',
        'color': Colors.blue,
        'tipo': 'nueva_solicitud',
      },
      {
        'title': '✅ ¡Solicitud aprobada!',
        'message': 'Tu solicitud para adoptar a "Luna" fue aprobada',
        'color': Colors.green,
        'tipo': 'solicitud_aprobada',
      },
      {
        'title': '❌ Solicitud rechazada',
        'message': 'Tu solicitud para adoptar a "Rocky" fue rechazada',
        'color': Colors.red,
        'tipo': 'solicitud_rechazada',
      },
      {
        'title': '💬 Nuevo mensaje',
        'message': 'Tienes un nuevo mensaje sobre una adopción',
        'color': Colors.purple,
        'tipo': 'nuevo_mensaje',
      },
    ];

    // Seleccionar una notificación aleatoria
    final notificacion = tiposNotificaciones[
        DateTime.now().millisecondsSinceEpoch % tiposNotificaciones.length];

    _showNotificationSnackBar(
      title: notificacion['title'] as String,
      message: notificacion['message'] as String,
      backgroundColor: notificacion['color'] as Color,
    );

    // También simular la llamada al servicio de notificaciones
    if (_currentUser!.isRefugio) {
      // Simular notificación para refugio
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📡 Notificación de prueba enviada para refugio: ${notificacion['tipo']}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Simular notificación para adoptante
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📡 Notificación de prueba enviada para adoptante: ${notificacion['tipo']}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _loadPets() async {
    try {
      _pets = await _petRepository.getPets();
      _filteredPets = _pets;
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mascotas: $e')),
        );
      }
    }
  }

  void _filterPets(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'all') {
        _filteredPets = _pets;
      } else {
        _filteredPets = _pets.where((pet) => pet.species == filter).toList();
      }
    });
  }

  void _searchPets(String query) {
    if (query.isEmpty) {
      _filterPets(_selectedFilter);
      return;
    }

    setState(() {
      _filteredPets = _pets.where((pet) {
        return pet.name.toLowerCase().contains(query.toLowerCase()) ||
            (pet.breed?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    });
  }

  Future<void> _logout() async {
    try {
      await _authRepository.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildHomePage(),
      const ChatPage(),
      const MapPage(),
      _currentUser?.isAdoptante == true
          ? const MyRequestsPage()
          : const ShelterDashboardPage(),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
      // 🆕 BOTÓN PARA SIMULAR NOTIFICACIONES (solo en desarrollo/testing)
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Botón principal para simular notificaciones
          FloatingActionButton(
            onPressed: _simularNotificacionPrueba,
            backgroundColor: Colors.orange,
            heroTag: 'simular_notificacion',
            tooltip: 'Simular notificación de prueba',
            child: const Icon(
              Icons.notification_add,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Botón para verificar notificaciones reales
          if (_currentUser != null)
            FloatingActionButton(
              onPressed: () {
                NotificationService().checkNow(
                  _currentUser!.id,
                  _currentUser!.isRefugio,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔍 Verificando notificaciones reales...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              heroTag: 'verificar_notificaciones',
              tooltip: 'Verificar notificaciones reales',
              mini: true,
              child: const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHomePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetAdopt'),
        actions: [
          // 🆕 BOTÓN EN APP BAR PARA PRUEBAS RÁPIDAS
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.notification_important),
              tooltip: 'Enviar notificación de prueba',
              onPressed: _simularNotificacionPrueba,
            ),
          if (_currentUser?.isRefugio == true)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePetPage()),
                );
                if (result == true) _loadPets();
              },
            ),
          PopupMenuButton(
            icon: const Icon(Icons.person),
            itemBuilder: (context) => <PopupMenuEntry>[
              PopupMenuItem(
                child: Text(_currentUser?.fullName ?? 'Usuario'),
                enabled: false,
              ),
              PopupMenuItem(
                child: Text(
                    _currentUser?.isRefugio == true ? 'Refugio' : 'Adoptante'),
                enabled: false,
              ),
              // 🆕 OPCIÓN EN MENÚ PARA SIMULAR NOTIFICACIONES
              if (_currentUser != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  onTap: _simularNotificacionPrueba,
                  child: const Row(
                    children: [
                      Icon(Icons.notification_add, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Simular notificación'),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Cargando mascotas...')
          : RefreshIndicator(
              onRefresh: _loadPets,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 700) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 300,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterChips(),
                              const SizedBox(height: 16),
                              // 🆕 BOTÓN DE PRUEBA EN PANEL LATERAL
                              if (_currentUser != null)
                                ElevatedButton.icon(
                                  onPressed: _simularNotificacionPrueba,
                                  icon: const Icon(Icons.notification_add, size: 18),
                                  label: const Text('Probar Notificación'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Mascotas (${_filteredPets.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _buildSearchBar(),
                              Expanded(child: _buildPetGrid()),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildSearchBar(),
                        _buildFilterChips(),
                        Expanded(child: _buildPetGrid()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        if (_currentUser != null) {
          NotificationService().checkNow(
            _currentUser!.id,
            _currentUser!.isRefugio,
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textGrey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chat IA',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Mapa',
        ),
        BottomNavigationBarItem(
          icon: _currentUser != null
              ? NotificationBadge(
                  userId: _currentUser!.id,
                  isRefugio: _currentUser!.isRefugio,
                  child: const Icon(Icons.favorite),
                )
              : const Icon(Icons.favorite),
          label: _currentUser?.isRefugio == true
              ? 'Solicitudes'
              : 'Mis Solicitudes',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _searchPets,
        decoration: InputDecoration(
          hintText: AppStrings.searchPet,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: AppStrings.all,
            isSelected: _selectedFilter == 'all',
            onTap: () => _filterPets('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: AppStrings.dogs,
            isSelected: _selectedFilter == AppConstants.speciesDog,
            onTap: () => _filterPets(AppConstants.speciesDog),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: AppStrings.cats,
            isSelected: _selectedFilter == AppConstants.speciesCat,
            onTap: () => _filterPets(AppConstants.speciesCat),
          ),
        ],
      ),
    );
  }

  Widget _buildPetGrid() {
    if (_filteredPets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 80,
              color: AppTheme.textGrey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay mascotas disponibles',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
            ),
            // 🆕 BOTÓN DE PRUEBA EN ESTADO VACÍO
            if (_currentUser != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton.icon(
                  onPressed: _simularNotificacionPrueba,
                  icon: const Icon(Icons.notification_add),
                  label: const Text('Probar Notificaciones'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isWide = maxWidth > 800;
        final childAspect = isWide ? 1.0 : 0.75;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isWide ? 350 : 300,
            childAspectRatio: childAspect,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredPets.length,
          itemBuilder: (context, index) {
            return PetCard(
              pet: _filteredPets[index],
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PetDetailPage(pet: _filteredPets[index]),
                  ),
                );
                if (result == true) _loadPets();
              },
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.textGrey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}