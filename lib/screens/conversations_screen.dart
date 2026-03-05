import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              const Text('Messages',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Spacer(),
              _TotalUnreadBadge(myUid: myUid),
            ]),
          ),

          // ── Hint ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: const [
              Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textGrey),
              SizedBox(width: 4),
              Text('Appui long pour supprimer',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ]),
          ),

          // ── Liste conversations ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: myUid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryPink));
                }

                final allDocs = [...(snap.data?.docs ?? [])];
                // Dédupliquer: garder 1 conversation par otherUid (la plus récente)
                final myUidLocal = myUid;
                final Map<String, dynamic> seenOther = {};
                final docs = <dynamic>[];
                for (final doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final parts = List<String>.from(data['participants'] ?? []);
                  final other = parts.firstWhere((p) => p != myUidLocal, orElse: () => '');
                  if (other.isEmpty) continue;
                  if (!seenOther.containsKey(other)) {
                    seenOther[other] = doc;
                    docs.add(doc);
                  } else {
                    // Garder le plus récent
                    final existingTs = ((seenOther[other].data() as Map<String,dynamic>)['lastMessageAt'] as Timestamp?);
                    final newTs = (data['lastMessageAt'] as Timestamp?);
                    if (newTs != null && (existingTs == null || newTs.compareTo(existingTs) > 0)) {
                      docs.remove(seenOther[other]);
                      seenOther[other] = doc;
                      docs.add(doc);
                    }
                  }
                }
                // Trier par lastMessageAt
                docs.sort((a, b) {
                  final aTs = ((a.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?);
                  final bTs = ((b.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?);
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });

                if (docs.isEmpty) return const _EmptyConversations();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUid = participants.firstWhere(
                        (p) => p != myUid, orElse: () => '');
                    if (otherUid.isEmpty) return const SizedBox.shrink();

                    return _ConversationTile(
                      myUid: myUid,
                      otherUid: otherUid,
                      convData: data,
                      convId: docs[i].id,
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Badge total non lus ──
class _TotalUnreadBadge extends StatelessWidget {
  final String myUid;
  const _TotalUnreadBadge({required this.myUid});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: myUid)
        .snapshots(),
    builder: (_, snap) {
      int total = 0;
      for (final doc in snap.data?.docs ?? []) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['unread_$myUid'] ?? 0) as int;
      }
      if (total == 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.primaryPink,
            borderRadius: BorderRadius.circular(20)),
        child: Text('$total non lu${total > 1 ? 's' : ''}',
            style: const TextStyle(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
      );
    },
  );
}

// ── Tuile de conversation ──
class _ConversationTile extends StatelessWidget {
  final String myUid, otherUid, convId;
  final Map<String, dynamic> convData;
  const _ConversationTile({
    required this.myUid,
    required this.otherUid,
    required this.convData,
    required this.convId,
  });

  Future<void> _confirmDelete(BuildContext context, String prenom, String nom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la conversation ?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('La conversation avec $prenom $nom sera supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final msgs = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(convId)
            .collection('messages')
            .get();
        for (final m in msgs.docs) {
          await m.reference.delete();
        }
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(convId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Conversation supprimée'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final userData = snap.data!.data() as Map<String, dynamic>? ?? {};
        final prenom = userData['prenom'] ?? '';
        final nom = userData['nom'] ?? '';
        final photoBase64 = userData['photoBase64'] as String?;
        final role = userData['role'] ?? '';
        final initiales =
            '${prenom.isNotEmpty ? prenom[0].toUpperCase() : ''}${nom.isNotEmpty ? nom[0].toUpperCase() : ''}';

        final lastMsg = convData['lastMessage'] ?? '';
        final lastSenderUid = convData['lastSenderUid'] ?? '';
        final unread = (convData['unread_$myUid'] ?? 0) as int;
        final ts = convData['lastMessageAt'] as Timestamp?;
        final isMe = lastSenderUid == myUid;

        return GestureDetector(
          onLongPress: () => _confirmDelete(context, prenom, nom),
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => ChatScreen(
                otherUid: otherUid,
                otherPrenom: prenom,
                otherNom: nom,
                otherPhotoBase64: photoBase64,
              ),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3))],
              border: unread > 0
                  ? Border.all(
                      color: AppColors.primaryPink.withOpacity(0.3),
                      width: 1.5)
                  : null,
            ),
            child: Row(children: [
              // Avatar
              Stack(children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primaryPink.withOpacity(0.25),
                        width: 2),
                  ),
                  child: ClipOval(
                    child: photoBase64 != null
                        ? Image.memory(base64Decode(photoBase64),
                            fit: BoxFit.cover)
                        : Container(
                            color: role == 'Babysitter'
                                ? AppColors.primaryPink.withOpacity(0.12)
                                : AppColors.buttonBlue.withOpacity(0.12),
                            child: Center(
                              child: Text(initiales,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: role == 'Babysitter'
                                          ? AppColors.primaryPink
                                          : AppColors.buttonBlue)),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              ]),
              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Text('$prenom $nom',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: AppColors.textDark)),
                    Text(
                      _formatTime(ts?.toDate()),
                      style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? AppColors.primaryPink
                              : AppColors.textGrey,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w400),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (isMe)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.done_all_rounded,
                            size: 14, color: AppColors.textGrey),
                      ),
                    Expanded(
                      child: Text(
                        lastMsg.isEmpty
                            ? 'Démarrez la conversation'
                            : lastMsg,
                        style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.textDark
                                : AppColors.textGrey,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primaryPink,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$unread',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${dt.day} ${mois[dt.month - 1]}';
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
            color: AppColors.primaryPink.withOpacity(0.08),
            shape: BoxShape.circle),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryPink, size: 40),
      ),
      const SizedBox(height: 20),
      const Text('Aucune conversation',
          style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Text(
        'Envoyez un message à une nounou\ndepuis son profil !',
        style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}
