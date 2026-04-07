import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'search_nounous_screen.dart';
import 'parent_profile_screen.dart';
import 'demandes_screen.dart';
import 'conversations_screen.dart';
import 'payment_screen.dart';
import 'historique_screen.dart';
import 'notifications_screen.dart';
import 'chatbot_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});
  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      _HomeTab(),
      SearchNounousScreen(),
      DemandesScreen(role: 'Parent'),
      ConversationsScreen(),
      ParentProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _ChatFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        uid: uid ?? '',
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION
// ─────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final String uid;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.uid, required this.onTap});

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
              _NavItem(
                icon: Icons.search_rounded,
                activeIcon: Icons.search_rounded,
                label: 'Recherche',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItemBadge(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note_rounded,
                label: 'RDV',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                uid: uid,
                fieldKey: 'demandes',
              ),
              _NavItemBadge(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Messages',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
                uid: uid,
                fieldKey: 'conversations',
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                selected: currentIndex == 4,
                onTap: () => onTap(4),
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
          color: selected ? const Color(0xFFFF6B8A).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selected ? activeIcon : icon,
              key: ValueKey(selected),
              color: selected ? const Color(0xFFFF6B8A) : const Color(0xFFB0AFBC),
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFFFF6B8A) : const Color(0xFFB0AFBC),
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
  final String uid, fieldKey;
  const _NavItemBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.uid,
    required this.fieldKey,
  });

  Stream<int> get _countStream {
    if (fieldKey == 'conversations') {
      return FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .snapshots()
          .map((snap) => snap.docs.fold<int>(
        0,
            (sum, doc) => sum + ((doc.data()['unread_$uid'] ?? 0) as int),
      ));
    }
    return FirebaseFirestore.instance
        .collection('demandes')
        .where('parentUid', isEqualTo: uid)
        .where('statut', isEqualTo: 'en_attente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

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
            color: selected ? const Color(0xFFFF6B8A).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: selected ? const Color(0xFFFF6B8A) : const Color(0xFFB0AFBC),
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFFFF6B8A) : const Color(0xFFB0AFBC),
              ),
            ),
          ]),
        ),
        StreamBuilder<int>(
          stream: _countStream,
          builder: (_, snap) {
            final count = snap.data ?? 0;
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
                      fontWeight: FontWeight.w800,
                    ),
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
// HOME TAB
// ─────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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

                    // ── Header ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFFFFB347)),
                            const SizedBox(width: 6),
                            const Text(
                              'Bonjour,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9E9AAB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .snapshots(),
                            builder: (_, snap) {
                              final prenom = (snap.hasData && snap.data!.exists)
                                  ? ((snap.data!.get('prenom') ?? '') as String)
                                  : '';
                              return Text(
                                prenom.isNotEmpty ? prenom : 'Parent',
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
                    _HeroSearchCard(uid: uid),

                    const SizedBox(height: 28),

                    // ── Stats rapides ─────────────────────────
                    _StatsRow(uid: uid),

                    const SizedBox(height: 28),

                    // ── Dernières demandes ─────────────────────
                    _LastDemandesWidget(
                      uid: uid,
                      onViewAll: () {
                        final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
                        s?.setState(() => s._currentIndex = 2);
                      },
                    ),

                    // ── Paiements en attente ───────────────────
                    _PendingPaymentsWidget(uid: uid),

                    const SizedBox(height: 28),

                    // ── Accès rapide ───────────────────────────
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

// ─────────────────────────────────────────────────────────────
// HERO SEARCH CARD
// ─────────────────────────────────────────────────────────────
class _HeroSearchCard extends StatelessWidget {
  final String uid;
  const _HeroSearchCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
        s?.setState(() => s._currentIndex = 1);
      },
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
          // Cercles décoratifs
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

          // Illustration SVG-style icon
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
                child: const Icon(
                  Icons.child_care_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),

          // Texte
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 120, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trouvez une nounou',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Babysitters qualifiées\nprès de chez vous',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Text(
                      'Rechercher',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF6B8A),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF6B8A)),
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

// ─────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes')
          .where('parentUid', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        final all = snap.data?.docs ?? [];
        final accepted = all.where((d) => (d.data() as Map)['statut'] == 'acceptée').length;
        final pending  = all.where((d) => (d.data() as Map)['statut'] == 'en_attente').length;

        return Row(children: [
          Expanded(
            child: _StatChip(
              icon: Icons.event_available_rounded,
              value: '$accepted',
              label: 'Acceptés',
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
              label: 'Total RDV',
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
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
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
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NOTIFICATION BELL
// ─────────────────────────────────────────────────────────────
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
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1E1B2E),
                size: 22,
              ),
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
                        fontWeight: FontWeight.w800,
                      ),
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

// ─────────────────────────────────────────────────────────────
// DERNIÈRES DEMANDES
// ─────────────────────────────────────────────────────────────
class _LastDemandesWidget extends StatelessWidget {
  final String uid;
  final VoidCallback onViewAll;
  const _LastDemandesWidget({required this.uid, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes')
          .where('parentUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(2)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final docs = snap.data!.docs;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text(
              'Dernières demandes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B2E),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF6B8A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final statut = data['statut'] ?? 'en_attente';
            final nounouNom = '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}';
            final ts = data['dateTime'] as Timestamp?;
            final dt = ts?.toDate();
            const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
            final dateStr = dt != null
                ? '${dt.day} ${mois[dt.month - 1]} · ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}'
                : '';

            final (color, bgColor, icon, statutLabel) = switch (statut) {
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    nounouNom.trim().isEmpty ? 'Nounou' : nounouNom.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF9E9AAB)),
                    const SizedBox(width: 3),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9AAB))),
                  ]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statutLabel,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
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

// ─────────────────────────────────────────────────────────────
// PAIEMENTS EN ATTENTE
// ─────────────────────────────────────────────────────────────
class _PendingPaymentsWidget extends StatelessWidget {
  final String uid;
  const _PendingPaymentsWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes')
          .where('parentUid', isEqualTo: uid)
          .where('statut', isEqualTo: 'acceptée')
          .snapshots(),
      builder: (_, snap) {
        final docs = (snap.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['paiementStatut'] == null;
        }).toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 28),
          Row(children: [
            const Text(
              'Paiements en attente',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B2E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF5B7FFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${docs.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            final nounouNom =
            '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}'.trim();
            final duree = data['dureeHeures'] ?? 1;
            final prix = (data['prixHeure'] ?? 0).toDouble();
            final montant = prix * duree;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      PaymentScreen(demandeData: data, demandeId: doc.id),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B7FFF), Color(0xFF3A5FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B7FFF).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      nounouNom.isEmpty ? 'Nounou' : nounouNom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$duree h · ${montant > 0 ? "${montant.toInt()} DA" : "Voir détails"}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Text(
                        'Payer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5B7FFF),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF5B7FFF)),
                    ]),
                  ),
                ]),
              ),
            );
          }),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUICK ACCESS GRID
// ─────────────────────────────────────────────────────────────
class _QuickGrid extends StatelessWidget {
  final String uid;
  const _QuickGrid({required this.uid});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickItem(
        icon: Icons.search_rounded,
        label: 'Chercher',
        color: const Color(0xFF5B7FFF),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () {
          final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
          s?.setState(() => s._currentIndex = 1);
        },
      ),
      _QuickItem(
        icon: Icons.event_note_rounded,
        label: 'Mes RDV',
        color: const Color(0xFFFF6B8A),
        bgColor: const Color(0xFFFFEEF2),
        onTap: () {
          final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
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
            const HistoriquePaiementsScreen(role: 'Parent'),
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
            const HistoriqueScreen(role: 'Parent'),
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
            const HistoriqueScreen(role: 'Parent'),
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
          final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
          s?.setState(() => s._currentIndex = 4);
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
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B2E),
              ),
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
// BOUTON FLOTTANT CHATBOT
// ─────────────────────────────────────────────────────────────
class _ChatFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
      ),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8FAB), Color(0xFFC8384E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPink.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Center(child: Text('👶', style: TextStyle(fontSize: 26))),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2545),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('IA',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
