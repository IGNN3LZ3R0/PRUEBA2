import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants.dart';
import 'models.dart';

class GeminiRepository {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiRepository() {
    // VALIDACION PARA CONFIRMA QUE LA API KEY NO ESTÉ VACÍA
    final apiKey = AppConstants.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY no configurada. '
          'Asegúrate de que el archivo .env tenga: GEMINI_API_KEY=tu-clave-real');
    }

    final visibleKey =
        apiKey.length > 10 ? '${apiKey.substring(0, 10)}...' : apiKey;
    print('Gemini API Key cargada: $visibleKey');

    final modelName = AppConstants.geminiModel;
    print('Usando modelo Gemini: $modelName');

    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system('''
Eres un asistente virtual experto en cuidado y salud de mascotas (perros y gatos).

Tu objetivo es ayudar a adoptantes y refugios con información sobre:
- Salud y cuidados básicos de mascotas
- Alimentación adecuada según edad, tamaño y raza
- Comportamiento y entrenamiento
- Vacunas y desparasitación
- Preparación del hogar para una nueva mascota
- Primeros auxilios básicos
- Síntomas que requieren atención veterinaria

Responde de manera:
- Clara y concisa (máximo 3-4 párrafos)
- Empática y amigable
- Basada en información veterinaria confiable
- En español
- Sin usar formato markdown

IMPORTANTE: 
- Si te preguntan sobre diagnósticos médicos serios, recomienda consultar a un veterinario.
- No des consejos que puedan poner en riesgo la salud del animal.
- Si la pregunta no está relacionada con mascotas, responde amablemente que solo puedes ayudar con temas de cuidado de perros y gatos.
      '''),
    );

    _chat = _model.startChat();
  }

  Future<ChatMessage> sendMessage(String message) async {
    try {
      // Enviar mensaje del usuario (registro)
      print('Enviando mensaje a Gemini: ${message.length} chars');

      // Obtener respuesta de Gemini con timeout
      final content = Content.text(message);
      final response = await _chat.sendMessage(content).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception(
                'Tiempo de espera agotado al comunicarse con Gemini'),
          );

      // Verificar respuesta
      final responseText = response.text?.trim();
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Respuesta vacía desde Gemini');
      }

      // Crear mensaje de respuesta
      final aiMessage = ChatMessage(
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );

      return aiMessage;
    } catch (e) {
      print('❌ Error en sendMessage: $e');
      throw Exception('Error al comunicarse con Gemini: $e');
    }
  }

  // Reiniciar conversación
  void resetChat() {
    _chat = _model.startChat();
  }

  // Preguntas sugeridas
  static const List<String> suggestedQuestions = [
    '¿Cómo preparar mi casa para un nuevo cachorro?',
    '¿Qué vacunas necesita un perro adulto?',
    '¿Cómo calmar la ansiedad por separación en gatos?',
    '¿Cuál es la mejor alimentación para un gato senior?',
    '¿Cómo detectar si mi mascota tiene parásitos?',
    '¿Cada cuánto debo bañar a mi perro?',
  ];
}
