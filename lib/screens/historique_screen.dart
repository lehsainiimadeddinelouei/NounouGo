import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import 'evaluation_screen.dart';

class HistoriqueScreen extends StatelessWidget {
  final String role; // 'Parent' ou 'Babysitter'
  const HistoriqueScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final field = role == 'Parent' ? 'parentUid' : 'nounouUid';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [

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
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10)],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  role == 'Parent'
                      ? 'Mes gardes passées'
                      : 'Gardes reçues',
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
              ]),
            ),

            // ── Liste ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('demandes')
                    .where(field, isEqualTo: uid)
                    .where('statut', isEqualTo: 'acceptée')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AppColors.primaryPink));
                  }

                  final now = DateTime.now();
                  // Gardes passées uniquement (date dépassée)
                  final docs = (snap.data?.docs ?? []).where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = data['dateTime'] as Timestamp?;
                    if (ts == null) return false;
                    return ts.toDate().isBefore(now);
                  }).toList();

                  // Trier par date décroissante
                  docs.sort((a, b) {
                    final aTs = ((a.data() as Map<String,dynamic>)['dateTime'] as Timestamp?)?.toDate();
                    final bTs = ((b.data() as Map<String,dynamic>)['dateTime'] as Timestamp?)?.toDate();
                    if (aTs == null || bTs == null) return 0;
                    return bTs.compareTo(aTs);
                  });

                  if (docs.isEmpty) {
                    return _EmptyHistorique(role: role);
                  }

                  // Stats résumées
                  final nbGardes = docs.length;
                  final totalHeures = docs.fold<int>(0, (sum, doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return sum + ((d['dureeHeures'] ?? 0) as int);
                  });

                  return Column(children: [
                    // ── Carte stats ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8FAB), AppColors.primaryPink],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: AppColors.primaryPink.withOpacity(0.3),
                              blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Row(children: [
                          _StatBubble(
                              value: '$nbGardes',
                              label: 'Garde${nbGardes > 1 ? 's' : ''}'),
                          const _VertDivider(),
                          _StatBubble(
                              value: '${totalHeures}h',
                              label: 'Total heures'),
                          if (role == 'Babysitter') ...[
                            const _VertDivider(),
                            _AvisStatBubble(nounouUid: uid),
                          ],
                        ]),
                      ),
                    ),

                    // ── Liste gardes ──
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final data =
                              docs[i].data() as Map<String, dynamic>;
                          data['id'] = docs[i].id;
                          return _GardeCard(
                              data: data,
                              role: role,
                              demandeId: docs[i].id);
                        },
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Carte d'une garde ──
class _GardeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String role, demandeId;
  const _GardeCard(
      {required this.data, required this.role, required this.demandeId});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    const jours = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${jours[dt.weekday]} ${dt.day} ${mois[dt.month - 1]} ${dt.year}';
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Cette garde sera supprimée de votre historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('demandes').doc(id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Garde supprimée'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['dateTime'] as Timestamp?;
    final duree = data['dureeHeures'] ?? 1;
    final nbEnfants = data['nbEnfants'] ?? 1;
    final paiementStatut = data['paiementStatut'] as String?;
    final evaluee = data['evaluee'] ?? false;
    final montant = data['paiementMontant'];

    final autreNom = role == 'Parent'
        ? '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}'
        : '${data['parentPrenom'] ?? ''} ${data['parentNom'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header carte
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryPink.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(
                color: AppColors.primaryPink.withOpacity(0.1), width: 1)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.child_care_rounded,
                  color: AppColors.primaryPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(autreNom, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: AppColors.textDark)),
              Text(_formatDate(ts), style: const TextStyle(
                  fontSize: 12, color: AppColors.textGrey)),
            ])),
            // Badge paiement
            if (paiementStatut != null)
              _StatusBadge(
                label: paiementStatut == 'payé' ? '✓ Payé' : '💵 Cash',
                color: paiementStatut == 'payé' ? Colors.green : Colors.orange,
              ),
          ]),
        ),

        // Infos garde
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _InfoChip(icon: Icons.access_time_rounded,
                  label: '$duree h', color: AppColors.buttonBlue),
              const SizedBox(width: 8),
              _InfoChip(icon: Icons.child_care_rounded,
                  label: '$nbEnfants enfant${nbEnfants > 1 ? 's' : ''}',
                  color: Colors.purple),
              if (montant != null) ...[
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.payments_rounded,
                    label: '${montant.toInt()} DA',
                    color: Colors.green),
              ],
            ]),

            // ── Avis existant (si évalué) ──
            if (evaluee) ...[
              const SizedBox(height: 12),
              _AvisExistant(
                  nounouUid: data['nounouUid'] ?? '',
                  demandeId: demandeId),
            ],

            // ── Bouton supprimer ──
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _confirmDelete(context, demandeId),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red, size: 15),
                  SizedBox(width: 6),
                  Text('Supprimer', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

            // ── Bouton évaluer (parent, pas encore évalué) ──
            if (role == 'Parent' && !evaluee) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Charger photo nounou si manquante
                    final enrichedData = Map<String, dynamic>.from(data);
                    if (enrichedData['nounouPhotoBase64'] == null) {
                      try {
                        final nounouDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(enrichedData['nounouUid'])
                            .get();
                        enrichedData['nounouPhotoBase64'] =
                            nounouDoc.data()?['photoBase64'];
                        enrichedData['parentPrenom'] = enrichedData['parentPrenom'] ??
                            (await FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .get()).data()?['prenom'] ?? '';
                        enrichedData['parentNom'] = enrichedData['parentNom'] ?? '';
                      } catch (_) {}
                    }
                    if (!context.mounted) return;
                    Navigator.push(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => EvaluationScreen(
                        demandeData: enrichedData,
                        demandeId: demandeId,
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 350),
                    ));
                  },
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: const Text('Évaluer la garde',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Avis existant sur la carte ──
class _AvisExistant extends StatelessWidget {
  final String nounouUid, demandeId;
  const _AvisExistant(
      {required this.nounouUid, required this.demandeId});

  @override
  Widget build(BuildContext context) => FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('avis')
        .where('demandeId', isEqualTo: demandeId)
        .limit(1)
        .get(),
    builder: (_, snap) {
      if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
      final avis = snap.data!.docs.first.data() as Map<String, dynamic>;
      final note = (avis['notefinale'] ?? 0).toDouble();
      final comment = avis['commentaire'] ?? '';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(note.toStringAsFixed(1),
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: Colors.amber)),
            const SizedBox(width: 8),
            const Text('Votre avis',
                style: TextStyle(fontSize: 12,
                    color: AppColors.textGrey, fontWeight: FontWeight.w600)),
          ]),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment, style: const TextStyle(
                fontSize: 13, color: AppColors.textGrey, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      );
    },
  );
}

