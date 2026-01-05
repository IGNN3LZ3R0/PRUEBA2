import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../data/pet_repository.dart';
import '../data/models.dart';

class CreatePetPage extends StatefulWidget {
  final PetModel? pet; // Para edición

  const CreatePetPage({super.key, this.pet});

  @override
  State<CreatePetPage> createState() => _CreatePetPageState();
}

class _CreatePetPageState extends State<CreatePetPage> {
  final _formKey = GlobalKey<FormState>();
  final _petRepository = PetRepository();
  final _uuid = const Uuid();

  // Controllers
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _healthController = TextEditingController();
  final _specialNeedsController = TextEditingController();

  // Valores seleccionables
  String _selectedSpecies = AppConstants.speciesDog;
  String _selectedGender = 'Macho';
  String _selectedSize = 'Mediano';
  bool _isVaccinated = false;
  bool _isDewormed = false;
  bool _isSterilized = false;
  bool _hasMicrochip = false;

  // Imágenes
  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pet != null) {
      _loadPetData(widget.pet!);
    }
  }

  void _loadPetData(PetModel pet) {
    _nameController.text = pet.name;
    _breedController.text = pet.breed ?? '';
    _ageController.text = pet.age.toString();
    _descriptionController.text = pet.description;
    _healthController.text = pet.healthStatus;
    _specialNeedsController.text = pet.specialNeeds ?? '';
    
    _selectedSpecies = pet.species;
    _selectedGender = pet.gender;
    _selectedSize = pet.size;
    _isVaccinated = pet.isVaccinated;
    _isDewormed = pet.isDewormed;
    _isSterilized = pet.isSterilized;
    _hasMicrochip = pet.hasMicrochip;
    _existingImageUrls = List.from(pet.imageUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _healthController.dispose();
    _specialNeedsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _petRepository.pickMultipleImages();
      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      _showError('Error al seleccionar imágenes: $e');
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
      _showError('Error al tomar foto: $e');
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showError('Debes agregar al menos una imagen');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseClientManager.instance.userId;
      if (userId == null) throw Exception('Usuario no autenticado');

      final petId = widget.pet?.id ?? _uuid.v4();

      // Subir nuevas imágenes
      List<String> uploadedUrls = [];
      if (_selectedImages.isNotEmpty) {
        uploadedUrls = await _petRepository.uploadMultipleImages(
          _selectedImages,
          petId,
        );
      }

      // Combinar URLs
      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];

      final petData = PetModel(
        id: petId,
        refugioId: userId,
        name: _nameController.text.trim(),
        species: _selectedSpecies,
        breed: _breedController.text.trim().isEmpty 
            ? null 
            : _breedController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
        gender: _selectedGender,
        size: _selectedSize,
        description: _descriptionController.text.trim(),
        healthStatus: _healthController.text.trim(),
        imageUrls: allImageUrls,
        isVaccinated: _isVaccinated,
        isDewormed: _isDewormed,
        isSterilized: _isSterilized,
        hasMicrochip: _hasMicrochip,
        specialNeeds: _specialNeedsController.text.trim().isEmpty
            ? null
            : _specialNeedsController.text.trim(),
        createdAt: widget.pet?.createdAt ?? DateTime.now(),
      );

      if (widget.pet == null) {
        await _petRepository.createPet(petData);
      } else {
        await _petRepository.updatePet(petId, petData.toJson());
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.pet == null 
                ? '¡Mascota registrada exitosamente!' 
                : '¡Mascota actualizada!'),
            backgroundColor: AppTheme.approved,
          ),
        );
      }
    } catch (e) {
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.rejected),
    );
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
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imágenes
                _buildImageSection(),
                const SizedBox(height: 24),

                // Nombre
                CustomTextField(
                  label: 'NOMBRE',
                  hint: 'Nombre de la mascota',
                  controller: _nameController,
                  validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Especie
                _buildDropdown(
                  'ESPECIE',
                  _selectedSpecies,
                  [AppConstants.speciesDog, AppConstants.speciesCat],
                  (v) => setState(() => _selectedSpecies = v!),
                  (s) => s == AppConstants.speciesDog ? 'Perro' : 'Gato',
                ),
                const SizedBox(height: 16),

                // Raza
                CustomTextField(
                  label: 'RAZA',
                  hint: 'Opcional',
                  controller: _breedController,
                ),
                const SizedBox(height: 16),

                // Edad, Género, Tamaño
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'EDAD (años)',
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        'GÉNERO',
                        _selectedGender,
                        ['Macho', 'Hembra'],
                        (v) => setState(() => _selectedGender = v!),
                        (s) => s,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildDropdown(
                  'TAMAÑO',
                  _selectedSize,
                  ['Pequeño', 'Mediano', 'Grande'],
                  (v) => setState(() => _selectedSize = v!),
                  (s) => s,
                ),
                const SizedBox(height: 16),

                // Descripción
                CustomTextField(
                  label: 'DESCRIPCIÓN',
                  hint: 'Cuéntanos sobre esta mascota',
                  controller: _descriptionController,
                  maxLines: 4,
                  validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                // Estado de salud
                CustomTextField(
                  label: 'ESTADO DE SALUD',
                  hint: 'Opcional',
                  controller: _healthController,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Checkboxes
                Text('INFORMACIÓN MÉDICA', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                _buildCheckbox('Vacunado', _isVaccinated, (v) => setState(() => _isVaccinated = v!)),
                _buildCheckbox('Desparasitado', _isDewormed, (v) => setState(() => _isDewormed = v!)),
                _buildCheckbox('Esterilizado', _isSterilized, (v) => setState(() => _isSterilized = v!)),
                _buildCheckbox('Microchip', _hasMicrochip, (v) => setState(() => _hasMicrochip = v!)),
                
                const SizedBox(height: 16),

                // Necesidades especiales
                CustomTextField(
                  label: 'NECESIDADES ESPECIALES',
                  hint: 'Opcional',
                  controller: _specialNeedsController,
                  maxLines: 2,
                ),

                const SizedBox(height: 32),

                // Botón guardar
                CustomButton(
                  text: widget.pet == null ? 'Registrar Mascota' : 'Actualizar',
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
        Text('FOTOS', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        
        // Grid de imágenes
        if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Imágenes existentes
                ..._existingImageUrls.asMap().entries.map((e) => _buildImagePreview(
                  isNetwork: true,
                  imagePath: e.value,
                  onRemove: () => _removeExistingImage(e.key),
                )),
                // Nuevas imágenes
                ..._selectedImages.asMap().entries.map((e) => _buildImagePreview(
                  isNetwork: false,
                  imagePath: e.value.path,
                  onRemove: () => _removeNewImage(e.key),
                )),
              ],
            ),
          ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cámara'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview({
    required bool isNetwork,
    required String imagePath,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: isNetwork 
              ? NetworkImage(imagePath) as ImageProvider
              : FileImage(File(imagePath)),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
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
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    void Function(T?) onChanged,
    String Function(T) itemLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(itemLabel(item)),
          )).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, void Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppTheme.primary,
    );
  }
}