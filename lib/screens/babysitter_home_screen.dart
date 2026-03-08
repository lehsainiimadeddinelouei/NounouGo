import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import 'role_selection_screen.dart';
import 'babysitter_setup_screen.dart';
import 'demandes_screen.dart';
import 'conversations_screen.dart';
import 'payment_screen.dart';
import 'historique_screen.dart';
import 'babysitter_edit_profile_screen.dart';

class BabysitterHomeScreen extends StatefulWidget {
  const BabysitterHomeScreen({super.key});
  @override
  State<BabysitterHomeScreen> createState() => _BabysitterHomeScreenState();
}

class _BabysitterHomeScreenState extends State<BabysitterHomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      final profilComplet = data['profilComplet'] ?? false;
      if (!profilComplet && mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const BabysitterSetupScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
        return;
      }
      setState(() { _data = data; _isLoading = false; });
    }
  }

  String get _initiales {
    final p = (_data['prenom'] ?? ''); final n = (_data['nom'] ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordCtrl = TextEditingController();
    bool isLoading = false; String? errorMessage; bool obscure = true;
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(canPop: !isLoading, child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 22), SizedBox(width: 10),
            Text('Supprimer le compte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Text('⚠️ Action irréversible. Toutes vos données seront supprimées.',
                  style: TextStyle(fontSize: 13, color: Colors.red, height: 1.4), textAlign: TextAlign.center)),
            const SizedBox(height: 14),
            if (errorMessage != null) ...[
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(errorMessage!, style: const TextStyle(fontSize: 13, color: Colors.red))),
              const SizedBox(height: 10),
            ],
            TextField(controller: passwordCtrl, obscureText: obscure,
              decoration: InputDecoration(hintText: 'Mot de passe', filled: true, fillColor: const Color(0xFFFFF5F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                suffixIcon: GestureDetector(onTap: () => set(() => obscure = !obscure),
                    child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20)))),
          ]),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: isLoading ? null : () async {
                if (passwordCtrl.text.isEmpty) { set(() => errorMessage = 'Saisissez votre mot de passe.'); return; }
                set(() { isLoading = true; errorMessage = null; });
                try {
                  final user = _auth.currentUser!;
                  final uid  = user.uid;
                  final email = (user.email ?? '').toLowerCase();

                  // 1. Réauthentifier
                  final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
                  await user.reauthenticateWithCredential(cred);

                  // 2. Supprimer la sous-collection documents/
                  try {
                    final docsSnap = await FirebaseFirestore.instance
                        .collection('users').doc(uid).collection('documents').get();
                    for (final d in docsSnap.docs) await d.reference.delete();
                  } catch (_) {}

                  // 3. Enregistrer dans deleted_accounts pour bloquer réinscription
                  try {
                    await FirebaseFirestore.instance.collection('deleted_accounts').doc(uid).set({
                      'uid': uid,
                      'email': email,
                      'prenom': _data['prenom'] ?? '',
                      'nom': _data['nom'] ?? '',
                      'deletedAt': FieldValue.serverTimestamp(),
                      'deletedBySelf': true,
                    });
                  } catch (_) {}

                  // 4. Supprimer le document Firestore
                  await FirebaseFirestore.instance.collection('users').doc(uid).delete();

                  // 5. Supprimer le compte Firebase Auth
                  await user.delete();

                  if (ctx.mounted) Navigator.of(ctx).pop();
                } on FirebaseAuthException catch (e) {
                  set(() {
                    isLoading = false;
                    errorMessage = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                        ? 'Mot de passe incorrect.'
                        : 'Erreur Auth: ${e.code}';
                  });
                } catch (e) {
                  set(() { isLoading = false; errorMessage = 'Erreur: ${e.toString().substring(0, e.toString().length.clamp(0, 80))}'; });
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
            ),
          ],
        )),
      ),
    );
    passwordCtrl.dispose();
    if (_auth.currentUser == null && mounted) {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryPink)));
    }

    final uid = _auth.currentUser?.uid ?? '';
    final screens = [
      _ProfilTab(data: _data, initiales: _initiales, onDelete: _showDeleteAccountDialog, onLogout: () async {
        await _auth.signOut();
        if (mounted) Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ), (route) => false);
      }),
      const DemandesScreen(role: 'Babysitter'),
      const ConversationsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _NavItem(icon: Icons.person_rounded, label: 'Mon Profil', selected: _currentIndex == 0,
                  color: AppColors.primaryPink, onTap: () => setState(() => _currentIndex = 0)),
              _NavItemBadge(icon: Icons.calendar_month_rounded, label: 'Demandes', selected: _currentIndex == 1,
                  color: AppColors.primaryPink, onTap: () => setState(() => _currentIndex = 1), uid: uid),
              _NavItemMsgBadge(icon: Icons.chat_bubble_outline_rounded, label: 'Messages', selected: _currentIndex == 2,
                  color: AppColors.primaryPink, onTap: () => setState(() => _currentIndex = 2), uid: uid),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: selected ? color : AppColors.textGrey, size: 24),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? color : AppColors.textGrey)),
      ]),
    ),
  );
}

