import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';
import 'historique_screen.dart';
import 'role_selection_screen.dart';

class NounouProfileScreen extends StatefulWidget {
  final Map<String, dynamic> nounouData;
  const NounouProfileScreen({super.key, required this.nounouData});
  @override
  State<NounouProfileScreen> createState() => _NounouProfileScreenState();
}

class _NounouProfileScreenState extends State<NounouProfileScreen> {
  String get _initiales {
    final p = (widget.nounouData['prenom'] ?? '');
    final n = (widget.nounouData['nom'] ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  // Vérifie si c'est la nounou elle-même qui regarde son profil
  bool get _isOwnProfile {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return currentUid != null && currentUid == widget.nounouData['uid'];
  }

  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    bool obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !isLoading,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text('Supprimer le compte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Text('⚠️ Action irréversible. Toutes vos données seront supprimées.',
                    style: TextStyle(fontSize: 13, color: Colors.red, height: 1.4), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 14),
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(errorMsg!, style: const TextStyle(fontSize: 13, color: Colors.red)),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Confirmez votre mot de passe',
                  filled: true, fillColor: const Color(0xFFFFF5F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                  suffixIcon: GestureDetector(
                    onTap: () => set(() => obscure = !obscure),
                    child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: isLoading ? null : () async {
                  if (passwordCtrl.text.isEmpty) {
                    set(() => errorMsg = 'Saisissez votre mot de passe.');
                    return;
                  }
                  set(() { isLoading = true; errorMsg = null; });
                  try {
                    final user = FirebaseAuth.instance.currentUser!;
                    final uid  = user.uid;
                    final email = (user.email ?? '').toLowerCase();

                    // 1. Réauthentifier
                    final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
                    await user.reauthenticateWithCredential(cred);

                    // 2. Supprimer sous-collection documents/
                    try {
                      final docsSnap = await FirebaseFirestore.instance
                          .collection('users').doc(uid).collection('documents').get();
                      for (final d in docsSnap.docs) await d.reference.delete();
                    } catch (_) {}

                    // 3. Enregistrer dans deleted_accounts
                    try {
                      await FirebaseFirestore.instance.collection('deleted_accounts').doc(uid).set({
                        'uid': uid, 'email': email,
                        'prenom': widget.nounouData['prenom'] ?? '',
                        'nom': widget.nounouData['nom'] ?? '',
                        'deletedAt': FieldValue.serverTimestamp(),
                        'deletedBySelf': true,
                      });
                    } catch (_) {}

                    // 4. Supprimer document Firestore
                    await FirebaseFirestore.instance.collection('users').doc(uid).delete();

                    // 5. Supprimer compte Auth
                    await user.delete();

                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } on FirebaseAuthException catch (e) {
                    set(() {
                      isLoading = false;
                      errorMsg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                          ? 'Mot de passe incorrect.' : 'Erreur: ${e.code}';
                    });
                  } catch (e) {
                    set(() { isLoading = false; errorMsg = 'Erreur: $e'; });
                  }
                },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
    passwordCtrl.dispose();

    // Si supprimé → aller au login
    if (FirebaseAuth.instance.currentUser == null && mounted) {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prenom = widget.nounouData['prenom'] ?? '';
    final nom = widget.nounouData['nom'] ?? '';
    final ville = widget.nounouData['ville'] ?? 'Non renseignée';
    final prix = widget.nounouData['prixHeure'];
    final score = (widget.nounouData['score'] ?? 0.0).toDouble();
    final nbAvis = widget.nounouData['nbAvis'] ?? 0;
    final bio = widget.nounouData['bio'] ?? '';
    final photoBase64 = widget.nounouData['photoBase64'] as String?;
    final diplomes = List<String>.from(widget.nounouData['diplomes'] ?? []);
    final competences = List<String>.from(widget.nounouData['competences'] ?? []);
    final experiences = List<String>.from(widget.nounouData['experiences'] ?? []);
    final ageGroups = List<String>.from(widget.nounouData['ageGroups'] ?? []);
    final disponibilites = List<String>.from(widget.nounouData['disponibilites'] ?? []);

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
            actions: _isOwnProfile ? [
              GestureDetector(
                onTap: _deleteAccount,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ] : null,
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
                        pageBuilder: (_, __, ___) => BookingScreen(nounouData: widget.nounouData),
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
                          otherUid: widget.nounouData['uid'] ?? '',
                          otherPrenom: prenom,
                          otherNom: nom,
                          otherPhotoBase64: widget.nounouData['photoBase64'] as String?,
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
                AvisNounouSection(nounouUid: widget.nounouData['uid'] ?? ''),

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
