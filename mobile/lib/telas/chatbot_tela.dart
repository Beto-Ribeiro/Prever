import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prever/services/chatbot_service.dart';
import 'package:prever/controles/controle_acessibilidade.dart';

// ════════════════════════════════════════════════════════════════════════════
// MODELO DE DADOS
// ════════════════════════════════════════════════════════════════════════════

/// Representa uma mensagem individual na conversa.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// ECRÃ PRINCIPAL — ChatbotTela
// ════════════════════════════════════════════════════════════════════════════

/// Ecrã de chat com o assistente Nimbo (Gemini via firebase_ai).
///
/// Gere três estados visuais:
/// - [_WelcomeView]: estado inicial com mascote e saudação do bot.
/// - [_MessageListView]: lista scrollável de mensagens (após primeiro envio).
/// - Indicador de "a escrever..." e banner de erro inline.
class ChatbotTela extends StatefulWidget {
  final String title;
  final Function(int)? onChangePage;

  const ChatbotTela({
    super.key,
    this.title = 'Chatbot',
    this.onChangePage,
  });

  @override
  State<ChatbotTela> createState() => _ChatbotTelaState();
}

class _ChatbotTelaState extends State<ChatbotTela>
    with SingleTickerProviderStateMixin {
  // ── Dependências ─────────────────────────────────────────────────────────
  final ChatbotService _service = ChatbotService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _typingAnim;

  // ── Estado ────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Olá, meu nome é Nimbo. Te ajudarei aqui no chat. Como quer começar?',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  bool _isLoading = false;
  bool _hasUserMessages = false;
  String? _errorMessage;

  // ── Ciclo de vida ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingAnim.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── Lógica de envio ───────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _errorMessage = null;
      _hasUserMessages = true;
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().length > 120
          ? '${e.toString().substring(0, 120)}…'
          : e.toString();
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    // ── Cores dinâmicas via AccessibilityController ───────────────────────
    final bgColor = acessibilidade.fundo;
    final navyDark = acessibilidade.corPrimaria;
    final navyMid = acessibilidade.altoContraste
        ? Colors.grey.shade900
        : acessibilidade.daltonismo
        ? Color(0xFF3D2B6B)
        : Color(0xFF1A2B4A);
    final sendBtnColor = acessibilidade.altoContraste
        ? Colors.yellow
        : acessibilidade.daltonismo
        ? Color(0xFFF4A261)
        : Color(0xFF3B7DD8);
    final textSecondary = acessibilidade.corSecundaria;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _AppBar(
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                widget.onChangePage?.call(0);
              }
            },
            navyDark: navyDark,
          ),

          // ── Área de mensagens ──────────────────────────────────────────
          Expanded(
            child: _hasUserMessages
                ? _MessageListView(
                    messages: _messages,
                    isLoading: _isLoading,
                    scrollController: _scrollController,
                    typingAnim: _typingAnim,
                    navyDark: navyDark,
                  )
                : _WelcomeView(
                    greeting: _messages.first.text,
                    navyDark: navyDark,
                  ),
          ),

          // ── Banner de erro ─────────────────────────────────────────────
          if (_errorMessage != null)
            _ErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // ── Barra de input ─────────────────────────────────────────────
          _InputBar(
            controller: _textController,
            isLoading: _isLoading,
            navyDark: navyDark,
            navyMid: navyMid,
            textSecondary: textSecondary,
            sendBtnColor: sendBtnColor,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS — AppBar personalizado
// ════════════════════════════════════════════════════════════════════════════

class _AppBar extends StatelessWidget {
  final VoidCallback onBack;
  final Color navyDark;

  const _AppBar({required this.onBack, required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botão voltar (pill cinzento)
            Semantics(
              label: 'Voltar',
              button: true,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Color(0xFFCDD5E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0B1426),
                    size: 20,
                  ),
                ),
              ),
            ),
            // Ícone de perfil (círculo navy)
            Semantics(
              label: 'Perfil',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: navyDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Vista de boas-vindas (estado inicial)
// ════════════════════════════════════════════════════════════════════════════

class _WelcomeView extends StatelessWidget {
  final String greeting;
  final Color navyDark;

  const _WelcomeView({required this.greeting, required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balão de saudação do bot
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 80, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: _BotBubble(text: greeting, navyDark: navyDark),
          ),
        ),

        const Spacer(),

        // Mascote Nimbo centralizado
        Center(
          child: Image.asset(
            'gfx/png/Image/nimbo_icon.png',
            height: 260,
            semanticLabel: 'Mascote Nimbo',
            errorBuilder: (context, error, stackTrace) => _NimboFallback(navyDark: navyDark),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// Fallback visual caso a imagem do Nimbo não seja encontrada.
class _NimboFallback extends StatelessWidget {
  final Color navyDark;

  const _NimboFallback({required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: navyDark.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.smart_toy_rounded, size: 90, color: navyDark),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Lista de mensagens
// ════════════════════════════════════════════════════════════════════════════

class _MessageListView extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final AnimationController typingAnim;
  final Color navyDark;

  const _MessageListView({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.typingAnim,
    required this.navyDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = messages.length + (isLoading ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: total,
      itemBuilder: (ctx, i) {
        // Indicador de digitação no final
        if (i == messages.length) {
          return _TypingIndicator(anim: typingAnim, navyDark: navyDark);
        }

        final msg = messages[i];
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: msg.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: msg.isUser
                ? _UserBubble(text: msg.text, navyDark: navyDark)
                : _BotBubble(text: msg.text, navyDark: navyDark),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Balões de mensagem
// ════════════════════════════════════════════════════════════════════════════

class _BotBubble extends StatelessWidget {
  final String text;
  final Color navyDark;

  const _BotBubble({required this.text, required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nimbo: $text',
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: navyDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  final Color navyDark;

  const _UserBubble({required this.text, required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Você: $text',
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: navyDark, fontSize: 15, height: 1.45),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Indicador de "a escrever..."
// ════════════════════════════════════════════════════════════════════════════

class _TypingIndicator extends StatelessWidget {
  final AnimationController anim;
  final Color navyDark;

  const _TypingIndicator({required this.anim, required this.navyDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: navyDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: anim,
                builder: (context, child) {
                  final phase = (anim.value + i * 0.25) % 1.0;
                  final scale =
                      0.6 + 0.4 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    width: 8 * scale,
                    height: 8 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Banner de erro
// ════════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUB-WIDGET — Barra de input
// ════════════════════════════════════════════════════════════════════════════

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final Color navyDark;
  final Color navyMid;
  final Color textSecondary;
  final Color sendBtnColor;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.navyDark,
    required this.navyMid,
    required this.textSecondary,
    required this.sendBtnColor,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (ctx, value, _) {
        final hasText = value.text.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: navyDark,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Campo de texto ─────────────────────────────────────────
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Mensagem',
                            hintStyle: TextStyle(color: textSecondary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => onSend(),
                          textInputAction: TextInputAction.send,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                      // Ícone de anexo (visível quando sem texto)
                      if (!hasText)
                        Semantics(
                          label: 'Anexar ficheiro',
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: textSecondary,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Botão enviar (aparece ao digitar) ─────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: hasText
                    ? Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Semantics(
                          label: 'Enviar mensagem',
                          button: true,
                          child: GestureDetector(
                            onTap: onSend,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: sendBtnColor,
                                shape: BoxShape.circle,
                              ),
                              child: isLoading
                                  ? Padding(
                                      padding: EdgeInsets.all(13),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ),
                      )
                    : SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
