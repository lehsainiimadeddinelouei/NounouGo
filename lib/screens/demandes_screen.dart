import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'payment_screen.dart';

class DemandesScreen extends StatelessWidget {
  final String role; // 'Parent' ou 'Babysitter'
  const DemandesScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final field = role == 'Parent' ? 'parentUid' : 'nounouUid';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
      ),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Text(role == 'Parent' ? 'Mes demandes' : 'Demandes reçues',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Spacer(),
              // Badge notifications non lues
              _NotifBadge(uid: uid),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('demandes')
                  .where(field, isEqualTo: uid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _EmptyState(role: role);
                }
                final docs = [...snap.data!.docs];
                docs.sort((a, b) {
                  final aTs = (a.data() as Map<String,dynamic>)['createdAt'] as Timestamp?;
                  final bTs = (b.data() as Map<String,dynamic>)['createdAt'] as Timestamp?;
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    data['id'] = docs[i].id;
                    return _DemandeCard(data: data, role: role);
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

class _NotifBadge extends StatelessWidget {
  final String uid;
  const _NotifBadge({required this.uid});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('notifications')
        .where('destinataireUid', isEqualTo: uid)
        .where('lu', isEqualTo: false)
        .snapshots(),
    builder: (_, snap) {
      final count = snap.data?.docs.length ?? 0;
      if (count == 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryPink, borderRadius: BorderRadius.circular(20)),
        child: Text('$count nouvelle${count > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
      );
    },
  );
}

class _DemandeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String role;
  const _DemandeCard({required this.data, required this.role});

  String get _statut => data['statut'] ?? 'en_attente';

  Color get _statutColor {
    switch (_statut) {
      case 'acceptée': return Colors.green;
      case 'refusée': return Colors.red;
      default: return Colors.orange;
    }
  }

  String get _statutLabel {
    switch (_statut) {
      case 'acceptée': return '✓ Acceptée';
      case 'refusée': return '✗ Refusée';
      default: return '⏳ En attente';
    }
  }

  String _formatDateTime() {
    final ts = data['dateTime'] as Timestamp?;
    if (ts == null) return '—';
    final dt = ts.toDate();
    const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${mois[dt.month - 1]} ${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  String get _autreNom => role == 'Parent'
      ? '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}'
      : '${data['parentPrenom'] ?? ''} ${data['parentNom'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    final duree = data['dureeHeures'] ?? 1;
    final nbEnfants = data['nbEnfants'] ?? 1;
    final message = data['message'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: _statutColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _statutColor.withOpacity(0.06),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(child: Text(_autreNom,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _statutColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(_statutLabel, style: TextStyle(fontSize: 12, color: _statutColor, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── Détails ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _InfoRow(icon: Icons.calendar_today_rounded, text: _formatDateTime(), color: AppColors.primaryPink),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.access_time_rounded, text: '$duree heure${duree > 1 ? 's' : ''}', color: AppColors.buttonBlue),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.child_care_rounded, text: '$nbEnfants enfant${nbEnfants > 1 ? 's' : ''}', color: Colors.purple),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.lightPink, borderRadius: BorderRadius.circular(10)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4))),
                ]),
              ),
            ],

            // ── Actions babysitter ──
            if (role == 'Babysitter' && _statut == 'en_attente') ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _ActionBtn(
                  label: 'Refuser', color: Colors.red, icon: Icons.close_rounded,
                  onTap: () => _updateStatut(context, 'refusée'),
                )),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(
                  label: 'Accepter', color: Colors.green, icon: Icons.check_rounded,
                  onTap: () => _updateStatut(context, 'acceptée'),
                )),
              ]),
            ],

            // ── Payer (parent, demande acceptée, pas encore payée) ──
            if (role == 'Parent' && _statut == 'acceptée') ...[
              const SizedBox(height: 12),
              _PaymentStatusRow(data: data, context: context),
            ],

            // ── Annuler (parent, en attente) ──
            if (role == 'Parent' && _statut == 'en_attente') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _cancelDemande(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.cancel_outlined, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Text('Annuler la demande', style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],

            // ── Supprimer (toujours visible) ──
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _deleteDemande(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red, size: 15),
                  SizedBox(width: 6),
                  Text('Supprimer', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _updateStatut(BuildContext context, String newStatut) async {
    final demandeId = data['id'] as String;
    // Charger le prixHeure de la nounou pour le paiement
    Map<String, dynamic> updateData = {'statut': newStatut};
    if (newStatut == 'acceptée') {
      final nounouDoc = await FirebaseFirestore.instance
          .collection('users').doc(data['nounouUid']).get();
      final prixHeure = nounouDoc.data()?['prixHeure'] ?? 0;
      updateData['prixHeure'] = prixHeure;
    }
    await FirebaseFirestore.instance.collection('demandes').doc(demandeId).update(updateData);

    // Notifier le parent
    await FirebaseFirestore.instance.collection('notifications').add({
      'destinataireUid': data['parentUid'],
      'type': 'reponse_demande',
      'demandeId': demandeId,
      'titre': newStatut == 'acceptée' ? 'Demande acceptée ✓' : 'Demande refusée',
      'message': newStatut == 'acceptée'
          ? '${data['nounouPrenom']} a accepté votre demande du ${_formatDateTime()}'
          : '${data['nounouPrenom']} n\'est pas disponible pour cette date.',
      'lu': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatut == 'acceptée' ? 'Demande acceptée !' : 'Demande refusée.'),
        backgroundColor: newStatut == 'acceptée' ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _deleteDemande(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Cette demande sera supprimée définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed == true) {
      final demandeId = data['id'] as String;
      await FirebaseFirestore.instance.collection('demandes').doc(demandeId).delete();
    }
  }

  Future<void> _cancelDemande(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la demande ?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Cette demande sera supprimée.', style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Non', style: TextStyle(color: AppColors.textGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui, annuler', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('demandes').doc(data['id']).delete();
    }
  }
}

class _PaymentStatusRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final BuildContext context;
  const _PaymentStatusRow({required this.data, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final paiementStatut = data['paiementStatut'] as String?;
    final montant = data['paiementMontant'];

    // Déjà payé
    if (paiementStatut != null) {
      final isPaid = paiementStatut == 'payé';
      final color = isPaid ? Colors.green : Colors.orange;
      final icon = isPaid ? Icons.check_circle_rounded : Icons.payments_rounded;
      final label = isPaid
          ? '✓ Payé — ${montant?.toInt() ?? 0} DA'
          : '💵 Cash prévu — ${montant?.toInt() ?? 0} DA';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    // Pas encore payé → bouton Payer
    return GestureDetector(
      onTap: () => Navigator.push(ctx, PageRouteBuilder(
        pageBuilder: (_, __, ___) => PaymentScreen(
          demandeData: data,
          demandeId: data['id'],
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4A90D9), AppColors.buttonBlue]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: AppColors.buttonBlue.withOpacity(0.3),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.payment_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Procéder au paiement',
              style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}


class _InfoRow extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _InfoRow({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label; final Color color; final IconData icon; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String role;
  const _EmptyState({required this.role});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📭', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 16),
      Text(role == 'Parent' ? 'Aucune demande envoyée' : 'Aucune demande reçue',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 8),
      Text(
        role == 'Parent' ? 'Cherchez une nounou et envoyez\nvotre première demande !' : 'Les demandes des parents\napparaîtront ici.',
        style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}
