import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════
// Point d'entrée: AdminScreen
// Accessible uniquement si role == 'admin' dans Firestore
// ════════════════════════════════════════════════
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(child: Column(children: [

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryPink, Color(0xFFE05C7A)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NounouGo Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Tableau de bord', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ]),
              const Spacer(),
              _NotifBadge(),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Tabs ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Expanded(child: _TabBtn(label: '📊', index: 0, current: _tab, onTap: (i) => setState(() => _tab = i))),
                Expanded(child: _TabBtn(label: '📄 Docs', index: 1, current: _tab, onTap: (i) => setState(() => _tab = i))),
                Expanded(child: _TabBtn(label: '👥 Users', index: 2, current: _tab, onTap: (i) => setState(() => _tab = i))),
                Expanded(child: _TabBtn(label: '🗑️ Supp.', index: 3, current: _tab, onTap: (i) => setState(() => _tab = i))),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // ── Contenu ──
          Expanded(child: IndexedStack(index: _tab, children: [
            const _StatsTab(),
            const _DocumentsTab(),
            const _UsersTab(),
            const _DeletedAccountsTab(),
          ])),
        ])),
      ),
    );
  }
}

// ── Tab button ──
class _TabBtn extends StatelessWidget {
  final String label; final int index, current; final Function(int) onTap;
  const _TabBtn({required this.label, required this.index, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPink : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.white54)),
      ),
    );
  }
}

