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
import 'notifications_screen.dart';

// ─────────────────────────────────────────────────────────────
// BABYSITTER HOME SCREEN  (premier écran après connexion)
// ─────────────────────────────────────────────────────────────
class BabysitterHomeScreen extends StatefulWidget {
  const BabysitterHomeScreen({super.key});
  @override
  State<BabysitterHomeScreen> createState() => _BabysitterHomeScreenState();
}

class _BabysitterHomeScreenState extends State<BabysitterHomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  Map<String, dynamic> _data = {};
  bool _isLoading   = true;
  int  _currentIndex = 0; // 0=Accueil  1=Demandes  2=Messages  3=Profil

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

  /// Reload user data from Firestore (called after returning from edit screen).
  Future<void> _reloadData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _data = doc.data()!);
      }
    } catch (_) {}
  }

  String get _initiales {
    final p = (_data['prenom'] ?? '');
    final n = (_data['nom']   ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
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
              Text('Supprimer le compte',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text(
                    '⚠️ Action irréversible. Toutes vos données seront supprimées.',
                    style: TextStyle(fontSize: 13, color: Colors.red, height: 1.4),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 14),
              if (errorMessage != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(errorMessage!,
                        style: const TextStyle(fontSize: 13, color: Colors.red))),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  filled: true,
                  fillColor: const Color(0xFFFFF5F7),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                  suffixIcon: GestureDetector(
                      onTap: () => set(() => obscure = !obscure),
                      child: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey,
                          size: 20)),
                ),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  if (passwordCtrl.text.isEmpty) {
                    set(() => errorMessage = 'Saisissez votre mot de passe.');
                    return;
                  }
                  set(() { isLoading = true; errorMessage = null; });
                  try {
                    final user  = _auth.currentUser!;
                    final uid   = user.uid;
                    final email = (user.email ?? '').toLowerCase();
                    final cred  = EmailAuthProvider.credential(
                        email: user.email!, password: passwordCtrl.text);
                    await user.reauthenticateWithCredential(cred);
                    try {
                      final docsSnap = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('documents')
                          .get();
                      for (final d in docsSnap.docs) await d.reference.delete();
                    } catch (_) {}
                    try {
                      await FirebaseFirestore.instance
                          .collection('deleted_accounts')
                          .doc(uid)
                          .set({
                        'uid': uid,
                        'email': email,
                        'prenom': _data['prenom'] ?? '',
                        'nom': _data['nom'] ?? '',
                        'deletedAt': FieldValue.serverTimestamp(),
                        'deletedBySelf': true,
                      });
                    } catch (_) {}
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .delete();
                    await user.delete();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } on FirebaseAuthException catch (e) {
                    set(() {
                      isLoading    = false;
                      errorMessage = (e.code == 'wrong-password' ||
                          e.code == 'invalid-credential')
                          ? 'Mot de passe incorrect.'
                          : 'Erreur Auth: ${e.code}';
                    });
                  } catch (e) {
                    set(() {
                      isLoading    = false;
                      errorMessage = 'Erreur: ${e.toString().substring(0, e.toString().length.clamp(0, 80))}';
                    });
                  }
                },
                child: isLoading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : const Text('Supprimer',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
    passwordCtrl.dispose();
    if (_auth.currentUser == null && mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
              (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPink)));
    }

    final uid = _auth.currentUser?.uid ?? '';

    final screens = [
      // 0 – Accueil (dashboard)
      _HomeTab(uid: uid, onDemandesTab: () => setState(() => _currentIndex = 1)),
      // 1 – Demandes
      const DemandesScreen(role: 'Babysitter'),
      // 2 – Messages
      const ConversationsScreen(),
      // 3 – Mon Profil
      _ProfilTab(
        data: _data,
        initiales: _initiales,
        onDelete: _showDeleteAccountDialog,
        onLogout: () async {
          await _auth.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
                    (route) => false);
          }
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        uid: uid,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION  (identique au design parent)
// ─────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final String uid;
  final ValueChanged<int> onTap;
  const _BottomNav(
      {required this.currentIndex, required this.uid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B8A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                activeIcon: Icons.home_rounded,
                label: 'Accueil',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItemBadge(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note_rounded,
                label: 'Demandes',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
                uid: uid,
              ),
              _NavItemMsgBadge(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Messages',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                uid: uid,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF6B8A).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selected ? activeIcon : icon,
              key: ValueKey(selected),
              color: selected
                  ? const Color(0xFFFF6B8A)
                  : const Color(0xFFB0AFBC),
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFFFF6B8A)
                  : const Color(0xFFB0AFBC),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NavItemBadge extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String uid;
  const _NavItemBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B8A).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: selected
                    ? const Color(0xFFFF6B8A)
                    : const Color(0xFFB0AFBC),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xFFFF6B8A)
                    : const Color(0xFFB0AFBC),
              ),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('demandes')
              .where('nounouUid', isEqualTo: uid)
              .where('statut', isEqualTo: 'en_attente')
              .snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _NavItemMsgBadge extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String uid;
  const _NavItemMsgBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B8A).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: selected
                    ? const Color(0xFFFF6B8A)
                    : const Color(0xFFB0AFBC),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xFFFF6B8A)
                    : const Color(0xFFB0AFBC),
              ),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: uid)
              .snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.fold<int>(0, (sum, doc) {
              final data = doc.data() as Map<String, dynamic>;
              return sum + ((data['unread_$uid'] ?? 0) as int);
            }) ??
                0;
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOME TAB  (onglet Accueil — index 0)
// ─────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String uid;
  final VoidCallback onDemandesTab;
  const _HomeTab({required this.uid, required this.onDemandesTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F4FB),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting header ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: const [
                                Icon(Icons.wb_sunny_outlined,
                                    size: 16, color: Color(0xFFFFB347)),
                                SizedBox(width: 6),
                                Text(
                                  'Bonjour,',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF9E9AAB),
                                      fontWeight: FontWeight.w500),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .snapshots(),
                                builder: (_, snap) {
                                  final prenom =
                                  (snap.data?.get('prenom') ?? '') as String;
                                  return Text(
                                    prenom.isNotEmpty ? prenom : 'Babysitter',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E1B2E),
                                      letterSpacing: -0.5,
                                    ),
                                  );
                                },
                              ),
                            ]),
                        _NotifBell(uid: uid),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ── Hero card ────────────────────────────
                    _HeroDashboardCard(onDemandesTab: onDemandesTab),

                    const SizedBox(height: 28),

                    // ── Stats rapides ─────────────────────────
                    _StatsRow(uid: uid),

                    const SizedBox(height: 28),

                    // ── Dernières demandes reçues ─────────────
                    _LastDemandesWidget(
                      uid: uid,
                      onViewAll: onDemandesTab,
                    ),

                    const SizedBox(height: 28),

                    // ── Accès rapide ──────────────────────────
                    const Text(
                      'Accès rapide',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1B2E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    _QuickGrid(uid: uid),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification bell ────────────────────────────────────────
class _NotifBell extends StatelessWidget {
  final String uid;
  const _NotifBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('destinataireUid', isEqualTo: uid)
          .where('lu', isEqualTo: false)
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const NotificationsScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: Color(0xFF1E1B2E), size: 22),
            ),
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B8A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ── Hero dashboard card ──────────────────────────────────────
class _HeroDashboardCard extends StatelessWidget {
  final VoidCallback onDemandesTab;
  const _HeroDashboardCard({required this.onDemandesTab});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDemandesTab,
      child: Container(
        width: double.infinity,
        height: 164,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B8A), Color(0xFFFF94B0), Color(0xFFFFB7CC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B8A).withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(children: [
          // Decorative circles
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Icon
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.child_care_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
          ),
          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 120, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text(
                    'Mes demandes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Consultez vos réservations\net gardes en cours',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Text(
                      'Voir tout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF6B8A),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Color(0xFFFF6B8A)),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes')
          .where('nounouUid', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        final all      = snap.data?.docs ?? [];
        final accepted = all
            .where((d) => (d.data() as Map)['statut'] == 'acceptée')
            .length;
        final pending  = all
            .where((d) => (d.data() as Map)['statut'] == 'en_attente')
            .length;

        return Row(children: [
          Expanded(
            child: _StatChip(
              icon: Icons.event_available_rounded,
              value: '$accepted',
              label: 'Acceptées',
              iconColor: const Color(0xFF43C59E),
              bgColor: const Color(0xFFE6F7F2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatChip(
              icon: Icons.hourglass_top_rounded,
              value: '$pending',
              label: 'En attente',
              iconColor: const Color(0xFFFFB347),
              bgColor: const Color(0xFFFFF4E0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatChip(
              icon: Icons.favorite_rounded,
              value: '${all.length}',
              label: 'Total gardes',
              iconColor: const Color(0xFFFF6B8A),
              bgColor: const Color(0xFFFFEEF2),
            ),
          ),
        ]);
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color iconColor, bgColor;
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: iconColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF9E9AAB),
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ── Dernières demandes reçues ────────────────────────────────
class _LastDemandesWidget extends StatelessWidget {
  final String uid;
  final VoidCallback onViewAll;
  const _LastDemandesWidget(
      {required this.uid, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes')
          .where('nounouUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(2)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dernières demandes',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1B2E),
                      letterSpacing: -0.3),
                ),
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Voir tout',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF6B8A),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final data   = doc.data() as Map<String, dynamic>;
            final statut = data['statut'] ?? 'en_attente';
            final parentNom =
                '${data['parentPrenom'] ?? ''} ${data['parentNom'] ?? ''}';
            final ts = data['dateTime'] as Timestamp?;
            final dt = ts?.toDate();
            const mois = [
              'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
              'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
            ];
            final dateStr = dt != null
                ? '${dt.day} ${mois[dt.month - 1]} · ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}'
                : '';

            final (color, bgColor, icon, statutLabel) =
            switch (statut) {
              'acceptée' => (
              const Color(0xFF43C59E),
              const Color(0xFFE6F7F2),
              Icons.check_circle_rounded,
              'Acceptée',
              ),
              'refusée' => (
              const Color(0xFFE05C7A),
              const Color(0xFFFFEEF2),
              Icons.cancel_rounded,
              'Refusée',
              ),
              _ => (
              const Color(0xFFFFB347),
              const Color(0xFFFFF4E0),
              Icons.schedule_rounded,
              'En attente',
              ),
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parentNom.trim().isEmpty
                                ? 'Parent'
                                : parentNom.trim(),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1B2E)),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.access_time_rounded,
                                size: 12, color: Color(0xFF9E9AAB)),
                            const SizedBox(width: 3),
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF9E9AAB))),
                          ]),
                        ])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    statutLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 4),
        ]);
      },
    );
  }
}

