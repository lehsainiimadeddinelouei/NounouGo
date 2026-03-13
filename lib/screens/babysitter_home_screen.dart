import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nounou_profile_screen.dart';
import 'babysitter_setup_screen.dart';

// ─────────────────────────────────────────────────────────────
// SCREEN — Main dashboard shown after login
// ─────────────────────────────────────────────────────────────
class BabysitterHomeScreen extends StatefulWidget {
  const BabysitterHomeScreen({super.key});

  @override
  State<BabysitterHomeScreen> createState() => _BabysitterHomeScreenState();
}

class _BabysitterHomeScreenState extends State<BabysitterHomeScreen> {

  // ── Constants ──────────────────────────────────────────────
  static const _pink   = Color(0xFFFF6B8A);
  static const _bg     = Color(0xFFFFF8F9);
  static const _teal   = Color(0xFF43C59E);
  static const _purple = Color(0xFF7C83FD);
  static const _amber  = Color(0xFFFFB347);

  // ── Firebase shortcuts ─────────────────────────────────────
  final _user = FirebaseAuth.instance.currentUser!;

  late final _profileRef = FirebaseFirestore.instance
      .collection('babysitters')
      .doc(_user.uid);

  late final _activitiesRef = _profileRef
      .collection('activities')
      .orderBy('createdAt', descending: true)
      .limit(5);

  // ── Helpers ────────────────────────────────────────────────

  // Returns first name only (e.g. "Amina Bouhired" → "Amina")
  String _firstName(String? full) =>
      (full ?? 'Nounou').trim().split(' ').first;

  // Human-readable time ago string
  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays    == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }

  // Returns icon + color based on activity type string
  ({IconData icon, Color color}) _activityStyle(String type) => switch (type) {
    'request' => (icon: Icons.assignment_rounded,   color: _amber),
    'message' => (icon: Icons.chat_bubble_rounded,  color: _teal),
    'review'  => (icon: Icons.star_rounded,         color: _purple),
    _         => (icon: Icons.notifications_rounded, color: _pink),
  };

  // ── Navigation helpers ─────────────────────────────────────
  void _goTo(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Listen to the profile document for name, photo, and status
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileRef.snapshots(),
      builder: (context, snap) {
        final data        = snap.data?.data() ?? {};
        final fullName    = data['fullName']  ?? _user.displayName ?? '';
        final photoUrl    = data['photoUrl']  ?? _user.photoURL    ?? '';
        final isAvailable = data['isAvailable'] ?? false;

        return Scaffold(
          backgroundColor: _bg,
          bottomNavigationBar: _BottomNav(
            onProfile: () => _goTo(const NounouProfileScreen()),
            onSetup:   () => _goTo(const BabysitterSetupScreen()),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header: avatar + greeting + bell ──────
                  _Header(
                    fullName:  fullName,
                    photoUrl:  photoUrl,
                    firstName: _firstName(fullName),
                    unreadStream: _profileRef
                        .collection('activities')
                        .where('read', isEqualTo: false)
                        .snapshots()
                        .map((s) => s.docs.length),
                  ),
                  const SizedBox(height: 24),

                  // ── Hero card: availability status ────────
                  _HeroCard(
                    isAvailable: isAvailable,
                    onManage: () => _goTo(const BabysitterSetupScreen()),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick-access grid ─────────────────────
                  _SectionLabel(text: 'Accès rapide'),
                  const SizedBox(height: 16),
                  _QuickGrid(
                    onProfile:       () => _goTo(const NounouProfileScreen()),
                    onAvailabilities:() => _goTo(const BabysitterSetupScreen()),
                  ),
                  const SizedBox(height: 24),

                  // ── Recent activity from Firestore ────────
                  _SectionLabel(text: 'Activité récente'),
                  const SizedBox(height: 12),
                  _ActivityList(
                    stream:        _activitiesRef.snapshots(),
                    activityStyle: _activityStyle,
                    timeAgo:       _timeAgo,
                  ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.grey[800],
    ),
  );
}

// Top row: avatar + greeting + notification bell
class _Header extends StatelessWidget {
  final String fullName;
  final String photoUrl;
  final String firstName;
  final Stream<int> unreadStream;

  const _Header({
    required this.fullName,
    required this.photoUrl,
    required this.firstName,
    required this.unreadStream,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Profile avatar (photo or initials fallback)
      CircleAvatar(
        radius: 28,
        backgroundColor: _pink.withOpacity(0.2),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: _pink),
              )
            : null,
      ),
      const SizedBox(width: 14),

      // Greeting text
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour, $firstName 👋',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[850])),
          const SizedBox(height: 2),
          Text('Bienvenue sur Nounou',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ]),
      ),

      // Notification bell with unread dot
      StreamBuilder<int>(
        stream: unreadStream,
        builder: (_, snap) => Stack(children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
            onPressed: () {},
          ),
          if ((snap.data ?? 0) > 0)
            Positioned(
              right: 10, top: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: _pink, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// Pink gradient card showing current availability status
class _HeroCard extends StatelessWidget {
  final bool isAvailable;
  final VoidCallback onManage;
  const _HeroCard({required this.isAvailable, required this.onManage});

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Statut actuel',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              isAvailable ? 'Disponible ✓' : 'Non disponible',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Gérer disponibilités',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        const Icon(Icons.child_care_rounded, color: Colors.white30, size: 72),
      ]),
    );
  }
}

// 2×2 grid of navigation shortcut cards
class _QuickGrid extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onAvailabilities;
  const _QuickGrid({required this.onProfile, required this.onAvailabilities});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickItem(icon: Icons.person_rounded,       label: 'Mon Profil',      color: const Color(0xFFFF6B8A), onTap: onProfile),
      _QuickItem(icon: Icons.calendar_month_rounded,label: 'Disponibilités', color: const Color(0xFF7C83FD), onTap: onAvailabilities),
      _QuickItem(icon: Icons.chat_bubble_rounded,  label: 'Messages',        color: const Color(0xFF43C59E), onTap: () {}),
      _QuickItem(icon: Icons.assignment_rounded,   label: 'Demandes',        color: const Color(0xFFFFB347), onTap: () {}),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: items.map((item) => GestureDetector(
        onTap: item.onTap,
        child: Card(
          elevation: 0,
          color: item.color.withOpacity(0.1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(item.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800])),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

// Data class for a quick-access card
class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickItem({required this.icon, required this.label,
      required this.color, required this.onTap});
}

// Streams recent activities from Firestore and renders them
class _ActivityList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final ({IconData icon, Color color}) Function(String) activityStyle;
  final String Function(Timestamp) timeAgo;

  const _ActivityList({
    required this.stream,
    required this.activityStyle,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('Aucune activité récente.',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          );
        }

        return Column(
          children: docs.map((doc) {
            final d = doc.data();
            final style = activityStyle(d['type'] ?? '');
            final ts = d['createdAt'] as Timestamp?;
            final sub = [
              if (d['senderName'] != null) d['senderName'] as String,
              if (ts != null) timeAgo(ts),
            ].join(' · ');

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                title: Text(d['title'] ?? 'Notification',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(sub,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                trailing:
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Fixed bottom navigation bar
class _BottomNav extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onSetup;
  const _BottomNav({required this.onProfile, required this.onSetup});

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (i) {
        if (i == 1) onProfile();
        if (i == 2) onSetup();
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _pink,
      unselectedItemColor: Colors.grey[400],
      backgroundColor: Colors.white,
      elevation: 12,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded),           label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded),         label: 'Profil'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded),    label: 'Messages'),
      ],
    );
  }
}
