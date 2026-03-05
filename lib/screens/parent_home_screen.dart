import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'search_nounous_screen.dart';
import 'parent_profile_screen.dart';
import 'demandes_screen.dart';
import 'conversations_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'historique_screen.dart';
import 'notifications_screen.dart';
import 'evaluation_screen.dart';

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0)),
              _NavItem(icon: Icons.search_rounded, label: 'Recherche', selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1)),
              // Badge demandes en attente
              _NavItemWithBadge(
                icon: Icons.calendar_month_rounded, label: 'RDV', selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
                uid: uid ?? '', fieldKey: 'demandes',
              ),
              _NavItemWithBadge(
                icon: Icons.chat_bubble_outline_rounded, label: 'Messages', selected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
                uid: uid ?? '', fieldKey: 'conversations',
              ),
              _NavItem(icon: Icons.person_rounded, label: 'Profil', selected: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Badge sur les onglets ──
class _NavItemWithBadge extends StatelessWidget {
  final IconData icon; final String label; final bool selected;
  final VoidCallback onTap; final String uid; final String fieldKey;
  const _NavItemWithBadge({required this.icon, required this.label, required this.selected,
    required this.onTap, required this.uid, required this.fieldKey});

  Stream<int> get _countStream {
    if (fieldKey == 'conversations') {
      return FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .snapshots()
          .map((snap) => snap.docs.fold<int>(0, (sum, doc) {
            final data = doc.data();
            return sum + ((data['unread_$uid'] ?? 0) as int);
          }));
    }
    return FirebaseFirestore.instance
        .collection('demandes')
        .where('parentUid', isEqualTo: uid)
        .where('statut', isEqualTo: 'en_attente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPink.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? AppColors.primaryPink : AppColors.textGrey, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryPink : AppColors.textGrey)),
        ]),
      ),
      StreamBuilder<int>(
        stream: _countStream,
        builder: (_, snap) {
          final count = snap.data ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Positioned(top: 0, right: 0,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
              child: Center(child: Text('$count',
                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))));
        },
      ),
    ]),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.buttonBlue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: selected ? AppColors.buttonBlue : AppColors.textGrey, size: 24),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? AppColors.buttonBlue : AppColors.textGrey)),
      ]),
    ),
  );
}

// ── Onglet Accueil ──
class _HomeTab extends StatelessWidget {
  const _HomeTab();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bonjour 👋', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (_, snap) {
                    final prenom = snap.data?.get('prenom') ?? '';
                    return Text(prenom.isNotEmpty ? prenom : 'Parent',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark));
                  },
                ),
              ]),
              // Cloche notif
              _NotifBell(uid: uid ?? ''),
            ]),
            const SizedBox(height: 28),

            // Carte recherche
            GestureDetector(
              onTap: () {
                final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
                s?.setState(() => s._currentIndex = 1);
              },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryPink, Color(0xFFFF8FAB)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.primaryPink.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Trouvez une nounou', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('Recherchez parmi nos babysitters qualifiées près de chez vous',
                        style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Rechercher →',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryPink)),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  const Text('👩‍👧', style: TextStyle(fontSize: 48)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Dernières demandes
            _LastDemandesWidget(uid: uid ?? '', onViewAll: () {
              final s = context.findAncestorStateOfType<_ParentHomeScreenState>();
              s?.setState(() => s._currentIndex = 2);
            }),

            // ── Paiements en attente ──
            _PendingPaymentsWidget(uid: uid ?? ''),

            const SizedBox(height: 24),
            const Text('Accès rapide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _QuickCard(icon: Icons.search_rounded, label: 'Chercher', color: AppColors.buttonBlue,
                  onTap: () { final s = context.findAncestorStateOfType<_ParentHomeScreenState>(); s?.setState(() => s._currentIndex = 1); })),
              const SizedBox(width: 12),
              Expanded(child: _QuickCard(icon: Icons.calendar_month_rounded, label: 'Mes RDV', color: AppColors.primaryPink,
                  onTap: () { final s = context.findAncestorStateOfType<_ParentHomeScreenState>(); s?.setState(() => s._currentIndex = 2); })),
              const SizedBox(width: 12),
              Expanded(child: _QuickCard(icon: Icons.payment_rounded, label: 'Paiements', color: AppColors.buttonBlue,
                  onTap: () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const HistoriquePaiementsScreen(role: 'Parent'),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  )))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _QuickCard(icon: Icons.history_rounded, label: 'Historique', color: Colors.purple,
                  onTap: () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const HistoriqueScreen(role: 'Parent'),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  )))),
              const SizedBox(width: 12),
              Expanded(child: _QuickCard(icon: Icons.star_rounded, label: 'Mes avis', color: Colors.amber,
                  onTap: () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const HistoriqueScreen(role: 'Parent'),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  )))),
              const SizedBox(width: 12),
              Expanded(child: _QuickCard(icon: Icons.person_rounded, label: 'Profil', color: Colors.teal,
                  onTap: () { final s = context.findAncestorStateOfType<_ParentHomeScreenState>(); s?.setState(() => s._currentIndex = 4); })),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Cloche notifications ──
