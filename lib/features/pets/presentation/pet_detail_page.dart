import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/data/auth_repository.dart';
import '../../adoptions/data/adoption_repository.dart';
import '../data/models.dart';
import '../data/pet_repository.dart';
import 'create_pet_page.dart';

class PetDetailPage extends StatefulWidget {
  final PetModel pet;

  const PetDetailPage({super.key, required this.pet});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  final _adoptionRepo = AdoptionRepository();
  final _authRepo = AuthRepository();
  final _petRepo = PetRepository();
  final _messageController = TextEditingController();
  
  late PetModel _pet;
  int _currentImageIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _loadPetDetails();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPetDetails() async {
    try {
      final petDetail = await _petRepo.getPetDetail(_pet.id);
      if (petDetail != null && mounted) {
        setState(() => _pet = petDetail);
      }
    } catch (e) {
      // Error silencioso, ya tenemos los datos básicos
    }
  }

  Future<void> _requestAdoption() async {
    final currentUser = await _authRepo.getUserProfile(
      SupabaseClientManager.instance.userId!,
    );

    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Adopción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Deseas solicitar la adopción de ${_pet.name}?'),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Mensaje (opcional)',
                hintText: 'Cuéntale al refugio por qué quieres adoptar',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _adoptionRepo.createRequest(
        petId: _pet.id,
        adoptanteId: currentUser.id,
        refugioId: _pet.refugioId,
        petName: _pet.name,
        refugioName: _pet.refugioName ?? 'Refugio',
        adoptanteName: currentUser.fullName,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud enviada! El refugio te contactará pronto.'),
            backgroundColor: AppTheme.approved,
          ),
        );
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

  Future<void> _editPet() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePetPage(pet: _pet),
      ),
    );

    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deletePet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mascota'),
        content: Text('¿Estás seguro de eliminar a ${_pet.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rejected),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _petRepo.deletePet(_pet.id);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mascota eliminada')),
        );
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseClientManager.instance.userId;
    final isOwner = currentUserId == _pet.refugioId;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: CustomScrollView(
          slivers: [
            // AppBar con imagen
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageGallery(),
              ),
              actions: [
                if (isOwner) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _editPet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deletePet,
                  ),
                ],
              ],
            ),

            // Contenido
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre y estado
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pet.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          if (_pet.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.approved.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Disponible',
                                style: TextStyle(
                                  color: AppTheme.approved,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (_pet.breed != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _pet.breed!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Características
                      _buildInfoGrid(),

                      const SizedBox(height: 24),

                      // Descripción
                      const Text(
                        'Sobre mí',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pet.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textDark,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Información médica
                      _buildMedicalInfo(),

                      if (_pet.specialNeeds != null) ...[
                        const SizedBox(height: 24),
                        _buildSpecialNeeds(),
                      ],

                      if (_pet.refugioName != null) ...[
                        const SizedBox(height: 24),
                        _buildShelterInfo(),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: !isOwner && _pet.isAvailable
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: CustomButton(
                  text: 'Solicitar Adopción',
                  onPressed: _requestAdoption,
                  icon: Icons.favorite,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildImageGallery() {
    if (_pet.imageUrls.isEmpty) {
      return Container(
        color: AppTheme.background,
        child: const Center(
          child: Icon(Icons.pets, size: 100, color: AppTheme.textGrey),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: _pet.imageUrls.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: _pet.imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.background,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.background,
                child: const Icon(Icons.error),
              ),
            );
          },
        ),
        if (_pet.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pet.imageUrls.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppTheme.primary
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return Row(
      children: [
        Expanded(child: _buildInfoCard(Icons.cake, 'Edad', _pet.ageText)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            _pet.gender == 'Macho' ? Icons.male : Icons.female,
            'Sexo',
            _pet.gender,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoCard(Icons.straighten, 'Tamaño', _pet.size)),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Médica',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildMedicalItem('Vacunado', _pet.isVaccinated),
          _buildMedicalItem('Desparasitado', _pet.isDewormed),
          _buildMedicalItem('Esterilizado', _pet.isSterilized),
          _buildMedicalItem('Microchip', _pet.hasMicrochip),
          if (_pet.healthStatus.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Estado: ${_pet.healthStatus}',
              style: const TextStyle(color: AppTheme.textDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalItem(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? AppTheme.approved : AppTheme.textGrey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: value ? AppTheme.textDark : AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialNeeds() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pending.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pending.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.pending),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Necesidades Especiales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pet.specialNeeds!,
                  style: const TextStyle(color: AppTheme.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelterInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home, color: AppTheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refugio',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
                Text(
                  _pet.refugioName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                if (_pet.refugioPhone != null)
                  Text(
                    _pet.refugioPhone!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textGrey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}