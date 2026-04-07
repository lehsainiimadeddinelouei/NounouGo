import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';
import '../theme/app_theme.dart';

/// Suggestions rapides affichées au démarrage
const List<Map<String, String>> _suggestions = [
  {'emoji': '💰', 'label': 'Les tarifs ?',        'q': 'Quels sont les tarifs ?'},
  {'emoji': '🔍', 'label': 'Trouver une nounou',  'q': 'Comment trouver une nounou ?'},
  {'emoji': '🛡️', 'label': 'Profils vérifiés ?',  'q': 'Les profils sont-ils vérifiés ?'},
  {'emoji': '📅', 'label': 'Réserver',             'q': 'Comment faire une réservation ?'},
];

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _service = ChatbotService();
  final List<ChatMessage> _history = [];
  final List<_BubbleData> _bubbles = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _loading = false;
  bool _suggHidden = false;

  // ── Message de bienvenue ──────────────────────────────────
  @override
  void initState() {
    super.initState();
    _bubbles.add(const _BubbleData(
      role: 'bot',
      text: 'Bonjour ! 👋 Je suis l\'assistant IA de NounouGo.\nPosez-moi n\'importe quelle question sur l\'app, les nounous ou les réservations !',
    ));
    _testerAPI();
  }

  Future<void> _testerAPI() async {
    try {
      final res = await _service.sendMessage([
        ChatMessage(role: 'user', content: 'dis bonjour'),
      ]);
      print('✅ API OK: $res');
    } catch (e) {
      print('❌ API ERREUR: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Envoi du message ──────────────────────────────────────
  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();

    setState(() {
      if (!_suggHidden) _suggHidden = true;
      _bubbles.add(_BubbleData(role: 'user', text: text));
      _loading = true;
    });
    _history.add(ChatMessage(role: 'user', content: text));
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(_history);
      _history.add(ChatMessage(role: 'assistant', content: reply));
      if (mounted) {
        setState(() {
          _bubbles.add(_BubbleData(role: 'bot', text: reply));
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ API ERREUR: $e');
      if (mounted) {
        setState(() {
          _bubbles.add(_BubbleData(
            role: 'bot',
            text: '⚠️ Erreur: $e',
          ));
          _loading = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A35),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (!_suggHidden) _buildSuggestions(),
          _buildInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A2545),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8FAB), Color(0xFFC8384E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.primaryPink.withOpacity(0.4), blurRadius: 12)],
            ),
            child: const Center(child: Text('👶', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assistant NounouGo',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DAB80),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('En ligne · Propulsé par Gemini IA',
                      style: TextStyle(color: Color(0xFF3DAB80), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      itemCount: _bubbles.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (_loading && i == _bubbles.length) return const _TypingBubble();
        return _ChatBubble(data: _bubbles[i]);
      },
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _suggestions.map((s) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SuggChip(
                emoji: s['emoji']!,
                label: s['label']!,
                onTap: () => _send(s['q']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A35),
        border: const Border(top: BorderSide(color: Color(0x0FFFFFFF))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white.withOpacity(0.13)),
              ),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Posez votre question…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(loading: _loading, onTap: () => _send(_ctrl.text)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DONNÉES D'UNE BULLE
// ─────────────────────────────────────────────────────────────
class _BubbleData {
  final String role;
  final String text;
  const _BubbleData({required this.role, required this.text});
}

// ─────────────────────────────────────────────────────────────
// BULLE DE MESSAGE
// ─────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _BubbleData data;
  const _ChatBubble({required this.data});

  bool get isUser => data.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[_Avatar(isUser: false), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFE8748A), Color(0xFFC8384E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white.withOpacity(0.07),
                border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                data.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFFCDD8F0),
                  fontSize: 13.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _Avatar(isUser: true)],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANIMATION "EN TRAIN D'ÉCRIRE"
// ─────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Avatar(isUser: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _Dot(controller: _ac, delay: i * 0.2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _Dot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = ((controller.value - delay) % 1.0).clamp(0.0, 1.0);
        final y = t < 0.5 ? -6 * (t * 2) : -6 * (1 - (t - 0.5) * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.translate(
            offset: Offset(0, y),
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4 + t * 0.6),
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isUser
              ? [const Color(0xFF4A7FD4), const Color(0xFF3D5A8A)]
              : [const Color(0xFFFF8FAB), const Color(0xFFC8384E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(isUser ? '👤' : '👶', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHIP DE SUGGESTION
// ─────────────────────────────────────────────────────────────
class _SuggChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _SuggChip({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryPink.withOpacity(0.1),
          border: Border.all(color: AppColors.primaryPink.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          '$emoji $label',
          style: const TextStyle(
            color: Color(0xFFFF8FAB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOUTON ENVOYER
// ─────────────────────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SendButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF8FAB), Color(0xFFC8384E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: loading ? Colors.white12 : null,
          boxShadow: loading
              ? []
              : [BoxShadow(color: AppColors.primaryPink.withOpacity(0.4), blurRadius: 16)],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                )
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
