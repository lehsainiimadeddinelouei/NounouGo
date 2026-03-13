import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nounou_profile_screen.dart';
import 'babysitter_setup_screen.dart';

class BabysitterHomeScreen extends StatefulWidget {
  const BabysitterHomeScreen({super.key});

  @override
  State<BabysitterHomeScreen> createState() => _BabysitterHomeScreenState();
}

class _BabysitterHomeScreenState extends State<BabysitterHomeScreen> {
  int _selectedIndex = 0;

  final Color primaryColor = const Color(0xFFFF6B8A);
  final Color bgColor = const Color(0xFFFFF8F9);

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get _currentUser => _auth.currentUser;

  // ── Firestore: babysitter profile doc ──────────────────────────────────────
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _profileStream =>
      _firestore
          .collection('babysitters')
          .doc(_currentUser!.uid)
          .snapshots();

  // ── Firestore: recent activities for this user ─────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> get _activitiesStream =>
      _firestore
          .collection('babysitters')
          .doc(_currentUser!.uid)
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();

  // ── Helper: first name only ────────────────────────────────────────────────
  String _firstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'Nounou';
    return fullName.trim().split(' ').first;
  }

  // ── Helper: activity icon & color from type string ─────────────────────────
  Map<String, dynamic> _activityStyle(String type) {
    switch (type) {
      case 'request':
        return {'icon': Icons.assignment_rounded, 'color': const Color(0xFFFFB347)};
      case 'message':
        return {'icon': Icons.chat_bubble_rounded, 'color': const Color(0xFF43C59E)};
      case 'review':
        return {'icon': Icons.star_rounded, 'color': const Color(0xFF7C83FD)};
      default:
        return {'icon': Icons.notifications_rounded, 'color': const Color(0xFFFF6B8A)};
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, profileSnap) {
        final profileData = profileSnap.data?.data() ?? {};
        final String fullName =
            profileData['fullName'] ?? _currentUser?.displayName ?? '';
        final String photoUrl =
            profileData['photoUrl'] ?? _currentUser?.photoURL ?? '';
        final bool isAvailable = profileData['isAvailable'] ?? false;

        return Scaffold(
          backgroundColor: bgColor,
          bottomNavigationBar: _buildBottomNav(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(fullName, photoUrl),
                  const SizedBox(height: 24),
                  _buildStatusCard(isAvailable),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Accès rapide'),
                  const SizedBox(height: 16),
                  _buildQuickAccessGrid(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Activité récente'),
                  const SizedBox(height: 12),
                  _buildActivityList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(String fullName, String photoUrl) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: primaryColor.withOpacity(0.2),
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, ${_firstName(fullName)} 👋',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[850]),
              ),
              const SizedBox(height: 2),
              Text('Bienvenue sur Nounou',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
        Stack(
          children: [
            // Notification bell — badge count from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('babysitters')
                  .doc(_currentUser!.uid)
                  .collection('activities')
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snap) {
                final unread = snap.data?.docs.length ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                          color: Colors.grey[700]),
                      onPressed: () {},
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Status hero card ───────────────────────────────────────────────────────
  Widget _buildStatusCard(bool isAvailable) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statut actuel',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  isAvailable ? 'Disponible ✓' : 'Non disponible',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BabysitterSetupScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Gérer disponibilités',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Icon(Icons.child_care_rounded,
              color: Colors.white30, size: 72),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800]),
      );

  // ── Quick access grid ──────────────────────────────────────────────────────
  Widget _buildQuickAccessGrid() {
    final items = [
      _QuickItem(
          icon: Icons.person_rounded,
          label: 'Mon Profil',
          color: const Color(0xFFFF6B8A),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NounouProfileScreen()))),
      _QuickItem(
          icon: Icons.calendar_month_rounded,
          label: 'Disponibilités',
          color: const Color(0xFF7C83FD),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BabysitterSetupScreen()))),
      _QuickItem(
          icon: Icons.chat_bubble_rounded,
          label: 'Messages',
          color: const Color(0xFF43C59E),
          onTap: () {}),
      _QuickItem(
          icon: Icons.assignment_rounded,
          label: 'Demandes',
          color: const Color(0xFFFFB347),
          onTap: () {}),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: items.map(_buildQuickCard).toList(),
    );
  }

  Widget _buildQuickCard(_QuickItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: item.color.withOpacity(0.1),
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
    );
  }

  // ── Activity list from Firestore ───────────────────────────────────────────
  Widget _buildActivityList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activitiesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucune activité récente.',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final style = _activityStyle(data['type'] ?? '');
            final Timestamp? ts = data['createdAt'] as Timestamp?;
            final String timeAgo = ts != null ? _timeAgo(ts.toDate()) : '';

            return _buildActivityCard(
              icon: style['icon'] as IconData,
              color: style['color'] as Color,
              title: data['title'] ?? 'Notification',
              subtitle:
                  '${data['senderName'] ?? ''} • $timeAgo'.trim().replaceAll(RegExp(r'^•\s*'), ''),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) {
        setState(() => _selectedIndex = i);
        if (i == 1) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NounouProfileScreen()));
        } else if (i == 2) {
          Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const BabysitterSetupScreen()));
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey[400],
      backgroundColor: Colors.white,
      elevation: 12,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Accueil'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded), label: 'Profil'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded), label: 'Planning'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
      ],
    );
  }

  // ── Time-ago helper ────────────────────────────────────────────────────────
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}
