import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  late MapController _mapController; // AHORA ES NULLABLE

  UserLocation? _userLocation;
  List<ShelterMarker> _allShelters = [];
  List<ShelterMarker> _nearbyShelters = [];
  bool _isLoading = true;
  bool _followUser = true;
  ShelterMarker? _selectedShelter;

  double _searchRadiusMeters = LocationRepository.DEFAULT_SEARCH_RADIUS_METERS;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    try {
      _userLocation = await _locationRepo.getCurrentLocation();
      await _loadShelters();
      _filterSheltersByRadius();
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
          ''').eq('user_type', AppConstants.userTypeRefugio);

      final shelters = <ShelterMarker>[];

      for (final shelter in response) {
        final pets = shelter['pets'] as List?;
        if (pets != null && pets.isNotEmpty) {
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

      setState(() => _allShelters = shelters);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar refugios: $e')),
        );
      }
    }
  }

  void _filterSheltersByRadius() {
    if (_userLocation == null) return;

    setState(() {
      _nearbyShelters = _locationRepo.filterByRadius(
        items: _allShelters,
        userLat: _userLocation!.latitude,
        userLon: _userLocation!.longitude,
        getItemLat: (shelter) => shelter.latitude,
        getItemLon: (shelter) => shelter.longitude,
        radiusInMeters: _searchRadiusMeters,
      );
    });
  }

  // MÉTODO SEGURO PARA MOVER EL MAPA
  void _centerOnUser() {
    if (_userLocation != null && _mapController != null) {
      _mapController!.move(_userLocation!.toLatLng(), 15.0);
      setState(() => _followUser = true);
    }
  }

  void _centerOnShelter(ShelterMarker shelter) {
    if (_mapController != null) {
      _mapController!.move(shelter.toLatLng(), 16.0);
      setState(() {
        _selectedShelter = shelter;
        _followUser = false;
      });
    }
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
              const Icon(Icons.location_off, size: 80, color: AppTheme.textGrey),
              const SizedBox(height: 16),
              const Text('No se pudo obtener tu ubicación',
                  style: TextStyle(fontSize: 16, color: AppTheme.textGrey)),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Refugios Cercanos'),
            Text(
              '${_nearbyShelters.length} en ${(_searchRadiusMeters / 1000).toStringAsFixed(0)} km',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRadiusSelector,
            tooltip: 'Ajustar radio',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadShelters();
              _filterSheltersByRadius();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPA CON onMapReady CALLBACK
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation!.toLatLng(),
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: (_, __) => setState(() => _selectedShelter = null),
              // 🔥 NUEVO: Inicializar controller cuando el mapa esté listo
              onMapReady: () {
                debugPrint('MapController inicializado');
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.petadoptprueba2b',
              ),

              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation!.toLatLng(),
                    radius: _searchRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderColor: AppTheme.primary.withValues(alpha: 0.5),
                    borderStrokeWidth: 2,
                  ),
                ],
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
                        child: Icon(Icons.my_location, color: Colors.blue, size: 28),
                      ),
                    ),
                  ),
                  // Marcadores de refugios
                  ..._nearbyShelters.map((shelter) {
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
                                color: AppTheme.secondary.withValues(alpha: 0.2),
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

          if (_nearbyShelters.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _NoSheltersAlert(
                onExpandRadius: () => _changeSearchRadius(10),
              ),
            ),

          // Botón centrar en usuario
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'center_user',
              onPressed: _centerOnUser,
              backgroundColor: _followUser ? AppTheme.primary : Colors.white,
              child: Icon(
                Icons.my_location,
                color: _followUser ? Colors.white : AppTheme.primary,
              ),
            ),
          ),

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

          if (_nearbyShelters.isNotEmpty && _selectedShelter == null)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'show_list',
                onPressed: _showSheltersList,
                backgroundColor: Colors.white,
                icon: const Icon(Icons.list, color: AppTheme.primary),
                label: Text(
                  '${_nearbyShelters.length} refugios',
                  style: const TextStyle(color: AppTheme.textDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRadiusSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Radio de búsqueda',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 24),
            _RadiusOption(
              label: '1 km - Muy cerca',
              radiusKm: 1,
              isSelected: _searchRadiusMeters == 1000,
              onTap: () {
                _changeSearchRadius(1);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _RadiusOption(
              label: '5 km - Cerca',
              radiusKm: 5,
              isSelected: _searchRadiusMeters == 5000,
              onTap: () {
                _changeSearchRadius(5);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _RadiusOption(
              label: '10 km - Medio',
              radiusKm: 10,
              isSelected: _searchRadiusMeters == 10000,
              onTap: () {
                _changeSearchRadius(10);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _RadiusOption(
              label: '20 km - Lejos',
              radiusKm: 20,
              isSelected: _searchRadiusMeters == 20000,
              onTap: () {
                _changeSearchRadius(20);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeSearchRadius(double newRadiusKm) {
    setState(() {
      _searchRadiusMeters = newRadiusKm * 1000;
      _filterSheltersByRadius();
    });
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
              child: Text('Refugios Cercanos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _nearbyShelters.length,
                itemBuilder: (context, index) {
                  final shelter = _nearbyShelters[index];
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
                        child: const Icon(Icons.home, color: AppTheme.secondary),
                      ),
                      title: Text(shelter.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shelter.address != null)
                            Text(shelter.address!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.pets, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('${shelter.petsCount} mascotas'),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 14, color: AppTheme.textGrey),
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

// Widgets auxiliares (sin cambios)
class _NoSheltersAlert extends StatelessWidget {
  final VoidCallback onExpandRadius;
  const _NoSheltersAlert({required this.onExpandRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pending.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('No hay refugios cerca',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Intenta ampliar el radio de búsqueda',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onExpandRadius,
              icon: const Icon(Icons.zoom_out_map, size: 18),
              label: const Text('Ampliar a 10 km'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.pending,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusOption extends StatelessWidget {
  final String label;
  final double radiusKm;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadiusOption({
    required this.label,
    required this.radiusKm,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.textGrey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.radio_button_checked,
                color: isSelected ? Colors.white : AppTheme.textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  )),
            ),
            if (isSelected) const Icon(Icons.check, color: Colors.white),
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
                  child: Text(shelter.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
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
                  const Icon(Icons.location_on, size: 16, color: AppTheme.textGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(shelter.address!,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textGrey)),
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
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}