// ── Notif badge documents en attente ──
class _NotifBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'Babysitter').snapshots(),
      builder: (_, snap) {
        int count = 0;
        final docs = snap.data?.docs ?? [];
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['diplomePdfStatut'] == 'en_attente' ||
              d['cvStatut'] == 'en_attente' ||
              d['cniStatut'] == 'en_attente') count++;
        }
        return GestureDetector(
          onTap: () => _showNotifSheet(context, docs),
          child: Stack(children: [
            Container(width: 42, height: 42,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20)),
            if (count > 0) Positioned(top: 4, right: 4,
                child: Container(width: 16, height: 16,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Center(child: Text('$count',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800))))),
          ]),
        );
      },
    );
  }

  void _showNotifSheet(BuildContext context, List<QueryDocumentSnapshot> docs) {
    // Construire la liste des notifications (docs en attente)
    final pending = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final prenom = d['prenom'] ?? '';
      final nom = d['nom'] ?? '';
      if (d['diplomePdfStatut'] == 'en_attente') {
        pending.add({'nom': '$prenom $nom', 'type': 'Diplome', 'icon': Icons.school_rounded, 'color': AppColors.primaryPink});
      }
      if (d['cvStatut'] == 'en_attente') {
        pending.add({'nom': '$prenom $nom', 'type': 'CV', 'icon': Icons.description_rounded, 'color': AppColors.buttonBlue});
      }
      if (d['cniStatut'] == 'en_attente') {
        pending.add({'nom': '$prenom $nom', "type": "Carte d'identite", 'icon': Icons.badge_rounded, 'color': Colors.teal});
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              const Icon(Icons.notifications_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 10),
              const Text('Documents en attente',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('${pending.length}',
                    style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Liste
          Expanded(
            child: pending.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text('Tout est a jour !',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              SizedBox(height: 6),
              Text('Aucun document en attente',
                  style: TextStyle(fontSize: 13, color: Colors.white38)),
            ]))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (_, i) {
                final n = pending[i];
                final color = n['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Container(width: 42, height: 42,
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(n['icon'] as IconData, color: color, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['nom'] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('${n['type']} en attente de verification',
                          style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Text('En attente',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                );
              },
            ),
          ),
          // Bouton fermer
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text('Fermer', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// ONGLET 1 — STATISTIQUES
// ════════════════════════════════════════════════
class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Cartes stats en temps réel
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (_, snap) {
            final users = snap.data?.docs ?? [];
            final parents = users.where((d) => (d.data() as Map)['role'] == 'Parent').length;
            final nounous = users.where((d) => (d.data() as Map)['role'] == 'Babysitter').length;
            return Column(children: [
              Row(children: [
                Expanded(child: _StatCard(label: 'Parents', value: '$parents',
                    icon: Icons.family_restroom_rounded, color: AppColors.buttonBlue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Nounous', value: '$nounous',
                    icon: Icons.child_care_rounded, color: AppColors.primaryPink)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(label: 'Total users', value: '${users.length}',
                    icon: Icons.people_rounded, color: Colors.teal)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Actifs', value: '${users.length}',
                    icon: Icons.verified_rounded, color: Colors.green)),
              ]),
            ]);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('demandes').snapshots(),
          builder: (_, snap) {
            final all = snap.data?.docs ?? [];
            final enAttente = all.where((d) => (d.data() as Map)['statut'] == 'en_attente').length;
            final acceptees = all.where((d) => (d.data() as Map)['statut'] == 'acceptée').length;
            return Row(children: [
              Expanded(child: _StatCard(label: 'Total RDV', value: '${all.length}',
                  icon: Icons.calendar_month_rounded, color: Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'En attente', value: '$enAttente',
                  icon: Icons.hourglass_empty_rounded, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Acceptés', value: '$acceptees',
                  icon: Icons.check_circle_rounded, color: Colors.green)),
            ]);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('paiements').snapshots(),
          builder: (_, snap) {
            final paiements = snap.data?.docs ?? [];
            double total = 0;
            for (final p in paiements) {
              total += ((p.data() as Map)['montantTotal'] ?? 0).toDouble();
            }
            return Row(children: [
              Expanded(child: _StatCard(label: 'Paiements', value: '${paiements.length}',
                  icon: Icons.payments_rounded, color: Colors.amber)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Total DA', value: '${total.toInt()}',
                  icon: Icons.account_balance_wallet_rounded, color: Colors.teal)),
            ]);
          },
        ),
        const SizedBox(height: 20),

        // Derniers utilisateurs inscrits
        const Text('Dernières inscriptions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .orderBy('createdAt', descending: true).limit(5).snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            return Column(children: snap.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return _UserMiniCard(data: d, uid: doc.id);
            }).toList());
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _UserMiniCard extends StatelessWidget {
  final Map<String, dynamic> data; final String uid;
  const _UserMiniCard({required this.data, required this.uid});
  @override
  Widget build(BuildContext context) {
    final role = data['role'] ?? '';
    final color = role == 'Babysitter' ? AppColors.primaryPink : AppColors.buttonBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Center(child: Text(
              '${(data['prenom'] ?? ' ')[0]}${(data['nom'] ?? ' ')[0]}'.toUpperCase(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(data['email'] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.white38), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text(role, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
// ONGLET 2 — DOCUMENTS (avec IA)
// ════════════════════════════════════════════════
class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'Babysitter').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));

        // Filtrer nounous avec au moins un doc en attente
        final docsEnAttente = snap.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['diplomePdfStatut'] == 'en_attente' ||
              d['cvStatut'] == 'en_attente' ||
              d['cniStatut'] == 'en_attente';
        }).toList();

        if (docsEnAttente.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
            const SizedBox(height: 16),
            const Text('Tout est vérifié !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Aucun document en attente de vérification',
                style: TextStyle(fontSize: 13, color: Colors.white54)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docsEnAttente.length,
          itemBuilder: (_, i) {
            final doc = docsEnAttente[i];
            final d = doc.data() as Map<String, dynamic>;
            return _NounouDocCard(uid: doc.id, data: d);
          },
        );
      },
    );
  }
}

class _NounouDocCard extends StatefulWidget {
  final String uid; final Map<String, dynamic> data;
  const _NounouDocCard({required this.uid, required this.data});
  @override
  State<_NounouDocCard> createState() => _NounouDocCardState();
}

class _NounouDocCardState extends State<_NounouDocCard> {
  bool _expanded = false;
  String _aiAnalysis = '';
  bool _aiLoading = false;

  Future<void> _analyzeWithAI(String docType, String base64Data, String fileName) async {
    setState(() { _aiLoading = true; _aiAnalysis = ''; });
    try {
      final http = await _callClaudeAPI(docType, base64Data, fileName, widget.data);
      setState(() => _aiAnalysis = http);
    } catch (e) {
      setState(() => _aiAnalysis = 'Erreur analyse: $e');
    }
    setState(() => _aiLoading = false);
  }

