import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final db = FirebaseFirestore.instance;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
          ),
        ),
        child: SafeArea(child: Column(children: [

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 14),
              const Text('Notifications',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Spacer(),
              // Bouton tout marquer comme lu
              TextButton(
                onPressed: () async {
                  final notifs = await db.collection('notifications')
                      .where('destinataireUid', isEqualTo: uid)
                      .where('lu', isEqualTo: false)
                      .get();
                  for (final doc in notifs.docs) {
                    doc.reference.update({'lu': true});
                  }
                },
                child: const Text('Tout lire',
                    style: TextStyle(fontSize: 13, color: AppColors.primaryPink, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ── Liste ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('notifications')
                  .where('destinataireUid', isEqualTo: uid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
                }

                final docs = [...(snap.data?.docs ?? [])];
                // Trier par date décroissante côté client
                docs.sort((a, b) {
                  final aTs = ((a.data() as Map<String,dynamic>)['createdAt'] as Timestamp?);
                  final bTs = ((b.data() as Map<String,dynamic>)['createdAt'] as Timestamp?);
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });

                if (docs.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 90, height: 90,
                      decoration: BoxDecoration(
                          color: AppColors.primaryPink.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded,
                          color: AppColors.primaryPink, size: 42)),
                    const SizedBox(height: 20),
                    const Text('Aucune notification',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    const Text('Vous serez notifié ici\nde toute activité sur votre compte.',
                        style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
                        textAlign: TextAlign.center),
                  ]));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final lu = data['lu'] ?? false;
                    final titre = data['titre'] ?? '';
                    final message = data['message'] ?? '';
                    final type = data['type'] ?? '';
                    final ts = data['createdAt'] as Timestamp?;

                    return Dismissible(
                      key: Key(docs[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                            color: Colors.red, borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                      ),
                      onDismissed: (_) => docs[i].reference.delete(),
                      child: GestureDetector(
                        onTap: () {
                          if (!lu) docs[i].reference.update({'lu': true});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: lu ? Colors.white : AppColors.primaryPink.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: lu ? null : Border.all(
                                color: AppColors.primaryPink.withOpacity(0.2), width: 1.5),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Icône selon type
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: _typeColor(type).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_typeIcon(type), color: _typeColor(type), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(titre,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: lu ? FontWeight.w600 : FontWeight.w800,
                                        color: AppColors.textDark))),
                                if (!lu)
                                  Container(width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                          color: AppColors.primaryPink, shape: BoxShape.circle)),
                              ]),
                              const SizedBox(height: 4),
                              Text(message,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4)),
                              const SizedBox(height: 6),
                              Text(_formatDate(ts?.toDate()),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ])),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ])),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'nouvelle_demande': return Icons.calendar_month_rounded;
      case 'demande_acceptee': return Icons.check_circle_rounded;
      case 'demande_refusee': return Icons.cancel_rounded;
      case 'nouveau_message': return Icons.chat_bubble_rounded;
      case 'paiement_recu': return Icons.payments_rounded;
      case 'nouvel_avis': return Icons.star_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'nouvelle_demande': return AppColors.buttonBlue;
      case 'demande_acceptee': return Colors.green;
      case 'demande_refusee': return Colors.red;
      case 'nouveau_message': return AppColors.primaryPink;
      case 'paiement_recu': return Colors.teal;
      case 'nouvel_avis': return Colors.amber;
      default: return AppColors.primaryPink;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
  }
}