// ── Section avis sur profil nounou ──
class AvisNounouSection extends StatelessWidget {
  final String nounouUid;
  const AvisNounouSection({super.key, required this.nounouUid});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('avis')
        .where('nounouUid', isEqualTo: nounouUid)
        .snapshots(),
    builder: (_, snap) {
      final docs = [...(snap.data?.docs ?? [])];
      docs.sort((a, b) {
        final aTs = ((a.data() as Map<String,dynamic>)['createdAt'] as Timestamp?);
        final bTs = ((b.data() as Map<String,dynamic>)['createdAt'] as Timestamp?);
        if (aTs == null || bTs == null) return 0;
        return bTs.compareTo(aTs);
      });

      if (docs.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: const Center(child: Text('Aucun avis pour l\'instant',
              style: TextStyle(fontSize: 14, color: AppColors.textGrey))),
        );
      }

      final avgNote = docs.fold<double>(0, (sum, doc) {
        return sum + ((doc.data() as Map<String,dynamic>)['notefinale'] ?? 0).toDouble();
      }) / docs.length;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Résumé note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 36),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(avgNote.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 28,
                      fontWeight: FontWeight.w900, color: AppColors.textDark)),
              Text('${docs.length} avis',
                  style: const TextStyle(fontSize: 13,
                      color: AppColors.textGrey)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Liste avis
        ...docs.take(5).map((doc) {
          final avis = doc.data() as Map<String, dynamic>;
          return _AvisCard(avis: avis);
        }),

        if (docs.length > 5)
          Center(child: Text('+ ${docs.length - 5} autres avis',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textGrey,
                  fontWeight: FontWeight.w600))),
      ]);
    },
  );
}

