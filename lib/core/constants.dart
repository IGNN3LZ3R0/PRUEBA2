import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API Keys (cargadas desde .env)
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Supabase Tables
  static const String profilesTable = 'profiles';
  static const String petsTable = 'pets';
  static const String adoptionRequestsTable = 'adoption_requests';

  // Storage Buckets
  static const String petImagesBucket = 'pet_images';

  // User Types
  static const String userTypeAdoptante = 'adoptante';
  static const String userTypeRefugio = 'refugio';

  // Adoption Status
  static const String statusPending = 'pendiente';
  static const String statusApproved = 'aprobada';
  static const String statusRejected = 'rechazada';

  // Pet Status
  static const String petAvailable = 'disponible';
  static const String petAdopted = 'adoptado';

  // Species
  static const String speciesDog = 'perro';
  static const String speciesCat = 'gato';
}

class AppStrings {
  // Auth
  static const String welcome = '¡Bienvenido!';
  static const String loginToContinue = 'Inicia sesión para continuar';
  static const String email = 'EMAIL';
  static const String password = 'CONTRASEÑA';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String login = 'Iniciar Sesión';
  static const String orContinueWith = 'o continúa con';
  static const String google = 'Google';
  static const String noAccount = '¿No tienes cuenta?';
  static const String register = 'Regístrate';

  // User Type
  static const String whoAreYou = '¿Quién eres?';
  static const String selectAccountType =
      'Selecciona el tipo de cuenta que deseas crear';
  static const String adoptante = 'Adoptante';
  static const String adoptanteDesc =
      'Busco adoptar una mascota y darle un hogar lleno de amor';
  static const String refugio = 'Refugio';
  static const String refugioDesc =
      'Represento un refugio o fundación de animales';

  // Home
  static const String findYourPet = 'Encuentra tu mascota';
  static const String searchPet = 'Buscar mascota...';
  static const String all = 'Todos';
  static const String dogs = 'Perros';
  static const String cats = 'Gatos';

  // Pet Details
  static const String available = 'Disponible';
  static const String age = 'Edad';
  static const String gender = 'Sexo';
  static const String size = 'Tamaño';
  static const String about = 'Sobre';
  static const String requestAdoption = 'Solicitar Adopción';

  // Chat
  static const String chatAssistant = 'Asistente PetAdopt';
  static const String poweredByGemini = 'Powered by Gemini AI';
  static const String writeYourQuestion = 'Escribe tu pregunta...';
}