class _NotifBell extends StatelessWidget {
  final String uid;
  const _NotifBell({required this.uid});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('notifications')
        .where('destinataireUid', isEqualTo: uid).where('lu', isEqualTo: false).snapshots(),
    builder: (_, snap) {
      final count = snap.data?.docs.length ?? 0;
      return GestureDetector(
        onTap: () => Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NotificationsScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        )),
        child: Stack(clipBehavior: Clip.none, children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)]),
          child: const Icon(Icons.notifications_outlined, color: AppColors.textDark)),
        if (count > 0) Positioned(top: 0, right: 0,
          child: Container(width: 18, height: 18,
            decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
            child: Center(child: Text('$count',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))))),
      ]),
      );
    },
  );
}

// ── Widget dernières demandes sur l'accueil ──
class _LastDemandesWidget extends StatelessWidget {
  final String uid; final VoidCallback onViewAll;
  const _LastDemandesWidget({required this.uid, required this.onViewAll});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('demandes')
        .where('parentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(2)
        .snapshots(),
    builder: (_, snap) {
      if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
      final docs = snap.data!.docs;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Mes dernières demandes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          GestureDetector(onTap: onViewAll,
              child: const Text('Voir tout', style: TextStyle(fontSize: 13, color: AppColors.primaryPink, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        ...docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final statut = data['statut'] ?? 'en_attente';
          final nounouNom = '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}';
          final ts = data['dateTime'] as Timestamp?;
          final dt = ts?.toDate();
          const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
          final dateStr = dt != null ? '${dt.day} ${mois[dt.month - 1]} à ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}' : '';
          final color = statut == 'acceptée' ? Colors.green : statut == 'refusée' ? Colors.red : Colors.orange;
          final icon = statut == 'acceptée' ? Icons.check_circle_rounded : statut == 'refusée' ? Icons.cancel_rounded : Icons.schedule_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nounouNom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(statut == 'acceptée' ? 'Acceptée' : statut == 'refusée' ? 'Refusée' : 'En attente',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
            ]),
          );
        }),
      ]);
    },
  );
}

// ── Widget paiements en attente sur l'accueil ──
class _PendingPaymentsWidget extends StatelessWidget {
  final String uid;
  const _PendingPaymentsWidget({required this.uid});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('demandes')
        .where('parentUid', isEqualTo: uid)
        .where('statut', isEqualTo: 'acceptée')
        .snapshots(),
    builder: (_, snap) {
      // Filtrer celles sans paiement
      final docs = (snap.data?.docs ?? []).where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['paiementStatut'] == null;
      }).toList();

      if (docs.isEmpty) return const SizedBox.shrink();

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        Row(children: [
          const Text('Paiements en attente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.buttonBlue, borderRadius: BorderRadius.circular(20)),
            child: Text('${docs.length}',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 12),
        ...docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          final nounouNom = '${data['nounouPrenom'] ?? ''} ${data['nounouNom'] ?? ''}';
          final duree = data['dureeHeures'] ?? 1;
          final prix = (data['prixHeure'] ?? 0).toDouble();
          final montant = prix * duree;
          return GestureDetector(
            onTap: () => Navigator.push(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => PaymentScreen(demandeData: data, demandeId: doc.id),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 350),
            )),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A90D9), AppColors.buttonBlue]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.buttonBlue.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.payment_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Payer $nounouNom',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('$duree h · ${montant > 0 ? "${montant.toInt()} DA" : "Voir détails"}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Payer →',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.buttonBlue)),
                ),
              ]),
            ),
          );
        }),
      ]);
    },
  );
}


class _QuickCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}
