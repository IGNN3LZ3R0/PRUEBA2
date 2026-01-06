import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../data/gemini_repository.dart';
import '../data/models.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _geminiRepo = GeminiRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text:
          '¡Hola! 🐾 Soy tu asistente virtual de PetAdopt. Puedo ayudarte con preguntas sobre salud, cuidados, alimentación y comportamiento de perros y gatos. ¿En qué puedo ayudarte hoy?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _errorMessage = null; // Limpiar errores previos
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      print('🚀 Enviando mensaje...');
      final aiMessage = await _geminiRepo.sendMessage(text);
      
      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        _scrollToBottom();
        print('✅ Mensaje recibido y mostrado');
      }
    } catch (e) {
      print('❌ Error capturado: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        
        // Mostrar error en un SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Error desconocido'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _sendMessage(text),
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asistente Virtual'),
            Text(
              'Powered by Gemini AI',
              style: TextStyle(
                fontSize: isLandscape ? 10 : 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _errorMessage = null;
                _geminiRepo.resetChat();
                _addWelcomeMessage();
              });
            },
            tooltip: 'Nueva conversación',
          ),
        ],
      ),
      body: Container(
        constraints: isLargeScreen ? const BoxConstraints(maxWidth: 800) : null,
        margin: isLargeScreen ? EdgeInsets.symmetric(
          horizontal: (screenWidth - 800) / 2
        ) : null,
        child: Column(
          children: [
            // 🔥 Mostrar error si existe
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isLandscape ? 8 : 12),
                margin: EdgeInsets.all(isLandscape ? 8 : 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: isLandscape ? 18 : 24),
                    SizedBox(width: isLandscape ? 8 : 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isLandscape ? 12 : 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: isLandscape ? 16 : 18),
                      onPressed: () => setState(() => _errorMessage = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            if (_messages.isEmpty) _buildEmptyState(isLandscape),
            if (_messages.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(isLandscape ? 8 : 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: _messages[index],
                      isLandscape: isLandscape,
                    );
                  },
                ),
              ),
            if (_messages.length == 1) _buildSuggestedQuestions(isLandscape),
            if (_isLoading) _buildLoadingIndicator(isLandscape),
            _buildInputArea(isLandscape, isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLandscape) {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isLandscape ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? 400 : 600,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isLandscape ? 16 : 24),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: isLandscape ? 48 : 60,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: isLandscape ? 16 : 24),
                Text(
                  'Asistente Virtual',
                  style: TextStyle(
                    fontSize: isLandscape ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isLandscape ? 8 : 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 16 : 48),
                  child: Text(
                    'Pregúntame sobre cuidados, salud o comportamiento de mascotas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLandscape ? 13 : 14,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions(bool isLandscape) {
    return Container(
      height: isLandscape ? 100 : 120,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 16,
        vertical: isLandscape ? 4 : 8,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: GeminiRepository.suggestedQuestions.length,
        itemBuilder: (context, index) {
          final question = GeminiRepository.suggestedQuestions[index];
          return Container(
            width: isLandscape ? 180 : 200,
            margin: EdgeInsets.only(
              right: isLandscape ? 8 : 12,
              bottom: isLandscape ? 8 : 16,
            ),
            child: InkWell(
              onTap: () => _sendMessage(question),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.primary,
                      size: isLandscape ? 18 : 20,
                    ),
                    SizedBox(height: isLandscape ? 6 : 8),
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: isLandscape ? 12 : 13,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isLandscape) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 8 : 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isLandscape ? 10 : 12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isLandscape ? 14 : 16,
                  height: isLandscape ? 14 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                SizedBox(width: isLandscape ? 6 : 8),
                Text(
                  'Pensando...',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: isLandscape ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isLandscape, bool isLargeScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12 : 16,
        vertical: isLandscape ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isLandscape ? 20 : 24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 16 : 20,
                  vertical: isLandscape ? 10 : 12,
                ),
              ),
              maxLines: isLandscape ? 2 : null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
            ),
          ),
          SizedBox(width: isLandscape ? 8 : 12),
          Container(
            decoration: BoxDecoration(
              color: _isLoading 
                  ? AppTheme.textGrey.withOpacity(0.3)
                  : AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: isLandscape ? 18 : 20,
                      height: isLandscape ? 18 : 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.send, 
                      color: Colors.white,
                      size: isLandscape ? 22 : 24,
                    ),
              onPressed: _isLoading 
                  ? null 
                  : () => _sendMessage(_messageController.text),
              padding: EdgeInsets.all(isLandscape ? 10 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLandscape;

  const _MessageBubble({
    required this.message,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLandscape ? 12 : 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: isLandscape ? 28 : 32,
              height: isLandscape ? 28 : 32,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                color: AppTheme.secondary,
                size: isLandscape ? 18 : 20,
              ),
            ),
            SizedBox(width: isLandscape ? 6 : 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLandscape 
                    ? MediaQuery.of(context).size.width * 0.7
                    : double.infinity,
              ),
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 10 : 12),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? AppTheme.primary
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(isLandscape ? 14 : 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : AppTheme.textDark,
                        fontSize: isLandscape ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 3 : 4),
                    Text(
                      message.getTimeFormatted(),
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white.withOpacity(0.7)
                            : AppTheme.textGrey,
                        fontSize: isLandscape ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: isLandscape ? 6 : 8),
            Container(
              width: isLandscape ? 28 : 32,
              height: isLandscape ? 28 : 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: AppTheme.primary,
                size: isLandscape ? 18 : 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}