class _NavItemBadge extends StatelessWidget {
  final IconData icon; final String label; final bool selected;
  final Color color; final VoidCallback onTap; final String uid;
  const _NavItemBadge({required this.icon, required this.label, required this.selected,
    required this.color, required this.onTap, required this.uid});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? color : AppColors.textGrey, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? color : AppColors.textGrey)),
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('demandes')
            .where('nounouUid', isEqualTo: uid).where('statut', isEqualTo: 'en_attente').snapshots(),
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Positioned(top: 0, right: 0,
            child: Container(width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
              child: Center(child: Text('$count',
                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))));
        },
      ),
    ]),
  );
}

// ── Onglet profil babysitter ──
class _ProfilTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String initiales;
  final VoidCallback onDelete;
  final VoidCallback onLogout;
  const _ProfilTab({required this.data, required this.initiales, required this.onDelete, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final photoBase64 = data['photoBase64'] as String?;
    final score = (data['score'] ?? 0.0).toDouble();
    final nbAvis = data['nbAvis'] ?? 0;
    final diplomes = List<String>.from(data['diplomes'] ?? []);
    final competences = List<String>.from(data['competences'] ?? []);
    final disponibilites = List<String>.from(data['disponibilites'] ?? []);
    final autorisee = (data['autoriseeATravail'] ?? false) || (data['compteActif'] ?? false);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
      ),
      child: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220, pinned: true,
          backgroundColor: AppColors.primaryPink,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              tooltip: 'Historique gardes',
              onPressed: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HistoriqueScreen(role: 'Babysitter'),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              )),
            ),
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
              tooltip: 'Paiements',
              onPressed: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HistoriquePaiementsScreen(role: 'Babysitter'),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              )),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              tooltip: 'Modifier le profil',
              onPressed: () async {
                // Recharger les données fraîches avant d'éditer
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .get();
                if (doc.exists) {
                  final freshData = doc.data()!;
                  freshData['uid'] = doc.id;
                  if (context.mounted) {
                    Navigator.push(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => BabysitterEditProfileScreen(data: freshData),
                      transitionsBuilder: (_, anim, __, child) =>
                          SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ));
                  }
                }
              },
            ),
            IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.white70),
                tooltip: 'Supprimer le compte', onPressed: onDelete),
            IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: onLogout),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8FAB), AppColors.primaryPink]),
              ),
              child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 20),
                Container(width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: ClipOval(child: photoBase64 != null
                      ? Image.memory(base64Decode(photoBase64), fit: BoxFit.cover)
                      : Container(color: Colors.white.withOpacity(0.3),
                      child: Center(child: Text(initiales, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))))),
                ),
                const SizedBox(height: 10),
                Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(data['ville'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(width: 16),
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text('$score ($nbAvis avis)', style: const TextStyle(fontSize: 13, color: Colors.white)),
                ]),
              ])),
            ),
          ),
        ),
        // ── Banner email non vérifié ──
        if (FirebaseAuth.instance.currentUser?.emailVerified == false)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _EmailVerifBanner(),
          )),

        // Banner statut autorisation
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: autorisee ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: autorisee ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(autorisee ? Icons.verified_rounded : Icons.pending_rounded,
                  color: autorisee ? Colors.green : Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                autorisee ? '✅ Profil vérifié — Vous êtes autorisée à travailler'
                    : "⏳ En attente de validation par l'administrateur",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: autorisee ? Colors.green.shade700 : Colors.orange.shade700),
              )),
            ]),
          ),
        )),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((data['bio'] ?? '').isNotEmpty) ...[
                const Text('À PROPOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                  child: Text(data['bio'], style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.6))),
                const SizedBox(height: 20),
              ],
              if (diplomes.isNotEmpty) ...[
                const Text('DIPLÔMES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                ...diplomes.map((d) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                  child: Row(children: [
                    const Icon(Icons.school_outlined, size: 18, color: AppColors.primaryPink),
                    const SizedBox(width: 12),
                    Text(d, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                  ]))),
                const SizedBox(height: 20),
              ],
              if (competences.isNotEmpty) ...[
                const Text('COMPÉTENCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: competences.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.buttonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(c, style: const TextStyle(fontSize: 13, color: AppColors.buttonBlue, fontWeight: FontWeight.w600)),
                )).toList()),
                const SizedBox(height: 20),
              ],
              if (disponibilites.isNotEmpty) ...[
                const Text('DISPONIBILITÉS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: disponibilites.map((d) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(d, style: const TextStyle(fontSize: 13, color: AppColors.primaryPink, fontWeight: FontWeight.w600)),
                )).toList()),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _NavItemMsgBadge extends StatelessWidget {
  final IconData icon; final String label; final bool selected;
  final Color color; final VoidCallback onTap; final String uid;
  const _NavItemMsgBadge({required this.icon, required this.label, required this.selected,
    required this.color, required this.onTap, required this.uid});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: selected ? color.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? color : AppColors.textGrey, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textGrey)),
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('conversations').where('participants', arrayContains: uid).snapshots(),
        builder: (_, snap) {
          final count = snap.data?.docs.fold<int>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['unread_$uid'] ?? 0) as int);
          }) ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Positioned(top: 0, right: 0,
            child: Container(width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
              child: Center(child: Text('$count', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))));
        },
      ),
    ]),
  );
}


