import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/pet_repository.dart';
import '../data/models.dart';

class CreatePetPage extends StatefulWidget {
  final PetModel? pet; // Si no es null, es edición

  const CreatePetPage({super.key, this.pet});

  @override
  State<CreatePetPage> createState() => _CreatePetPageState();
}

class _CreatePetPageState extends State<CreatePetPage> {
  final _formKey = GlobalKey<FormState>();
  final _petRepository = PetRepository();

  // Controllers
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _healthStatusController = TextEditingController();
  final _specialNeedsController = TextEditingController();

  // Valores seleccionados
  String _selectedSpecies = AppConstants.speciesDog;
  String _selectedGender = 'Macho';
  String _selectedSize = 'Mediano';
  bool _isVaccinated = false;
  bool _isDewormed = false;
  bool _isSterilized = false;
  bool _hasMicrochip = false;

  List<File> _selectedImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pet != null) {
      _loadPetData();
    }
  }

  void _loadPetData() {
    final pet = widget.pet!;
    _nameController.text = pet.name;
    _breedController.text = pet.breed ?? '';
    _ageController.text = pet.age.toString();
    _descriptionController.text = pet.description;
    _healthStatusController.text = pet.healthStatus;
    _specialNeedsController.text = pet.specialNeeds ?? '';

    _selectedSpecies = pet.species;
    _selectedGender = pet.gender;
    _selectedSize = pet.size;
    _isVaccinated = pet.isVaccinated;
    _isDewormed = pet.isDewormed;
    _isSterilized = pet.isSterilized;
    _hasMicrochip = pet.hasMicrochip;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _healthStatusController.dispose();
    _specialNeedsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _petRepository.pickMultipleImages();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imágenes: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final image = await _petRepository.pickImageFromCamera();
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty && widget.pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos una imagen')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseClientManager.instance.userId!;
      final petId = widget.pet?.id ?? const Uuid().v4();

      // 1. Subir imágenes
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _petRepository.uploadMultipleImages(
          _selectedImages,
          petId,
        );
      } else if (widget.pet != null) {
        imageUrls = widget.pet!.imageUrls;
      }

      // 2. Crear o actualizar mascota
      final pet = PetModel(
        id: petId,
        refugioId: userId,
        name: _nameController.text.trim(),
        species: _selectedSpecies,
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        age: int.parse(_ageController.text),
        gender: _selectedGender,
        size: _selectedSize,
        description: _descriptionController.text.trim(),
        healthStatus: _healthStatusController.text.trim(),
        imageUrls: imageUrls,
        isVaccinated: _isVaccinated,
        isDewormed: _isDewormed,
        isSterilized: _isSterilized,
        hasMicrochip: _hasMicrochip,
        specialNeeds: _specialNeedsController.text.trim().isEmpty
            ? null
            : _specialNeedsController.text.trim(),
        status: widget.pet?.status ?? AppConstants.petAvailable,
        createdAt: widget.pet?.createdAt ?? DateTime.now(),
      );

      if (widget.pet == null) {
        // Crear
        await _petRepository.createPet(pet);
      } else {
        // Actualizar
        await _petRepository.updatePet(petId, pet.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.pet == null
                ? '¡Mascota registrada exitosamente!'
                : '¡Mascota actualizada exitosamente!'),
            backgroundColor: AppTheme.approved,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pet == null ? 'Registrar Mascota' : 'Editar Mascota'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Guardando...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imágenes
                _buildImageSection(),
                const SizedBox(height: 24),

                // Información básica
                CustomTextField(
                  label: 'NOMBRE',
                  hint: 'Nombre de la mascota',
                  controller: _nameController,
                  prefixIcon: Icons.pets,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Especie
                const Text(
                  'ESPECIE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RadioOption(
                        label: 'Perro',
                        icon: Icons.pets,
                        isSelected: _selectedSpecies == AppConstants.speciesDog,
                        onTap: () =>
                            setState(() => _selectedSpecies = AppConstants.speciesDog),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RadioOption(
                        label: 'Gato',
                        icon: Icons.pest_control,
                        isSelected: _selectedSpecies == AppConstants.speciesCat,
                        onTap: () =>
                            setState(() => _selectedSpecies = AppConstants.speciesCat),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Raza
                CustomTextField(
                  label: 'RAZA (Opcional)',
                  hint: 'Ej: Labrador, Mestizo',
                  controller: _breedController,
                  prefixIcon: Icons.info_outline,
                ),
                const SizedBox(height: 20),

                // Edad
                CustomTextField(
                  label: 'EDAD (años)',
                  hint: '0 para cachorros',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La edad es requerida';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Debe ser un número';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Género
                const Text(
                  'GÉNERO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RadioOption(
                        label: 'Macho',
                        icon: Icons.male,
                        isSelected: _selectedGender == 'Macho',
                        onTap: () => setState(() => _selectedGender = 'Macho'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RadioOption(
                        label: 'Hembra',
                        icon: Icons.female,
                        isSelected: _selectedGender == 'Hembra',
                        onTap: () => setState(() => _selectedGender = 'Hembra'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tamaño
                const Text(
                  'TAMAÑO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RadioOption(
                        label: 'Pequeño',
                        icon: Icons.circle,
                        isSelected: _selectedSize == 'Pequeño',
                        onTap: () => setState(() => _selectedSize = 'Pequeño'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RadioOption(
                        label: 'Mediano',
                        icon: Icons.circle_outlined,
                        isSelected: _selectedSize == 'Mediano',
                        onTap: () => setState(() => _selectedSize = 'Mediano'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RadioOption(
                        label: 'Grande',
                        icon: Icons.panorama_fish_eye,
                        isSelected: _selectedSize == 'Grande',
                        onTap: () => setState(() => _selectedSize = 'Grande'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Descripción
                CustomTextField(
                  label: 'DESCRIPCIÓN',
                  hint: 'Describe la personalidad y características',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La descripción es requerida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Estado de salud
                CustomTextField(
                  label: 'ESTADO DE SALUD',
                  hint: 'Saludable, bajo tratamiento, etc.',
                  controller: _healthStatusController,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Checkboxes de salud
                const Text(
                  'CUIDADOS MÉDICOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                _CheckboxOption(
                  label: 'Vacunado',
                  value: _isVaccinated,
                  onChanged: (val) => setState(() => _isVaccinated = val),
                ),
                _CheckboxOption(
                  label: 'Desparasitado',
                  value: _isDewormed,
                  onChanged: (val) => setState(() => _isDewormed = val),
                ),
                _CheckboxOption(
                  label: 'Esterilizado',
                  value: _isSterilized,
                  onChanged: (val) => setState(() => _isSterilized = val),
                ),
                _CheckboxOption(
                  label: 'Microchip',
                  value: _hasMicrochip,
                  onChanged: (val) => setState(() => _hasMicrochip = val),
                ),
                const SizedBox(height: 20),

                // Necesidades especiales
                CustomTextField(
                  label: 'NECESIDADES ESPECIALES (Opcional)',
                  hint: 'Medicación, cuidados especiales, etc.',
                  controller: _specialNeedsController,
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                // Botón guardar
                CustomButton(
                  text: widget.pet == null ? 'Registrar Mascota' : 'Guardar Cambios',
                  onPressed: _savePet,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IMÁGENES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textGrey,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Botón agregar foto
              _AddImageButton(
                icon: Icons.add_photo_alternate,
                label: 'Galería',
                onTap: _pickImages,
              ),
              const SizedBox(width: 12),
              _AddImageButton(
                icon: Icons.camera_alt,
                label: 'Cámara',
                onTap: _takePicture,
              ),
              const SizedBox(width: 12),
              // Imágenes seleccionadas
              ..._selectedImages.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _ImagePreview(
                    image: entry.value,
                    onRemove: () => _removeImage(entry.key),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddImageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddImageButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;

  const _ImagePreview({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: FileImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.textGrey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.textGrey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxOption extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _CheckboxOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (val) => onChanged(val ?? false),
      activeColor: AppTheme.primary,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}