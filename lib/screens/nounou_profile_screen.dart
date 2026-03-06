import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';
import 'historique_screen.dart';

class NounouProfileScreen extends StatelessWidget {
  final Map<String, dynamic> nounouData;
  const NounouProfileScreen({super.key, required this.nounouData});

  String get _initiales {
    final p = (nounouData['prenom'] ?? '');
    final n = (nounouData['nom'] ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final prenom = nounouData['prenom'] ?? '';
    final nom = nounouData['nom'] ?? '';
    final ville = nounouData['ville'] ?? 'Non renseignée';
    final prix = nounouData['prixHeure'];
    final score = (nounouData['score'] ?? 0.0).toDouble();
    final nbAvis = nounouData['nbAvis'] ?? 0;
    final bio = nounouData['bio'] ?? '';
    final photoBase64 = nounouData['photoBase64'] as String?;
    final diplomes = List<String>.from(nounouData['diplomes'] ?? []);
    final competences = List<String>.from(nounouData['competences'] ?? []);
    final experiences = List<String>.from(nounouData['experiences'] ?? []);
    final ageGroups = List<String>.from(nounouData['ageGroups'] ?? []);
    final disponibilites = List<String>.from(nounouData['disponibilites'] ?? []);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
        ),
        child: CustomScrollView(slivers: [

          SliverAppBar(
            expandedHeight: 280, pinned: true,
            backgroundColor: AppColors.primaryPink,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8FAB), AppColors.primaryPink]),
                ),
                child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
                    child: ClipOval(child: photoBase64 != null
                        ? Image.memory(base64Decode(photoBase64), fit: BoxFit.cover)
                        : Container(color: Colors.white.withOpacity(0.3),
                        child: Center(child: Text(_initiales,
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white))))),
                  ),
                  const SizedBox(height: 12),
                  Text('$prenom $nom',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(ville, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    if (prix != null) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.payments_outlined, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('$prix DA/h', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  if (score > 0) Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => Icon(
                      i < score.floor() ? Icons.star_rounded : (i < score ? Icons.star_half_rounded : Icons.star_outline_rounded),
                      color: Colors.amber, size: 20,
                    ))..add(const SizedBox(width: 8))
                      ..add(Text('$score ($nbAvis avis)',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  ),
                ])),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Boutons RDV + Message ──
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, __, ___) => BookingScreen(nounouData: nounouData),
                        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 350),
                      )),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('RDV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, __, ___) => ChatScreen(
                          otherUid: nounouData['uid'] ?? '',
                          otherPrenom: prenom,
                          otherNom: nom,
                          otherPhotoBase64: nounouData['photoBase64'] as String?,
                        ),
                        transitionsBuilder: (_, anim, __, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                        transitionDuration: const Duration(milliseconds: 350),
                      )),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonBlue, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                if (bio.isNotEmpty) ...[
                  _SectionTitle(label: 'À propos'),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(16), decoration: _cardDecoration(),
                      child: Text(bio, style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.6))),
                  const SizedBox(height: 20),
                ],

                if (disponibilites.isNotEmpty) ...[
                  _SectionTitle(label: '🕐 Disponibilités'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: disponibilites.map((d) => _Tag(label: d, color: AppColors.buttonBlue)).toList()),
                  const SizedBox(height: 20),
                ],

                if (ageGroups.isNotEmpty) ...[
                  _SectionTitle(label: '👶 Tranches d\'âge acceptées'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: ageGroups.map((a) => _Tag(label: a, color: AppColors.primaryPink)).toList()),
                  const SizedBox(height: 20),
                ],

                if (diplomes.isNotEmpty) ...[
                  _SectionTitle(label: '🎓 Diplômes'),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(16), decoration: _cardDecoration(),
                    child: Column(children: diplomes.asMap().entries.map((e) => Column(children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.buttonBlue, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500))),
                      ]),
                      if (e.key < diplomes.length - 1) const Divider(height: 16, color: Color(0xFFF5EEF0)),
                    ])).toList()),
                  ),
                  const SizedBox(height: 20),
                ],

                if (competences.isNotEmpty) ...[
                  _SectionTitle(label: '⭐ Compétences'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: competences.map((c) => _Tag(label: c, color: const Color(0xFF9B59B6))).toList()),
                  const SizedBox(height: 20),
                ],

                if (experiences.isNotEmpty) ...[
                  _SectionTitle(label: '💼 Expériences'),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(16), decoration: _cardDecoration(),
                    child: Column(children: experiences.asMap().entries.map((e) => Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(margin: const EdgeInsets.only(top: 6), width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.4))),
                      ]),
                      if (e.key < experiences.length - 1) const Divider(height: 16, color: Color(0xFFF5EEF0)),
                    ])).toList()),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Avis depuis Firestore ──
                const _SectionTitle(label: '💬 Avis'),
                const SizedBox(height: 10),
                AvisNounouSection(nounouUid: nounouData['uid'] ?? ''),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
  );
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark));
}

class _Tag extends StatelessWidget {
  final String label; final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
  );
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentCard({required this.comment});
  @override
  Widget build(BuildContext context) {
    final auteur = comment['auteur'] ?? 'Anonyme';
    final texte = comment['texte'] ?? '';
    final note = (comment['note'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(auteur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Row(children: List.generate(5, (i) => Icon(i < note ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.amber, size: 14))),
        ]),
        if (texte.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(texte, style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5)),
        ],
      ]),
    );
  }
}
