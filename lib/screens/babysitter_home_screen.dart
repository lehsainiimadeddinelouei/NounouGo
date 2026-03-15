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

  // ── Theme colors ───────────────────────────────────────────
  static const _pink   = Color(0xFFFF6B8A);
  static const _bg     = Color(0xFFFFF8F9);
  static const _teal   = Color(0xFF43C59E);
  static const _purple = Color(0xFF7C83FD);
  static const _amber  = Color(0xFFFFB347);

  // ── Firebase references ────────────────────────────────────
  final _user = FirebaseAuth.instance.currentUser!;

  late final _profileRef = FirebaseFirestore.instance
      .collection('babysitters')
      .doc(_user.uid);

  // Last 5 activities ordered by creation date
  late final _activitiesRef = _profileRef
      .collection('activities')
      .orderBy('createdAt', descending: true)
      .limit(5);

  // ── Helper methods ─────────────────────────────────────────

  // Returns first name only — e.g. "Amina Bouhired" → "Amina"
  String _firstName(String? full) =>
      (full ?? 'Nounou').trim().split(' ').first;

  // Human-readable relative time — e.g. "Il y a 5min"
  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays    == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }

  // Maps an activity type string to an icon + color pair
  ({IconData icon, Color color}) _activityStyle(String type) => switch (type) {
    'request' => (icon: Icons.assignment_rounded,    color: _amber),
    'message' => (icon: Icons.chat_bubble_rounded,   color: _teal),
    'review'  => (icon: Icons.star_rounded,          color: _purple),
    _         => (icon: Icons.notifications_rounded,  color: _pink),
  };

  // ── Navigation helpers ─────────────────────────────────────
  void _goTo(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // FIX 1: Dedicated method for Messages screen.
  // Replace the SnackBar with _goTo(MessagesScreen()) once that screen exists.
  void _goToMessages() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bientôt disponible : écran Messages'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FIX 1: Dedicated method for Requests screen — placeholder for now.
  void _goToRequests() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bientôt disponible : écran Demandes'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FIX 2: Dedicated method for Notifications screen — placeholder for now.
  void _goToNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bientôt disponible : écran Notifications'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Real-time listener on the babysitter profile document
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileRef.snapshots(),
      builder: (context, snap) {
        final data        = snap.data?.data() ?? {};
        final fullName    = data['fullName']    ?? _user.displayName ?? '';
        final photoUrl    = data['photoUrl']    ?? _user.photoURL    ?? '';
        final isAvailable = data['isAvailable'] ?? false;

        return Scaffold(
          backgroundColor: _bg,
          // FIX 1: onMessages is now wired — was missing before
          bottomNavigationBar: _BottomNav(
            onProfile:  () => _goTo(const NounouProfileScreen()),
            onSetup:    () => _goTo(const BabysitterSetupScreen()),
            onMessages: _goToMessages,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Top row: avatar + greeting + bell ─────
                  _Header(
                    fullName:  fullName,
                    photoUrl:  photoUrl,
                    firstName: _firstName(fullName),
                    // FIX 2: Bell now opens a screen instead of doing nothing
                    onNotificationTap: _goToNotifications,
                    unreadStream: _profileRef
                        .collection('activities')
                        .where('read', isEqualTo: false)
                        .snapshots()
                        .map((s) => s.docs.length),
                  ),
                  const SizedBox(height: 24),

                  // ── Availability hero card ─────────────────
                  _HeroCard(
                    isAvailable: isAvailable,
                    onManage: () => _goTo(const BabysitterSetupScreen()),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick-access 2×2 grid ──────────────────
                  _SectionLabel(text: 'Accès rapide'),
                  const SizedBox(height: 16),
                  // FIX 1: All four grid buttons now have real callbacks
                  _QuickGrid(
                    onProfile:        () => _goTo(const NounouProfileScreen()),
                    onAvailabilities: () => _goTo(const BabysitterSetupScreen()),
                    onMessages:       _goToMessages,
                    onRequests:       _goToRequests,
                  ),
                  const SizedBox(height: 24),

                  // ── Recent activity feed from Firestore ────
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
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────

// Simple bold section title
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

// Top row: avatar + greeting text + notification bell with unread badge
class _Header extends StatelessWidget {
  final String fullName;
  final String photoUrl;
  final String firstName;
  final Stream<int> unreadStream;
  final VoidCallback onNotificationTap; // FIX 2: added callback

  const _Header({
    required this.fullName,
    required this.photoUrl,
    required this.firstName,
    required this.unreadStream,
    required this.onNotificationTap,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Profile avatar — shows photo or first-letter initials as fallback
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

      // Greeting column
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

      // FIX 2: Notification bell now calls onNotificationTap — was () {} before
      StreamBuilder<int>(
        stream: unreadStream,
        builder: (_, snap) => Stack(children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
            onPressed: onNotificationTap,
          ),
          // Small red dot shown when there are unread notifications
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

// Pink card showing current availability + manage button
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

// FIX 1: Added onMessages and onRequests — both were completely missing before
class _QuickGrid extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onAvailabilities;
  final VoidCallback onMessages; // new
  final VoidCallback onRequests; // new

  const _QuickGrid({
    required this.onProfile,
    required this.onAvailabilities,
    required this.onMessages,
    required this.onRequests,
  });

  @override
  Widget build(BuildContext context) {
    // All four cards now have real callbacks instead of empty () {}
    final items = [
      _QuickItem(icon: Icons.person_rounded,         label: 'Mon Profil',     color: const Color(0xFFFF6B8A), onTap: onProfile),
      _QuickItem(icon: Icons.calendar_month_rounded, label: 'Disponibilités', color: const Color(0xFF7C83FD), onTap: onAvailabilities),
      _QuickItem(icon: Icons.chat_bubble_rounded,    label: 'Messages',       color: const Color(0xFF43C59E), onTap: onMessages),
      _QuickItem(icon: Icons.assignment_rounded,     label: 'Demandes',       color: const Color(0xFFFFB347), onTap: onRequests),
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

// Simple data class for one quick-access card
class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// Streams recent activity documents from Firestore and renders one card per item
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
  final d     = doc.data();
  final style = activityStyle(d['type'] ?? '');
  final ts    = d['createdAt'] as Timestamp?;

  // Subtitle: "senderName · time ago"
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

// FIX 1: Added onMessages parameter + handled index 3 in onTap (was missing)
class _BottomNav extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onSetup;
  final VoidCallback onMessages; // new

  const _BottomNav({
    required this.onProfile,
    required this.onSetup,
    required this.onMessages,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (i) {
        if (i == 1) onProfile();
        if (i == 2) onSetup();
        if (i == 3) onMessages(); // FIX 1: index 3 was never handled before
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