  Future<String> _callClaudeAPI(String docType, String base64Data, String fileName,
      Map<String, dynamic> userData) async {
    final prenom = userData['prenom'] ?? '';
    final nom = userData['nom'] ?? '';
    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');
    final mimeType = isImage ? 'image/jpeg' : 'application/pdf';
    final prompt = _buildPrompt(docType, prenom, nom);

    try {
      final uri = Uri.parse('https://api.anthropic.com/v1/messages');
      final bodyMap = <String, dynamic>{
        'model': 'claude-sonnet-4-6',
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content': isImage
                ? [
              {'type': 'image', 'source': {'type': 'base64', 'media_type': mimeType, 'data': base64Data}},
              {'type': 'text', 'text': prompt},
            ]
                : [
              {'type': 'text', 'text': prompt},
            ],
          }
        ],
      };
      return await _postHttp(uri, bodyMap);
    } catch (e) {
      return '{"valide": false, "confiance": 0, "recommandation": "Vérification manuelle", "motif": "Erreur: $e"}';
    }
  }

  String _buildPrompt(String docType, String prenom, String nom) {
    switch (docType) {
      case 'diplome':
        return '''Analyse ce document comme assistant de vérification pour NounouGo.
Profil: $prenom $nom (babysitter)
Type attendu: Diplôme (CAP Petite Enfance, Licence, etc.)

Vérifie:
1. Est-ce bien un diplôme/certificat officiel ?
2. Le nom sur le document correspond-il à $prenom $nom ?
3. Le diplôme est-il pertinent pour la garde d'enfants ?
4. Y a-t-il des signes de falsification ?

Réponds en JSON: {"valide": true/false, "confiance": 0-100, "type_doc": "...", "nom_detecte": "...", "recommandation": "Valider/Refuser/Vérification manuelle", "motif": "..."}''';
      case 'cv':
        return '''Analyse ce CV pour NounouGo.
Profil: $prenom $nom (babysitter)

Vérifie:
1. Est-ce bien un CV professionnel ?
2. Y a-t-il une expérience en garde d'enfants ?
3. Le document semble-t-il authentique ?

Réponds en JSON: {"valide": true/false, "confiance": 0-100, "experience_enfants": true/false, "recommandation": "Valider/Refuser/Vérification manuelle", "motif": "..."}''';
      default: // cni
        return '''Analyse cette pièce d'identité pour NounouGo.
Profil attendu: $prenom $nom

Vérifie:
1. Est-ce bien une pièce d'identité officielle (CNI, passeport) ?
2. Le nom correspond-il à $prenom $nom ?
3. Le document est-il lisible et non expiré (si visible) ?
4. Y a-t-il des signes de falsification ?

Réponds en JSON: {"valide": true/false, "confiance": 0-100, "type_doc": "CNI/Passeport/Autre", "nom_detecte": "...", "recommandation": "Valider/Refuser/Vérification manuelle", "motif": "..."}''';
    }
  }

  Future<String> _postHttp(Uri uri, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('content-type', 'application/json');
      request.headers.set('x-api-key', '');
      request.headers.set('anthropic-version', '2023-06-01');
      request.write(jsonEncode(body));
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      final responseContent = decoded['content'] as List?;
      if (responseContent != null && responseContent.isNotEmpty) {
        return (responseContent[0] as Map)['text'] as String? ?? '';
      }
      return '{"recommandation": "Vérification manuelle", "motif": "Réponse inattendue"}';
    } finally {
      client.close();
    }
  }

  Future<void> _updateDocStatut(String docType, String statut) async {
    final field = docType == 'diplome' ? 'diplomePdfStatut'
        : docType == 'cv' ? 'cvStatut' : 'cniStatut';
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({field: statut});
    // Mettre à jour aussi la sous-collection
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.uid).collection('documents').doc(docType)
          .update({'statut': statut});
    } catch (_) {}

    // Notifier la nounou
    final notifMsg = statut == 'validé'
        ? 'Votre $docType a ete valide ✅'
        : 'Votre $docType a ete refuse. Veuillez soumettre un nouveau document.';
    await FirebaseFirestore.instance.collection('notifications').add({
      'destinataireUid': widget.uid,
      'titre': statut == 'validé' ? 'Document validé ✅' : 'Document refusé ❌',
      'message': notifMsg,
      'type': statut == 'validé' ? 'document_valide' : 'document_refuse',
      'lu': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(statut == 'validé' ? '✅ Document validé' : '❌ Document refusé'),
        backgroundColor: statut == 'validé' ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  List<Map<String, dynamic>> _docs = [];
  bool _docsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final d = widget.data;
    final uid = d['uid'] as String? ?? '';
    final loaded = <Map<String, dynamic>>[];

    // Construire depuis champs principaux (noms + statuts)
    final docsInfo = <Map<String, dynamic>>[];
    if ((d['diplomePdfName'] as String? ?? '').isNotEmpty || (d['diplomePdfBase64'] as String? ?? '').isNotEmpty) {
      docsInfo.add({'type': 'diplome', 'label': 'Diplôme', 'icon': Icons.school_rounded,
        'color': AppColors.primaryPink, 'base64': d['diplomePdfBase64'] ?? '',
        'name': d['diplomePdfName'] ?? 'diplome.pdf', 'statut': d['diplomePdfStatut'] ?? 'en_attente'});
    }
    if ((d['cvName'] as String? ?? '').isNotEmpty || (d['cvBase64'] as String? ?? '').isNotEmpty) {
      docsInfo.add({'type': 'cv', 'label': 'CV', 'icon': Icons.description_rounded,
        'color': AppColors.buttonBlue, 'base64': d['cvBase64'] ?? '',
        'name': d['cvName'] ?? 'cv.pdf', 'statut': d['cvStatut'] ?? 'en_attente'});
    }
    if ((d['cniName'] as String? ?? '').isNotEmpty || (d['cniBase64'] as String? ?? '').isNotEmpty) {
      docsInfo.add({'type': 'cni', 'label': "Carte d'identité", 'icon': Icons.badge_rounded,
        'color': Colors.teal, 'base64': d['cniBase64'] ?? '',
        'name': d['cniName'] ?? 'cni.pdf', 'statut': d['cniStatut'] ?? 'en_attente'});
    }

    if (uid.isNotEmpty) {
      try {
        final subSnap = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('documents').get();
        for (final subDoc in subSnap.docs) {
          final sd = subDoc.data();
          final type = sd['type'] as String? ?? subDoc.id;
          final info = docsInfo.firstWhere((i) => i['type'] == type, orElse: () => {});
          if (info.isEmpty) {
            loaded.add({'type': type,
              'label': type == 'diplome' ? 'Diplôme' : type == 'cv' ? 'CV' : "Carte d'identité",
              'icon': type == 'diplome' ? Icons.school_rounded : type == 'cv' ? Icons.description_rounded : Icons.badge_rounded,
              'color': type == 'diplome' ? AppColors.primaryPink : type == 'cv' ? AppColors.buttonBlue : Colors.teal,
              'base64': sd['base64'] ?? '', 'name': sd['name'] ?? '$type.pdf',
              'statut': sd['statut'] ?? 'en_attente'});
          } else {
            loaded.add({...info, 'base64': sd['base64'] ?? info['base64'] ?? ''});
          }
        }
        // Ajouter les docs anciens comptes (base64 dans doc principal)
        for (final info in docsInfo) {
          if (!loaded.any((x) => x['type'] == info['type'])) {
            if ((info['base64'] as String).isNotEmpty) loaded.add(info);
          }
        }
      } catch (_) {
        // Fallback: champs principaux
        loaded.addAll(docsInfo.where((i) => (i['base64'] as String).isNotEmpty));
      }
    } else {
      loaded.addAll(docsInfo.where((i) => (i['base64'] as String).isNotEmpty));
    }

    if (mounted) setState(() { _docs = loaded; _docsLoaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final uid = d['uid'] as String? ?? '';
    final prenom = d['prenom'] ?? '';
    final nom = d['nom'] ?? '';

    // Docs chargés dans initState/_loadDocs
    final docs = _docs;

    if (!_docsLoaded) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryPink)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primaryPink.withOpacity(0.2), shape: BoxShape.circle),
                  child: Center(child: Text('${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryPink)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$prenom $nom', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                Builder(builder: (ctx) {
                  final enAttente = docs.where((d) => d['statut'] == 'en_attente').length;
                  final total = docs.length;
                  return Text(
                    enAttente > 0 ? '$enAttente doc(s) en attente · $total au total' : '$total doc(s) soumis',
                    style: TextStyle(fontSize: 12, color: enAttente > 0 ? Colors.orange.shade300 : Colors.green.shade300),
                  );
                }),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('⏳ En attente',
                    style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white54, size: 20),
            ]),
          ),
        ),

        // Documents expandable
        if (_expanded) ...[
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              ...docs.map((doc) => _DocReviewCard(
                docInfo: doc,
                userData: d,
                onAnalyze: () => _analyzeWithAI(doc['type'], doc['base64'] ?? '', doc['name']),
                aiLoading: _aiLoading,
                aiResult: _aiAnalysis,
                onValidate: () => _updateDocStatut(doc['type'], 'validé'),
                onRefuse: () => _updateDocStatut(doc['type'], 'refusé'),
              )).toList(),
              const SizedBox(height: 4),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              _ConfirmNounouButton(uid: widget.uid, data: d),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _DocReviewCard extends StatelessWidget {
  final Map<String, dynamic> docInfo, userData;
  final VoidCallback onAnalyze, onValidate, onRefuse;
  final bool aiLoading;
  final String aiResult;

  const _DocReviewCard({
    required this.docInfo, required this.userData,
    required this.onAnalyze, required this.onValidate, required this.onRefuse,
    required this.aiLoading, required this.aiResult,
  });

  Map<String, dynamic>? _parseAiResult() {
    if (aiResult.isEmpty) return null;
    try {
      final clean = aiResult.replaceAll('```json', '').replaceAll('```', '').trim();
      return json.decode(clean) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final color = docInfo['color'] as Color;
    final aiData = _parseAiResult();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(docInfo['icon'] as IconData, color: color, size: 18),
          const SizedBox(width: 8),
          Text(docInfo['label'] as String,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const Spacer(),
          Text(docInfo['name'] as String,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),

        const SizedBox(height: 10),

        // ── Badge statut ──
        Builder(builder: (ctx) {
          final statut = (docInfo['statut'] as String? ?? 'en_attente');
          final statutColor = statut == 'validé' ? Colors.green : statut == 'refusé' ? Colors.red : Colors.orange;
          final statutLabel = statut == 'validé' ? '✅ Validé' : statut == 'refusé' ? '❌ Refusé' : '⏳ En attente';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statutColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statutColor.withOpacity(0.35)),
            ),
            child: Text(statutLabel,
                style: TextStyle(fontSize: 12, color: statutColor, fontWeight: FontWeight.w700)),
          );
        }),

        // ── Bouton Ouvrir le document ──
        GestureDetector(
          onTap: () => _showDocViewer(context, docInfo),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.visibility_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text('👁️  Ouvrir le document',
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),

        // Bouton analyser IA
        GestureDetector(
          onTap: aiLoading ? null : onAnalyze,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.4)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              aiLoading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.purple, size: 16),
              const SizedBox(width: 8),
              Text(aiLoading ? "Analyse en cours..." : "🤖 Analyser avec l'IA",
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),

        // Résultat IA
        if (aiData != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.psychology_rounded, color: Colors.purple, size: 16),
                const SizedBox(width: 6),
                const Text('Analyse IA', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRecommColor(aiData['recommandation'] ?? '').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(aiData['recommandation'] ?? '',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: _getRecommColor(aiData['recommandation'] ?? ''))),
                ),
              ]),
              const SizedBox(height: 8),
              if (aiData['confiance'] != null)
                _AiBar(label: 'Confiance', value: (aiData['confiance'] as num).toDouble()),
              const SizedBox(height: 6),
              if (aiData['motif'] != null)
                Text(aiData['motif'] as String,
                    style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
            ]),
          ),
        ],

        if (aiResult.isNotEmpty && aiData == null) ...[
          const SizedBox(height: 8),
          Text(aiResult, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],

        const SizedBox(height: 12),

        // Boutons Valider / Refuser
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: onRefuse,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.close_rounded, color: Colors.red, size: 16),
                SizedBox(width: 6),
                Text('Refuser', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: onValidate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_rounded, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('Valider', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }

  Color _getRecommColor(String r) {
    if (r.contains('Valider')) return Colors.green;
    if (r.contains('Refuser')) return Colors.red;
    return Colors.orange;
  }

  void _showDocViewer(BuildContext context, Map<String, dynamic> docInfo) {
    final b64 = (docInfo['base64'] as String?) ?? '';
    final fileName = (docInfo['name'] as String?) ?? '';
    final color = docInfo['color'] as Color;
    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(docInfo['icon'] as IconData, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(docInfo['label'] as String,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                Text(fileName,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18)),
              ),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Contenu
          Expanded(
            child: b64.isEmpty
                ? const Center(child: Text('Document non disponible',
                    style: TextStyle(color: Colors.white38, fontSize: 14)))
                : isImage
                    ? InteractiveViewer(
                        minScale: 0.5, maxScale: 5.0,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(base64Decode(b64), fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      )
                    : _PdfDownloadSection(b64: b64, fileName: fileName, color: color),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widget PDF : télécharge le fichier sur l'appareil
// ═══════════════════════════════════════════════════════════
class _PdfDownloadSection extends StatefulWidget {
  final String b64, fileName;
  final Color color;
  const _PdfDownloadSection({required this.b64, required this.fileName, required this.color});
  @override
  State<_PdfDownloadSection> createState() => _PdfDownloadSectionState();
}

class _PdfDownloadSectionState extends State<_PdfDownloadSection> {
  bool    _saving    = false;
  String? _savedPath = null;
  String? _error     = null;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; _savedPath = null; });
    try {
      final bytes = base64Decode(widget.b64);
      // Sur Android: dossier Downloads accessible par l'utilisateur
      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/NounouGo');
      } else {
        dir = Directory('${Directory.systemTemp.path}/NounouGo');
      }
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}/${widget.fileName}';
      await File(path).writeAsBytes(bytes);
      if (mounted) setState(() { _saving = false; _savedPath = path; });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeKo = (widget.b64.length * 3 / 4 / 1024).toStringAsFixed(0);
    return Center(child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Icône PDF
        Container(width: 96, height: 96,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(0.35), width: 2)),
          child: Icon(Icons.picture_as_pdf_rounded, color: widget.color, size: 46)),
        const SizedBox(height: 16),

        // Nom fichier
        Text(widget.fileName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),

        // Taille
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.35)),
          ),
          child: Text('PDF · $sizeKo Ko',
            style: TextStyle(fontSize: 12, color: widget.color, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),

        // ── État: pas encore téléchargé ──
        if (_savedPath == null) ...[
          // Bouton télécharger
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [widget.color.withOpacity(0.8), widget.color]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_saving)
                  const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                else
                  const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(_saving ? 'Téléchargement...' : '⬇️  Télécharger le PDF',
                  style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('Erreur: $_error',
                style: const TextStyle(fontSize: 11, color: Colors.red), textAlign: TextAlign.center),
            ),
          ],
        ],

        // ── État: téléchargé ──
        if (_savedPath != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: Column(children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                SizedBox(width: 8),
                Text('Fichier sauvegardé !',
                  style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              Text(_savedPath!, style: const TextStyle(fontSize: 11, color: Colors.white38),
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // Copier chemin
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _savedPath!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Chemin copié dans le presse-papier'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy_rounded, color: Colors.white54, size: 14),
                    SizedBox(width: 6),
                    Text('Copier le chemin', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Télécharger à nouveau
          GestureDetector(
            onTap: _save,
            child: Text('Télécharger à nouveau',
              style: TextStyle(fontSize: 12, color: widget.color.withOpacity(0.7),
                  decoration: TextDecoration.underline)),
          ),
        ],
      ]),
    )));
  }
}

