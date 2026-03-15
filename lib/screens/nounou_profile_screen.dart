import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'babysitter_edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────
// SCREEN — Displays the babysitter's public-facing profile
// ─────────────────────────────────────────────────────────────
class NounouProfileScreen extends StatelessWidget {
  const NounouProfileScreen({super.key});

  static const _pink = Color(0xFFFF6B8A);

  // FIX 3: Use getter instead of static final so the uid is re-read on each
  // access — static final is computed once and can become stale after logout.
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      FirebaseFirestore.instance.collection('babysitters').doc(_uid);

  // Last 5 reviews ordered by most recent
  Query<Map<String, dynamic>> get _reviewsRef => _profileRef
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .limit(5);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileRef.snapshots(),
      builder: (context, snap) {

        // Show a full-screen loader while waiting for the first snapshot
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Read every field with a safe fallback value
        final d           = snap.data?.data() ?? {};
        final fullName    = d['fullName']      ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Nounou';
        final photoUrl    = d['photoUrl']      ?? FirebaseAuth.instance.currentUser?.photoURL    ?? '';
        final description = d['description']  ?? 'Aucune description.';
        final experience  = d['experience']   ?? '-';
        final rating      = (d['averageRating'] ?? 0.0).toDouble();
        final reviewCount = d['reviewCount']  ?? 0;
        final location    = d['location']     ?? '';
        final skills      = List<String>.from(d['skills'] ?? []);
        final verified    = d['verified']     ?? false;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F9),
          body: CustomScrollView(
            slivers: [

              // ── Collapsible pink header with photo ─────────
              _ProfileAppBar(
                fullName:    fullName,
                photoUrl:    photoUrl,
                location:    location,
                description: description,
                experience:  experience,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── 3 stat chips: experience, reviews, rating ──
                      _StatsRow(
                          experience:  experience,
                          reviewCount: reviewCount,
                          rating:      rating),
                      const SizedBox(height: 20),

                      // ── Verified badge — shown only when verified == true ──
                      if (verified) ...[
                        _VerifiedCard(),
                        const SizedBox(height: 16),
                      ],

                      // ── About me ───────────────────────────
                      _InfoCard(
                        icon: Icons.info_outline_rounded,
                        title: 'À propos de moi',
                        child: Text(description,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.6)),
                      ),
                      const SizedBox(height: 16),

                      // ── Experience chip ────────────────────
                      _InfoCard(
                        icon: Icons.work_outline_rounded,
                        title: 'Expérience',
                        child: Chip(
                          avatar: Icon(Icons.work_rounded, color: _pink, size: 16),
                          label: Text("$experience d'expérience"),
                          backgroundColor: _pink.withOpacity(0.1),
                          labelStyle: TextStyle(
                              color: _pink, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Skills list ────────────────────────
                      _InfoCard(
                        icon: Icons.star_outline_rounded,
                        title: 'Compétences',
                        child: skills.isEmpty
                            ? Text('Aucune compétence renseignée.',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13))
                            : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills
                              .map((s) => _SkillChip(label: s))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Parent reviews from Firestore ──────
                      _InfoCard(
                        icon: Icons.reviews_outlined,
                        title: 'Avis des parents',
                        child: _ReviewsList(stream: _reviewsRef.snapshots()),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────

// Collapsible SliverAppBar — pink background with avatar, name, location
class _ProfileAppBar extends StatelessWidget {
  final String fullName, photoUrl, location, description, experience;
  const _ProfileAppBar({
    required this.fullName,
    required this.photoUrl,
    required this.location,
    required this.description,
    required this.experience,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _pink,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // Edit button in the top-right corner
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BabysitterEditProfileScreen(
                name:        fullName,
                description: description,
                experience:  experience,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _pink,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // FIX 4: Wrapped avatar in GestureDetector so tapping the photo
              // opens the edit screen — the camera icon was decorative before.
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BabysitterEditProfileScreen(
                      name:        fullName,
                      description: description,
                      experience:  experience,
                    ),
                  ),
                ),
                child: Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: _pink.withOpacity(0.2),
                      backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                          : null,
                    ),
                  ),
                  // Camera badge — now actually tappable (see GestureDetector above)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: _pink,
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Display name
              Text(fullName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              // Location row — hidden when location is empty
              if (location.isNotEmpty)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on_rounded,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(location,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

// Row of three stat cards: experience / review count / average rating
class _StatsRow extends StatelessWidget {
  final String experience;
  final int reviewCount;
  final double rating;
  const _StatsRow({
    required this.experience,
    required this.reviewCount,
    required this.rating,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Expérience', value: experience),
      (label: 'Avis',       value: reviewCount.toString()),
      (label: 'Note',       value: '${rating.toStringAsFixed(1)} ⭐'),
    ];

    return Row(
      children: items.map((item) => Expanded(
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(item.value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _pink)),
              const SizedBox(height: 4),
              Text(item.label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
        ),
      )).toList(),
    );
  }
}

// Generic card with icon header + divider + any child widget
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header row: icon + title
            Row(children: [
              Icon(icon, color: _pink, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// Purple pill chip used for skills
class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C83FD).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF7C83FD),
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }
}

// Gold verified-identity badge card
class _VerifiedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_rounded,
                color: Color(0xFFFFB347), size: 28),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Profil vérifié',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Votre identité a été confirmée',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// Streams and renders the list of parent reviews
class _ReviewsList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  const _ReviewsList({required this.stream});

  static const _pink = Color(0xFFFF6B8A);

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
          return Text('Aucun avis pour le moment.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13));
        }

        return Column(
          children: docs.map((doc) {
            final d       = doc.data();
            final name    = d['reviewerName'] ?? 'Anonyme';
            final comment = d['comment']      ?? '';
            final rating  = (d['rating']      ?? 5).toInt().clamp(1, 5);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reviewer avatar with first-letter initials
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _pink.withOpacity(0.2),
                    child: Text(name[0].toUpperCase(),
                        style: TextStyle(
                            color: _pink,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            // Star rating — one icon per point
                            Row(
                              children: List.generate(
                                rating,
                                    (_) => const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFB347), size: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(comment,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