// ── Quick access grid ────────────────────────────────────────
class _QuickGrid extends StatelessWidget {
  final String uid;
  const _QuickGrid({required this.uid});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickItem(
        icon: Icons.event_note_rounded,
        label: 'Demandes',
        color: const Color(0xFFFF6B8A),
        bgColor: const Color(0xFFFFEEF2),
        onTap: () {
          final s = context
              .findAncestorStateOfType<_BabysitterHomeScreenState>();
          s?.setState(() => s._currentIndex = 1);
        },
      ),
      _QuickItem(
        icon: Icons.chat_bubble_rounded,
        label: 'Messages',
        color: const Color(0xFF5B7FFF),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () {
          final s = context
              .findAncestorStateOfType<_BabysitterHomeScreenState>();
          s?.setState(() => s._currentIndex = 2);
        },
      ),
      _QuickItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Paiements',
        color: const Color(0xFF43C59E),
        bgColor: const Color(0xFFE6F7F2),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
            const HistoriquePaiementsScreen(role: 'Babysitter'),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
      ),
      _QuickItem(
        icon: Icons.history_rounded,
        label: 'Historique',
        color: const Color(0xFF9B72CF),
        bgColor: const Color(0xFFF3EEFF),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
            const HistoriqueScreen(role: 'Babysitter'),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
      ),
      _QuickItem(
        icon: Icons.star_rounded,
        label: 'Mes avis',
        color: const Color(0xFFFFB347),
        bgColor: const Color(0xFFFFF4E0),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
            const HistoriqueScreen(role: 'Babysitter'),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
      ),
      _QuickItem(
        icon: Icons.person_rounded,
        label: 'Profil',
        color: const Color(0xFF3BBFBF),
        bgColor: const Color(0xFFE0F7F7),
        onTap: () {
          final s = context
              .findAncestorStateOfType<_BabysitterHomeScreenState>();
          s?.setState(() => s._currentIndex = 3);
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => _QuickCard(item: item)).toList(),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final VoidCallback onTap;
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

class _QuickCard extends StatelessWidget {
  final _QuickItem item;
  const _QuickCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              item.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1B2E)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFIL TAB  (onglet Profil — index 3)
// StatefulWidget so it reloads fresh data from Firestore every
// time the user navigates back from the edit screen.
// ─────────────────────────────────────────────────────────────
class _ProfilTab extends StatefulWidget {
  final Map<String, dynamic> data;
  final String initiales;
  final VoidCallback onDelete;
  final VoidCallback onLogout;
  const _ProfilTab({
    required this.data,
    required this.initiales,
    required this.onDelete,
    required this.onLogout,
  });

  @override
  State<_ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<_ProfilTab> {
  late Map<String, dynamic> _localData;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.data);
  }

  /// Reload user doc from Firestore and update local state.
  Future<void> _refresh() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _refreshing = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _localData = doc.data()!;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Open edit screen and refresh profile when user comes back.
  Future<void> _openEdit(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists || !ctx.mounted) return;
    final freshData  = doc.data()!;
    freshData['uid'] = doc.id;
    await Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            BabysitterEditProfileScreen(data: freshData),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
              parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    // Refresh profile data after returning from edit screen
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data        = _localData;
    final photoBase64 = data['photoBase64'] as String?;
    final initiales   = widget.initiales;   // kept for fallback avatar
    final score       = (data['score'] ?? 0.0).toDouble();
    final nbAvis      = data['nbAvis'] ?? 0;
    final diplomes    = List<String>.from(data['diplomes']    ?? []);
    final competences = List<String>.from(data['competences'] ?? []);

    // Structured disponibilités: Map<String, List<String>> jour → periodes
    // Also handle legacy flat List<String> gracefully
    Map<String, List<String>> disponibilitesMap = {};
    final rawDispos = data['disponibilites'];
    if (rawDispos is Map) {
      rawDispos.forEach((jour, periodes) {
        if (periodes is List && periodes.isNotEmpty) {
          disponibilitesMap[jour.toString()] =
          List<String>.from(periodes.map((p) => p.toString()));
        }
      });
    }
    final disponibilitesLegacy = rawDispos is List
        ? List<String>.from(rawDispos)
        : <String>[];

    final autorisee = (data['autoriseeATravail'] ?? false) ||
        (data['compteActif'] ?? false);

    // Recompute initiales from local data in case name was changed
    final prenom = data['prenom'] ?? '';
    final nom    = data['nom']    ?? '';
    final localInitiales =
        '${prenom.isNotEmpty ? (prenom as String)[0].toUpperCase() : ''}'
        '${nom.isNotEmpty    ? (nom    as String)[0].toUpperCase() : ''}';

    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundGradientEnd
            ],
          ),
        ),
        child: CustomScrollView(slivers: [

          // ── SliverAppBar ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.primaryPink,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                tooltip: 'Historique gardes',
                onPressed: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                      const HistoriqueScreen(role: 'Babysitter'),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 350),
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white),
                tooltip: 'Paiements',
                onPressed: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                      const HistoriquePaiementsScreen(role: 'Babysitter'),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 350),
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                tooltip: 'Modifier le profil',
                onPressed: () => _openEdit(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded,
                    color: Colors.white70),
                tooltip: 'Supprimer le compte',
                onPressed: widget.onDelete,
              ),
              IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: widget.onLogout),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8FAB), AppColors.primaryPink],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),
                        // Avatar
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 16)
                            ],
                          ),
                          child: ClipOval(
                              child: photoBase64 != null
                                  ? Image.memory(base64Decode(photoBase64),
                                  fit: BoxFit.cover)
                                  : Container(
                                  color: Colors.white.withOpacity(0.3),
                                  child: Center(
                                      child: Text(localInitiales,
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white))))),
                        ),
                        const SizedBox(height: 10),
                        Text(
                            '${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.child_care_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Babysitter',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(data['ville'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70)),
                          const SizedBox(width: 16),
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text('$score ($nbAvis avis)',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white)),
                        ]),
                      ]),
                ),
              ),
            ),
          ),

          // ── Email verification banner ────────────────────────
          if (FirebaseAuth.instance.currentUser?.emailVerified == false)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _EmailVerifBanner())),

          // ── Authorization status banner ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: autorisee
                      ? Colors.green.withOpacity(0.08)
                      : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: autorisee
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(
                      autorisee
                          ? Icons.verified_rounded
                          : Icons.pending_rounded,
                      color: autorisee ? Colors.green : Colors.orange,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      autorisee
                          ? '✅ Profil vérifié — Vous êtes autorisée à travailler'
                          : "⏳ En attente de validation par l'administrateur",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: autorisee
                              ? Colors.green.shade700
                              : Colors.orange.shade700),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Profile body ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Informations personnelles
                    _SectionTitle(label: 'Informations personnelles'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: _cardDec(),
                      child: Column(children: [
                        _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Prénom',
                            value: data['prenom'] ?? ''),
                        const _Divider(),
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Nom',
                            value: data['nom'] ?? ''),
                        const _Divider(),
                        _InfoRow(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: FirebaseAuth.instance.currentUser?.email ?? ''),
                        const _Divider(),
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Ville',
                            value: data['ville'] ?? ''),
                        if (data['prixHeure'] != null) ...[
                          const _Divider(),
                          _InfoRow(
                              icon: Icons.payments_outlined,
                              label: 'Tarif horaire',
                              value: '${data['prixHeure']} DA/h'),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // À propos
                    if ((data['bio'] ?? '').isNotEmpty) ...[
                      _SectionTitle(label: 'À propos'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDec(),
                        child: Text(data['bio'],
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                                height: 1.6)),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Diplômes
                    if (diplomes.isNotEmpty) ...[
                      _SectionTitle(label: 'Diplômes'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: _cardDec(),
                        child: Column(
                            children: diplomes.asMap().entries.map((e) => Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryPink
                                              .withOpacity(0.08),
                                          borderRadius:
                                          BorderRadius.circular(10)),
                                      child: const Icon(Icons.school_outlined,
                                          size: 18,
                                          color: AppColors.primaryPink),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Text(e.value,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textDark))),
                                  ]),
                                ),
                                if (e.key < diplomes.length - 1) const _Divider(),
                              ],
                            )).toList()),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Compétences
                    if (competences.isNotEmpty) ...[
                      _SectionTitle(label: 'Compétences'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: competences
                            .map((c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.buttonBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                AppColors.buttonBlue.withOpacity(0.2)),
                          ),
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.buttonBlue,
                                  fontWeight: FontWeight.w600)),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Disponibilités (structured: day → periods)
                    if (disponibilitesMap.isNotEmpty) ...[
                      _SectionTitle(label: 'Disponibilités'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        decoration: _cardDec(),
                        child: Column(
                          children: disponibilitesMap.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((outer) {
                            final isLast = outer.key ==
                                disponibilitesMap.entries.length - 1;
                            final jour    = outer.value.key;
                            final periodes = outer.value.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jour,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: periodes
                                            .map((p) => Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPink
                                                .withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius.circular(
                                                20),
                                            border: Border.all(
                                                color: AppColors
                                                    .primaryPink
                                                    .withOpacity(0.2)),
                                          ),
                                          child: Text(p,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .primaryPink,
                                                  fontWeight:
                                                  FontWeight.w600)),
                                        ))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const _Divider(),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (disponibilitesLegacy.isNotEmpty) ...[
                      // Legacy flat list fallback
                      _SectionTitle(label: 'Disponibilités'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: disponibilitesLegacy
                            .map((d) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                            AppColors.primaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryPink
                                    .withOpacity(0.2)),
                          ),
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryPink,
                                  fontWeight: FontWeight.w600)),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Documents officiels (read-only status view)
                    _SectionTitle(label: 'Documents officiels'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.amber, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                              'Les documents sont vérifiés par notre équipe. Un badge ✅ sera affiché sur votre profil une fois validés.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  height: 1.4),
                            )),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: _cardDec(),
                      child: Column(children: [
                        _DocStatusRow(
                          icon: Icons.school_rounded,
                          title: 'Diplôme',
                          statut: data['diplomePdfStatut'] as String? ??
                              'non_soumis',
                          fileName: data['diplomePdfName'] as String?,
                          color: AppColors.primaryPink,
                        ),
                        const _Divider(),
                        _DocStatusRow(
                          icon: Icons.description_rounded,
                          title: 'CV',
                          statut: data['cvStatut'] as String? ?? 'non_soumis',
                          fileName: data['cvName'] as String?,
                          color: AppColors.buttonBlue,
                        ),
                        const _Divider(),
                        _DocStatusRow(
                          icon: Icons.badge_rounded,
                          title: "Carte d'identité",
                          statut: data['cniStatut'] as String? ?? 'non_soumis',
                          fileName: data['cniName'] as String?,
                          color: Colors.teal,
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),
                    _SectionTitle(label: 'Sécurité'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _cardDec(),
                      child: Column(children: [
                        _ActionRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Changer le mot de passe',
                            color: AppColors.buttonBlue,
                            onTap: () {}),
                        const _Divider(),
                        _ActionRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Vérification email',
                          color: Colors.green,
                          trailing:
                          FirebaseAuth.instance.currentUser?.emailVerified == true
                              ? _Badge(label: 'Vérifié ✓', color: Colors.green)
                              : _Badge(
                              label: 'En attente', color: Colors.orange),
                          onTap: () {},
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // Déconnexion
                    GestureDetector(
                      onTap: widget.onLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primaryPink.withOpacity(0.3),
                              width: 1.5),
                        ),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded,
                                  color: AppColors.primaryPink, size: 20),
                              SizedBox(width: 10),
                              Text('Se déconnecter',
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.primaryPink,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Suppression compte
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.25), width: 1.5),
                        ),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_forever_rounded,
                                  color: Colors.red, size: 20),
                              SizedBox(width: 10),
                              Text('Supprimer mon compte',
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ]),
            ),
          ),
        ]),
      ), // end Container
      // Loading overlay when refreshing after edit
      if (_refreshing)
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black12,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPink),
            ),
          ),
        ),
    ]); // end Stack
  }

  BoxDecoration _cardDec() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4))
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// SHARED HELPER WIDGETS
// ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey,
          letterSpacing: 1.2));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: AppColors.buttonBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppColors.buttonBlue),
      ),
      const SizedBox(width: 14),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600)),
              ])),
    ]),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 14),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600))),
        trailing ??
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textGrey),
      ]),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w700)),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF5EEF0),
      indent: 16,
      endIndent: 16);
}