class _AiBar extends StatelessWidget {
  final String label; final double value;
  const _AiBar({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      Text('${value.toInt()}%', style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 4),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value / 100,
        backgroundColor: Colors.white.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation(
            value >= 80 ? Colors.green : value >= 50 ? Colors.orange : Colors.red),
        minHeight: 6,
      ),
    ),
  ]);
}

// ════════════════════════════════════════════════
// ONGLET 3 — UTILISATEURS
// ════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'Tous';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filtre + Recherche
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          // Barre de recherche
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filtres
          Row(children: ['Tous', 'Parent', 'Babysitter', 'Bloqué'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filter == f ? AppColors.primaryPink : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _filter == f ? Colors.white : Colors.white54)),
                  ),
                ),
              )
          ).toList()),
        ]),
      ),
      const SizedBox(height: 12),

      // Liste
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));

            var users = snap.data!.docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final role = d['role'] ?? '';
              final bloque = d['bloque'] ?? false;
              final nom = '${d['prenom'] ?? ''} ${d['nom'] ?? ''} ${d['email'] ?? ''}'.toLowerCase();

              if (_search.isNotEmpty && !nom.contains(_search)) return false;
              if (_filter == 'Bloqué') return bloque;
              if (_filter == 'Tous') return true;
              return role == _filter;
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final doc = users[i];
                final d = doc.data() as Map<String, dynamic>;
                return _UserAdminCard(uid: doc.id, data: d);
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _UserAdminCard extends StatelessWidget {
  final String uid; final Map<String, dynamic> data;
  const _UserAdminCard({required this.uid, required this.data});

  Future<void> _toggleBlock(BuildContext context) async {
    final bloque = data['bloque'] ?? false;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'bloque': !bloque});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bloque ? '🔓 Utilisateur débloqué' : '🔒 Utilisateur bloqué'),
        backgroundColor: bloque ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text('Supprimer ${data['prenom']} ${data['nom']} définitivement ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed != true) return;

    final email  = (data['email'] ?? '').toString().toLowerCase();
    final prenom = data['prenom'] ?? '';
    final nom    = data['nom'] ?? '';

    try {
      // 1. Enregistrer dans deleted_accounts
      if (email.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('deleted_accounts')
            .doc(uid)
            .set({
          'uid': uid,
          'email': email,
          'prenom': prenom,
          'nom': nom,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Supprimer la sous-collection documents (diplôme, CV, CNI)
      try {
        final docsSnap = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('documents').get();
        for (final d in docsSnap.docs) {
          await d.reference.delete();
        }
      } catch (_) {}

      // 3. Supprimer le document utilisateur principal
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Compte de $prenom $nom supprimé.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur suppression: ${e.toString().substring(0, e.toString().length.clamp(0, 120))}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = data['role'] ?? '';
    final bloque = data['bloque'] ?? false;
    final color = role == 'Babysitter' ? AppColors.primaryPink : AppColors.buttonBlue;

    // Badges documents validés
    final diploOk = data['diplomePdfStatut'] == 'validé';
    final cvOk = data['cvStatut'] == 'validé';
    final cniOk = data['cniStatut'] == 'validé';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bloque ? Colors.red.withOpacity(0.05) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: bloque ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: [
        Row(children: [
          // Avatar
          Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(bloque ? 0.1 : 0.2), shape: BoxShape.circle),
              child: Center(child: Text(
                '${(data['prenom'] ?? ' ')[0]}${(data['nom'] ?? ' ')[0]}'.toUpperCase(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: bloque ? Colors.red : color),
              ))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: bloque ? Colors.red.shade300 : Colors.white)),
              if (bloque) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Bloqué', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w800))),
              ],
            ]),
            Text(data['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white38),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(role, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700))),
              if (role == 'Babysitter') ...[
                const SizedBox(width: 4),
                if (diploOk) _DocBadge(label: 'Dip', color: Colors.green),
                if (cvOk) ...[const SizedBox(width: 4), _DocBadge(label: 'CV', color: Colors.blue)],
                if (cniOk) ...[const SizedBox(width: 4), _DocBadge(label: 'CNI', color: Colors.teal)],
              ],
            ]),
          ])),
          // Actions
          Column(children: [
            GestureDetector(
              onTap: () => _toggleBlock(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bloque ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(bloque ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: bloque ? Colors.green : Colors.orange, size: 16),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _deleteUser(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _DocBadge extends StatelessWidget {
  final String label; final Color color;
  const _DocBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
    child: Text('✅$label', style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w700)),
  );
}

// ── Bouton confirmation autorisation travail nounou ──
class _ConfirmNounouButton extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _ConfirmNounouButton({required this.uid, required this.data});

  Future<void> _confirm(BuildContext context, bool autoriser) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'autoriseeATravail': autoriser,
    });

    // Notification à la nounou
    final msg = autoriser
        ? "🎉 Félicitations ! Votre profil a été vérifié et vous êtes autorisée à travailler sur NounouGo."
        : "Votre demande d'autorisation a ete refusee. Contactez le support.";
    await FirebaseFirestore.instance.collection('notifications').add({
      'destinataireUid': uid,
      'titre': autoriser ? '✅ Profil autorise' : '❌ Autorisation refusee',
      'message': msg,
      'type': autoriser ? 'autorisation_accordee' : 'autorisation_refusee',
      'lu': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(autoriser
            ? '✅ Nounou autorisée à travailler !'
            : '❌ Autorisation refusée'),
        backgroundColor: autoriser ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final autorisee = data['autoriseeATravail'] ?? false;

    return Column(children: [
      // Statut actuel
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: autorisee
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: autorisee
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            autorisee ? Icons.verified_rounded : Icons.pending_rounded,
            color: autorisee ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            autorisee
                ? 'Nounou autorisée à travailler'
                : "En attente d'autorisation",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: autorisee ? Colors.green : Colors.orange,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),

      // Boutons action
      Row(children: [
        if (autorisee)
          Expanded(
            child: GestureDetector(
              onTap: () => _confirm(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.block_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Révoquer autorisation',
                      style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          )
        else ...[
          Expanded(
            child: GestureDetector(
              onTap: () => _confirm(context, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.close_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 6),
                  Text('Refuser',
                      style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _confirm(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('✅ Confirmer & Autoriser',
                      style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    ]);
  }
}

// ════════════════════════════════════════════════
// ONGLET 4 — COMPTES SUPPRIMÉS
// L'admin peut voir les emails supprimés et les libérer
// pour permettre une nouvelle inscription
// ════════════════════════════════════════════════
class _DeletedAccountsTab extends StatelessWidget {
  const _DeletedAccountsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deleted_accounts')
          .orderBy('deletedAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPink));
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Aucun compte supprimé',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Tous les emails sont libres',
                  style: TextStyle(fontSize: 13, color: Colors.white54)),
            ]),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            // Bannière info
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ces comptes ont été supprimés. Appuyez sur "Libérer" '
                    'pour permettre la réinscription avec le même email.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white60, height: 1.4),
                  ),
                ),
              ]),
            ),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return _DeletedAccountCard(docId: doc.id, data: d);
            }),
          ],
        );
      },
    );
  }
}