// ═══════════════════════════════════════════════════════════
// Banner vérification email (affiché tant que non vérifié)
// ═══════════════════════════════════════════════════════════
class _EmailVerifBanner extends StatefulWidget {
  @override
  State<_EmailVerifBanner> createState() => _EmailVerifBannerState();
}

class _EmailVerifBannerState extends State<_EmailVerifBanner> {
  bool _sending = false;
  bool _sent    = false;

  Future<void> _resend() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        setState(() { _sending = false; _sent = true; });
        // Reset le message "envoyé" après 5s
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _sent = false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'emailVerified': true});
      } catch (_) {}
      if (mounted) setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Email pas encore vérifié. Vérifiez votre boite mail."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mark_email_unread_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Email non vérifié',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.amber))),
        ]),
        const SizedBox(height: 5),
        const Text(
          'Vérifiez votre boite mail et cliquez sur le lien de confirmation pour activer votre compte.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(children: [
          // Renvoyer email
          Expanded(child: GestureDetector(
            onTap: _resend,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_sending)
                  const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                else
                  Icon(_sent ? Icons.check_rounded : Icons.send_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 6),
                Text(
                  _sent ? 'Envoyé !' : (_sending ? 'Envoi...' : 'Renvoyer'),
                  style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          // Vérifier
          Expanded(child: GestureDetector(
            onTap: _checkVerified,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.35)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text("J'ai vérifié",
                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}
