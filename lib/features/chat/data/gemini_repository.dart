import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants.dart';
import 'models.dart';

class GeminiRepository {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiRepository() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: AppConstants.geminiApiKey,
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
      // Enviar mensaje del usuario
      final userMessage = ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      );

      // Obtener respuesta de Gemini
      final content = Content.text(message);
      final response = await _chat.sendMessage(content);

      // Crear mensaje de respuesta
      final aiMessage = ChatMessage(
        text: response.text ?? 'Lo siento, no pude generar una respuesta.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      return aiMessage;
    } catch (e) {
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