class _DeletedAccountCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _DeletedAccountCard({required this.docId, required this.data});
  @override
  State<_DeletedAccountCard> createState() => _DeletedAccountCardState();
}

class _DeletedAccountCardState extends State<_DeletedAccountCard> {
  bool _loading = false;

  Future<void> _libererEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Libérer cet email ?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          "L'email \"${widget.data['email']}\" sera libéré.\n"
          "${widget.data['prenom']} ${widget.data['nom']} pourra créer un nouveau compte.",
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('✅ Libérer',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    await FirebaseFirestore.instance
        .collection('deleted_accounts')
        .doc(widget.docId)
        .delete();

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Email "${widget.data['email']}" libéré !'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.data['email'] ?? '';
    final prenom = widget.data['prenom'] ?? '';
    final nom = widget.data['nom'] ?? '';
    final ts = widget.data['deletedAt'];
    String dateStr = '';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        dateStr = '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
          child: const Center(
              child: Icon(Icons.person_off_rounded, color: Colors.red, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$prenom $nom',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 3),
            Text(email,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Supprimé le $dateStr',
                  style: const TextStyle(fontSize: 11, color: Colors.white30)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        _loading
            ? const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.green))
            : GestureDetector(
                onTap: _libererEmail,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_open_rounded,
                        color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text('Libérer',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
      ]),
    );
  }
}
