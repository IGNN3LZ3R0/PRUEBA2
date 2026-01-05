import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/location_repository.dart';
import '../data/models.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _locationRepo = LocationRepository();
  final _mapController = MapController();
  
  UserLocation? _userLocation;
  List<ShelterMarker> _shelters = [];
  bool _isLoading = true;
  bool _followUser = true;
  ShelterMarker? _selectedShelter;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    try {
      // 1. Obtener ubicación del usuario
      _userLocation = await _locationRepo.getCurrentLocation();

      // 2. Cargar refugios cercanos
      await _loadShelters();

      // 3. Centrar mapa en usuario
      if (_userLocation != null) {
        _mapController.move(_userLocation!.toLatLng(), 13.0);
      }
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

  Future<void> _loadShelters() async {
    try {
      final response = await SupabaseClientManager.instance.client
          .from(AppConstants.profilesTable)
          .select('''
            id,
            full_name,
            address,
            phone,
            pets!refugio_id(id, latitude, longitude)
          ''')
          .eq('user_type', AppConstants.userTypeRefugio);

      final shelters = <ShelterMarker>[];

      for (final shelter in response) {
        final pets = shelter['pets'] as List?;
        if (pets != null && pets.isNotEmpty) {
          // Usar ubicación de la primera mascota como ubicación del refugio
          final firstPet = pets.first;
          final lat = firstPet['latitude'] as double?;
          final lon = firstPet['longitude'] as double?;

          if (lat != null && lon != null) {
            shelters.add(ShelterMarker(
              id: shelter['id'] as String,
              name: shelter['full_name'] as String? ?? 'Refugio',
              address: shelter['address'] as String?,
              phone: shelter['phone'] as String?,
              latitude: lat,
              longitude: lon,
              petsCount: pets.length,
            ));
          }
        }
      }

      setState(() => _shelters = shelters);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar refugios: $e')),
        );
      }
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!.toLatLng(), 15.0);
      setState(() => _followUser = true);
    }
  }

  void _centerOnShelter(ShelterMarker shelter) {
    _mapController.move(shelter.toLatLng(), 16.0);
    setState(() {
      _selectedShelter = shelter;
      _followUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Cargando mapa...'),
      );
    }

    if (_userLocation == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                size: 80,
                color: AppTheme.textGrey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No se pudo obtener tu ubicación',
                style: TextStyle(fontSize: 16, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeMap,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mapa de Refugios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShelters,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation!.toLatLng(),
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (_, __) => setState(() => _selectedShelter = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.petadoptprueba2b',
              ),
              MarkerLayer(
                markers: [
                  // Marcador del usuario
                  Marker(
                    point: _userLocation!.toLatLng(),
                    width: 60,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  // Marcadores de refugios
                  ..._shelters.map((shelter) {
                    final isSelected = _selectedShelter?.id == shelter.id;
                    return Marker(
                      point: shelter.toLatLng(),
                      width: isSelected ? 80 : 60,
                      height: isSelected ? 80 : 60,
                      child: GestureDetector(
                        onTap: () => _centerOnShelter(shelter),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.secondary
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.home,
                                color: AppTheme.secondary,
                                size: isSelected ? 40 : 30,
                              ),
                            ),
                            if (shelter.petsCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    shelter.petsCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Botón centrar en usuario
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'center_user',
              onPressed: _centerOnUser,
              backgroundColor:
                  _followUser ? AppTheme.primary : Colors.white,
              child: Icon(
                Icons.my_location,
                color: _followUser ? Colors.white : AppTheme.primary,
              ),
            ),
          ),

          // Info del refugio seleccionado
          if (_selectedShelter != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _ShelterInfoCard(
                shelter: _selectedShelter!,
                userLocation: _userLocation!,
                locationRepo: _locationRepo,
                onClose: () => setState(() => _selectedShelter = null),
              ),
            ),

          // Lista de refugios (desplegable)
          if (_shelters.isNotEmpty && _selectedShelter == null)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'show_list',
                onPressed: _showSheltersList,
                backgroundColor: Colors.white,
                icon: const Icon(Icons.list, color: AppTheme.primary),
                label: Text(
                  '${_shelters.length} refugios',
                  style: const TextStyle(color: AppTheme.textDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSheltersList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Refugios Cercanos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _shelters.length,
                itemBuilder: (context, index) {
                  final shelter = _shelters[index];
                  final distance = _locationRepo.calculateDistance(
                    _userLocation!.latitude,
                    _userLocation!.longitude,
                    shelter.latitude,
                    shelter.longitude,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home,
                          color: AppTheme.secondary,
                        ),
                      ),
                      title: Text(
                        shelter.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shelter.address != null)
                            Text(
                              shelter.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.pets,
                                  size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('${shelter.petsCount} mascotas'),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on,
                                  size: 14, color: AppTheme.textGrey),
                              const SizedBox(width: 4),
                              Text(_locationRepo.formatDistance(distance)),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _centerOnShelter(shelter);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelterInfoCard extends StatelessWidget {
  final ShelterMarker shelter;
  final UserLocation userLocation;
  final LocationRepository locationRepo;
  final VoidCallback onClose;

  const _ShelterInfoCard({
    required this.shelter,
    required this.userLocation,
    required this.locationRepo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final distance = locationRepo.calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      shelter.latitude,
      shelter.longitude,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shelter.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (shelter.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppTheme.textGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shelter.address!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.pets,
                  label: '${shelter.petsCount} mascotas',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.location_on,
                  label: locationRepo.formatDistance(distance),
                  color: AppTheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}