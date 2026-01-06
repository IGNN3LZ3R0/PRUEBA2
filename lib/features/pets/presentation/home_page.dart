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
    _startNotifications(); // 🆕 AGREGA ESTO
  }

  @override
  void dispose() {
    NotificationService().stop(); // 🆕 LIMPIAR
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

  // 🆕 NUEVO MÉTODO
  void _startNotifications() async {
    // Esperar a que cargue el usuario
    await Future.delayed(const Duration(seconds: 1));

    if (_currentUser != null) {
      NotificationService().start(
        _currentUser!.id,
        _currentUser!.isRefugio,
      );

      // Configurar callbacks para mostrar alertas
      NotificationService().onNewRequest = (request) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.pets, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🐾 Nueva solicitud',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${request['adoptante_name']} quiere adoptar'),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      };

      NotificationService().onRequestStatusChanged = (request) {
        if (mounted) {
          final status = request['status'];
          final isApproved = status == AppConstants.statusApproved;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isApproved ? '✅ ¡Solicitud aprobada!' : '❌ Solicitud rechazada',
              ),
              backgroundColor: isApproved ? Colors.green : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      };
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
    if (_selectedIndex == 1) return const ChatPage();
    if (_selectedIndex == 2) return const MapPage();
    if (_selectedIndex == 3) {
      return _currentUser?.isAdoptante == true
          ? const MyRequestsPage()
          : const ShelterDashboardPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PetAdopt'),
        actions: [
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
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  Expanded(child: _buildPetGrid()),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Actualizar notificaciones al cambiar de pestaña
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
            // 🆕 CON BADGE
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
      ),
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
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
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