class _DocStatusRow extends StatelessWidget {
  final IconData icon;
  final String title, statut;
  final Color color;
  final String? fileName;
  const _DocStatusRow({
    required this.icon,
    required this.title,
    required this.statut,
    required this.color,
    required this.fileName,
  });

  Color get _statutColor {
    switch (statut) {
      case 'validé':     return Colors.green;
      case 'en_attente': return Colors.orange;
      case 'refusé':     return Colors.red;
      default:           return AppColors.textGrey;
    }
  }

  String get _statutLabel {
    switch (statut) {
      case 'validé':     return '✅ Validé';
      case 'en_attente': return '⏳ En vérification';
      case 'refusé':     return '❌ Refusé';
      default:           return 'Non soumis';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                if (fileName != null)
                  Text(fileName!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _statutColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(_statutLabel,
              style: TextStyle(
                  fontSize: 11,
                  color: _statutColor,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EMAIL VERIFICATION BANNER
// ─────────────────────────────────────────────────────────────
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'emailVerified': true});
      } catch (_) {}
      if (mounted) setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text('Email pas encore vérifié. Vérifiez votre boite mail.'),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.mark_email_unread_rounded, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
              child: Text('Email non vérifié',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber))),
        ]),
        const SizedBox(height: 5),
        const Text(
          'Vérifiez votre boite mail et cliquez sur le lien de confirmation pour activer votre compte.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _resend,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_sending)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.amber))
                      else
                        Icon(
                            _sent ? Icons.check_rounded : Icons.send_rounded,
                            color: Colors.amber,
                            size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _sent ? 'Envoyé !' : (_sending ? 'Envoi...' : 'Renvoyer'),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _checkVerified,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.35)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.green, size: 14),
                      SizedBox(width: 6),
                      Text("J'ai vérifié",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
