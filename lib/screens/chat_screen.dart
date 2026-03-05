import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherPrenom;
  final String otherNom;
  final String? otherPhotoBase64;

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherPrenom,
    required this.otherNom,
    this.otherPhotoBase64,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  late String _myUid;
  late String _conversationId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser!.uid;
    // ID conversation déterministe (même pour les 2 users)
    final ids = [_myUid, widget.otherUid]..sort();
    _conversationId = '${ids[0]}_${ids[1]}';
    _initConversation();
  }

  // Crée le document conversation avec participants dès l'ouverture
  // Nécessaire pour que les règles Firestore autorisent la lecture des messages
  Future<void> _initConversation() async {
    try {
      await _db.collection('conversations').doc(_conversationId).set({
        'participants': [_myUid, widget.otherUid],
        'unread_$_myUid': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
    _markAsRead();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Marquer les messages reçus comme lus
  Future<void> _markAsRead() async {
    try {
      // Marquer messages non lus comme lus
      final unread = await _db
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .where('receiverUid', isEqualTo: _myUid)
          .get();
      for (final doc in unread.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['lu'] == false) {
          doc.reference.update({'lu': true});
        }
      }
      // Remettre le compteur à 0
      await _db.collection('conversations').doc(_conversationId).set({
        'participants': [_myUid, widget.otherUid],
        'unread_$_myUid': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    setState(() => _isSending = true);

    try {
      final now = FieldValue.serverTimestamp();

      // Ajouter le message dans la sous-collection
      await _db
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'senderUid': _myUid,
        'receiverUid': widget.otherUid,
        'text': text,
        'lu': false,
        'createdAt': now,
      });

      // Mettre à jour le doc conversation (dernier message + compteur)
      await _db.collection('conversations').doc(_conversationId).set({
        'participants': [_myUid, widget.otherUid],
        'lastMessage': text,
        'lastMessageAt': now,
        'lastSenderUid': _myUid,
        // Incrémenter non-lus pour le destinataire
        'unread_${widget.otherUid}': FieldValue.increment(1),
        'user_${_myUid}_prenom': _auth.currentUser?.displayName?.split(' ').first ?? '',
        'user_${widget.otherUid}_prenom': widget.otherPrenom,
      }, SetOptions(merge: true));

      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur envoi : $e'),
          backgroundColor: AppColors.primaryPink,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
    setState(() => _isSending = false);
  }

  String get _otherInitiales {
    final p = widget.otherPrenom;
    final n = widget.otherNom;
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8EEFF),
      body: Column(children: [
        // ── AppBar custom ──
        _ChatAppBar(
          prenom: widget.otherPrenom,
          nom: widget.otherNom,
          photoBase64: widget.otherPhotoBase64,
          initiales: _otherInitiales,
          conversationId: _conversationId,
          myUid: _myUid,
          onBack: () => Navigator.pop(context),
        ),

        // ── Messages ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('conversations')
                .doc(_conversationId)
                .collection('messages')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
              }

              final docs = [...(snap.data?.docs ?? [])];
              // Trier par createdAt côté client
              docs.sort((a, b) {
                final aTs = (a.data() as Map<String,dynamic>)['createdAt'] as Timestamp?;
                final bTs = (b.data() as Map<String,dynamic>)['createdAt'] as Timestamp?;
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return aTs.compareTo(bTs);
              });

              // Auto-scroll quand nouveaux messages
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });

              if (docs.isEmpty) return _EmptyChat(otherPrenom: widget.otherPrenom);

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderUid'] == _myUid;
                  final text = data['text'] ?? '';
                  final lu = data['lu'] ?? false;
                  final ts = data['createdAt'] as Timestamp?;
                  final dt = ts?.toDate();

                  // Afficher séparateur de date si changement de jour
                  final prevData = i > 0 ? docs[i - 1].data() as Map<String, dynamic> : null;
                  final prevTs = prevData?['createdAt'] as Timestamp?;
                  final prevDt = prevTs?.toDate();
                  final showDate = dt != null && (prevDt == null ||
                      dt.day != prevDt.day || dt.month != prevDt.month);

                  return Column(children: [
                    if (showDate && dt != null) _DateSeparator(date: dt),
                    _MessageBubble(
                      text: text,
                      isMe: isMe,
                      time: dt,
                      lu: lu,
                      photoBase64: isMe ? null : widget.otherPhotoBase64,
                      initiales: _otherInitiales,
                    ),
                  ]);
                },
              );
            },
          ),
        ),

        // ── Zone saisie ──
        _InputBar(
          controller: _msgController,
          isSending: _isSending,
          onSend: _sendMessage,
        ),
      ]),
    );
  }
}

