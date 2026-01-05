import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models.dart';
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
  final _authRepo = AuthRepository();
  final _adoptionRepo = AdoptionRepository();
  final _petRepo = PetRepository();
  final _pageController = PageController();

  UserModel? _currentUser;
  int _currentImageIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final userId = SupabaseClientManager.instance.userId;
    if (userId != null) {
      _currentUser = await _authRepo.getUserProfile(userId);
      setState(() {});
    }
  }

  Future<void> _requestAdoption() async {
    if (_currentUser == null) return;

    // Mostrar diálogo con mensaje opcional
    final messageController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Adopción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Deseas adoptar a ${widget.pet.name}?'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Mensaje para el refugio (opcional)',
                hintText: 'Cuéntanos por qué quieres adoptar...',
                border: OutlineInputBorder(),
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
            child: const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _adoptionRepo.createRequest(
          petId: widget.pet.id,
          adoptanteId: _currentUser!.id,
          refugioId: widget.pet.refugioId,
          petName: widget.pet.name,
          refugioName: widget.pet.refugioName ?? 'Refugio',
          adoptanteName: _currentUser!.fullName,
          message: messageController.text.trim().isEmpty
              ? null
              : messageController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Solicitud enviada! El refugio la revisará pronto.'),
              backgroundColor: AppTheme.approved,
            ),
          );
          Navigator.pop(context);
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
  }

  Future<void> _editPet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePetPage(pet: widget.pet),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mascota'),
        content: Text(
            '¿Estás seguro de eliminar a ${widget.pet.name}? Esta acción no se puede deshacer.'),
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

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _petRepo.deletePet(widget.pet.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mascota eliminada'),
              backgroundColor: AppTheme.rejected,
            ),
          );
          Navigator.pop(context, true);
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
  }

  bool get _isOwner => _currentUser?.id == widget.pet.refugioId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildInfoCards(),
                    const SizedBox(height: 24),
                    _buildAboutSection(),
                    const SizedBox(height: 24),
                    _buildHealthSection(),
                    if (widget.pet.specialNeeds != null) ...[
                      const SizedBox(height: 24),
                      _buildSpecialNeedsSection(),
                    ],
                    const SizedBox(height: 24),
                    _buildRefugioInfo(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.pet.imageUrls.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemCount: widget.pet.imageUrls.length,
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: widget.pet.imageUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.background,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.background,
                      child: const Icon(Icons.pets, size: 80),
                    ),
                  );
                },
              ),
            if (widget.pet.imageUrls.isEmpty)
              Container(
                color: AppTheme.background,
                child: const Center(
                  child: Icon(Icons.pets, size: 80, color: AppTheme.textGrey),
                ),
              ),
            // Gradiente inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Indicador de imágenes
            if (widget.pet.imageUrls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.pet.imageUrls.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_isOwner)
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _editPet,
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: _deletePet,
                child: const Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pet.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.pet.breed != null)
                Text(
                  widget.pet.breed!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textGrey,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.pet.isAvailable
                ? AppTheme.approved.withValues(alpha: 0.1)
                : AppTheme.textGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.pet.status == 'disponible' ? 'Disponible' : 'Adoptado',
            style: TextStyle(
              color: widget.pet.isAvailable ? AppTheme.approved : AppTheme.textGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.cake,
            label: 'Edad',
            value: widget.pet.ageText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            icon: widget.pet.gender == 'Macho' ? Icons.male : Icons.female,
            label: 'Sexo',
            value: widget.pet.gender,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            icon: Icons.straighten,
            label: 'Tamaño',
            value: widget.pet.size,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sobre mí',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.pet.description,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.textDark,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado de Salud',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.pet.healthStatus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services,
                    color: AppTheme.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.pet.healthStatus,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HealthBadge(
              label: 'Vacunado',
              isActive: widget.pet.isVaccinated,
            ),
            _HealthBadge(
              label: 'Desparasitado',
              isActive: widget.pet.isDewormed,
            ),
            _HealthBadge(
              label: 'Esterilizado',
              isActive: widget.pet.isSterilized,
            ),
            _HealthBadge(
              label: 'Microchip',
              isActive: widget.pet.hasMicrochip,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialNeedsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pending.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pending.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.pending, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Necesidades Especiales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.pet.specialNeeds!,
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRefugioInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                  widget.pet.refugioName ?? 'Sin información',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (widget.pet.refugioPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primary),
              onPressed: () {
                // TODO: Implementar llamada
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Tel: ${widget.pet.refugioPhone}')),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_currentUser == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _currentUser!.isAdoptante && !_isOwner && widget.pet.isAvailable
            ? CustomButton(
                text: 'Solicitar Adopción',
                onPressed: _requestAdoption,
                icon: Icons.favorite,
              )
            : _isOwner
                ? Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Editar',
                          onPressed: _editPet,
                          backgroundColor: AppTheme.secondary,
                          icon: Icons.edit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Eliminar',
                          onPressed: _deletePet,
                          backgroundColor: AppTheme.rejected,
                          icon: Icons.delete,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final String label;
  final bool isActive;

  const _HealthBadge({
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.approved.withValues(alpha: 0.1)
            : AppTheme.textGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppTheme.approved.withValues(alpha: 0.3)
              : AppTheme.textGrey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isActive ? AppTheme.approved : AppTheme.textGrey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppTheme.approved : AppTheme.textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}