class _AvisCard extends StatelessWidget {
  final Map<String, dynamic> avis;
  const _AvisCard({required this.avis});

  @override
  Widget build(BuildContext context) {
    final note = (avis['notefinale'] ?? 0).toDouble();
    final prenom = avis['parentPrenom'] ?? '';
    final nom = avis['parentNom'] ?? '';
    final comment = avis['commentaire'] ?? '';
    final ts = avis['createdAt'] as Timestamp?;
    final dt = ts?.toDate();
    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    final dateStr = dt != null ? '${dt.day} ${mois[dt.month-1]} ${dt.year}' : '';
    final initiales = '${prenom.isNotEmpty ? prenom[0].toUpperCase() : ''}${nom.isNotEmpty ? nom[0].toUpperCase() : ''}';

    final criteres = avis['criteres'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
                color: AppColors.primaryPink.withOpacity(0.12),
                shape: BoxShape.circle),
            child: Center(child: Text(initiales,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryPink)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$prenom $nom',
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(dateStr, style: const TextStyle(
                fontSize: 11, color: AppColors.textGrey)),
          ])),
          // Étoiles
          Row(children: List.generate(5, (i) => Icon(
            i < note.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: 16, color: Colors.amber,
          ))),
        ]),

        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(comment, style: const TextStyle(
              fontSize: 13, color: AppColors.textGrey, height: 1.5)),
        ],

        // Critères détaillés
        if (criteres != null && criteres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6,
            children: criteres.entries
                .where((e) => (e.value as num) > 0)
                .map((e) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  '${e.key} ${_starsText((e.value as num).toDouble())}',
                  style: const TextStyle(fontSize: 11,
                      color: AppColors.primaryPink,
                      fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ]),
    );
  }

  String _starsText(double v) {
    return List.generate(v.round(), (_) => '★').join();
  }
}

// ── Widgets helpers ──
class _StatBubble extends StatelessWidget {
  final String value, label;
  const _StatBubble({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 22,
          fontWeight: FontWeight.w900, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 11,
          color: Colors.white70, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _AvisStatBubble extends StatelessWidget {
  final String nounouUid;
  const _AvisStatBubble({required this.nounouUid});
  @override
  Widget build(BuildContext context) => Expanded(
    child: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(nounouUid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final score = (data?['score'] ?? 0.0).toDouble();
        final nbAvis = data?['nbAvis'] ?? 0;
        return Column(children: [
          Text(score > 0 ? score.toStringAsFixed(1) : '—',
              style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900, color: Colors.white)),
          Text('$nbAvis avis ⭐', style: const TextStyle(
              fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
        ]);
      },
    ),
  );
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 40, color: Colors.white.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(fontSize: 11,
        color: color, fontWeight: FontWeight.w700)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12,
          color: color, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _EmptyHistorique extends StatelessWidget {
  final String role;
  const _EmptyHistorique({required this.role});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 90, height: 90,
        decoration: BoxDecoration(
            color: AppColors.primaryPink.withOpacity(0.08),
            shape: BoxShape.circle),
        child: const Icon(Icons.history_rounded,
            color: AppColors.primaryPink, size: 40)),
      const SizedBox(height: 20),
      const Text('Aucune garde passée',
          style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 8),
      Text(
        role == 'Parent'
            ? 'Vos gardes passées apparaîtront ici'
            : 'Les gardes effectuées apparaîtront ici',
        style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}