// ── AppBar custom avec statut en ligne ──
class _ChatAppBar extends StatelessWidget {
  final String prenom, nom, initiales, conversationId, myUid;
  final String? photoBase64;
  final VoidCallback onBack;

  const _ChatAppBar({
    required this.prenom, required this.nom, required this.initiales,
    required this.conversationId, required this.myUid,
    this.photoBase64, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFF8FAB), AppColors.primaryPink],
        ),
        boxShadow: [BoxShadow(color: Color(0x22E8748A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Bouton retour
            GestureDetector(
              onTap: onBack,
              child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white)),
            ),
            const SizedBox(width: 12),

            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: ClipOval(child: photoBase64 != null
                  ? Image.memory(base64Decode(photoBase64!), fit: BoxFit.cover)
                  : Container(color: Colors.white.withOpacity(0.3),
                  child: Center(child: Text(initiales,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))))),
            ),
            const SizedBox(width: 12),

            // Nom
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$prenom $nom', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              // Nombre de messages non lus (si l'autre a des non lus)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('conversations').doc(conversationId).snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData || !snap.data!.exists) {
                    return const Text('Démarrez la conversation', style: TextStyle(fontSize: 11, color: Colors.white70));
                  }
                  return const Text('En ligne', style: TextStyle(fontSize: 11, color: Colors.white70));
                },
              ),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── Bulle de message ──
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe, lu;
  final DateTime? time;
  final String? photoBase64;
  final String initiales;

  const _MessageBubble({
    required this.text, required this.isMe, required this.lu,
    this.time, this.photoBase64, required this.initiales,
  });

  String _formatTime() {
    if (time == null) return '';
    return '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar interlocuteur
          if (!isMe) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryPink.withOpacity(0.3), width: 1.5)),
              child: ClipOval(child: photoBase64 != null
                  ? Image.memory(base64Decode(photoBase64!), fit: BoxFit.cover)
                  : Container(color: AppColors.lightPink,
                  child: Center(child: Text(initiales,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryPink))))),
            ),
            const SizedBox(width: 8),
          ],

          // Bulle
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryPink : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [BoxShadow(
                  color: isMe ? AppColors.primaryPink.withOpacity(0.25) : Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 3),
                )],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(text, style: TextStyle(
                  fontSize: 14, height: 1.4,
                  color: isMe ? Colors.white : AppColors.textDark,
                )),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_formatTime(), style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textGrey,
                  )),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      lu ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: lu ? Colors.white : Colors.white.withOpacity(0.6),
                    ),
                  ],
                ]),
              ]),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Séparateur de date ──
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Aujourd\'hui';
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${mois[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(children: [
      const Expanded(child: Divider(color: Color(0xFFE0D0E8))),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Text(_label(), style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider(color: Color(0xFFE0D0E8))),
    ]),
  );
}

// ── Zone de saisie ──
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.isSending, required this.onSend});
  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Champ texte
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message...',
                    hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Bouton envoi
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.primaryPink : AppColors.inputBorder,
                shape: BoxShape.circle,
                boxShadow: _hasText ? [BoxShadow(color: AppColors.primaryPink.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: widget.isSending
                  ? const Padding(padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : GestureDetector(
                onTap: _hasText ? widget.onSend : null,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── État vide ──
class _EmptyChat extends StatelessWidget {
  final String otherPrenom;
  const _EmptyChat({required this.otherPrenom});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryPink, size: 36)),
      const SizedBox(height: 16),
      Text('Discutez avec $otherPrenom',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Text('Envoyez votre premier message !',
          style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
    ]),
  );
}
