import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'nounou_profile_screen.dart';
import 'dart:convert';

class SearchNounousScreen extends StatefulWidget {
  const SearchNounousScreen({super.key});
  @override
  State<SearchNounousScreen> createState() => _SearchNounousScreenState();
}

class _SearchNounousScreenState extends State<SearchNounousScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _nounous = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  // Filtres
  String? _selectedVille;
  String? _selectedDisponibilite;
  String? _selectedTranche;
  double? _maxPrix;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _disponibilites = ['Matin', 'Après-midi', 'Soir', 'Week-end', 'Temps plein'];
  final List<String> _tranches = ['0-1 an', '1-3 ans', '3-6 ans', '6-12 ans', '12+ ans'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _loadNounous();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNounous() async {
    try {
      final query = await _db
          .collection('users')
          .where('role', isEqualTo: 'Babysitter')
          .get();

      final list = query.docs
          .map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      })
      // Exclure les nounous bloquées ou non autorisées
          .where((n) => !(n['bloque'] ?? false) && ((n['compteActif'] ?? false) || (n['autoriseeATravail'] ?? false)))
          .toList();

      setState(() {
        _nounous = list;
        _filtered = list;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final search = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _nounous.where((n) {
        final prenom = (n['prenom'] ?? '').toLowerCase();
        final nom = (n['nom'] ?? '').toLowerCase();
        final ville = (n['ville'] ?? '').toLowerCase();

        // Recherche texte
        if (search.isNotEmpty && !prenom.contains(search) && !nom.contains(search) && !ville.contains(search)) {
          return false;
        }
        // Filtre ville
        if (_selectedVille != null && _selectedVille!.isNotEmpty) {
          if (!(n['ville'] ?? '').toLowerCase().contains(_selectedVille!.toLowerCase())) return false;
        }
        // Filtre disponibilité
        if (_selectedDisponibilite != null) {
          final dispos = List<String>.from(n['disponibilites'] ?? []);
          if (!dispos.contains(_selectedDisponibilite)) return false;
        }
        // Filtre tranche d'âge
        if (_selectedTranche != null) {
          final tranches = List<String>.from(n['ageGroups'] ?? []);
          if (!tranches.contains(_selectedTranche)) return false;
        }
        // Filtre prix
        if (_maxPrix != null) {
          final prix = (n['prixHeure'] ?? 999).toDouble();
          if (prix > _maxPrix!) return false;
        }
        return true;
      }).toList();
    });
  }

  void _showFilterSheet() {
    String? tempVille = _selectedVille;
    String? tempDispo = _selectedDisponibilite;
    String? tempTranche = _selectedTranche;
    double? tempPrix = _maxPrix;

    // Contrôleur ville persistant — créé une seule fois avec le curseur à la fin
    final villeCtrl = TextEditingController(text: tempVille ?? '');
    villeCtrl.selection = TextSelection.collapsed(offset: villeCtrl.text.length);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.inputBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Filtres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                TextButton(
                  onPressed: () {
                    villeCtrl.clear();
                    setSheetState(() { tempVille = null; tempDispo = null; tempTranche = null; tempPrix = null; });
                  },
                  child: Text('Réinitialiser', style: TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 24),

              // ── Ville ──
              _FilterLabel(icon: Icons.location_on_rounded, label: 'Ville'),
              const SizedBox(height: 10),
              TextField(
                controller: villeCtrl,
                decoration: InputDecoration(
                  hintText: 'Ex: Alger, Oran, Tlemcen...',
                  hintStyle: const TextStyle(color: AppColors.textGrey),
                  filled: true, fillColor: AppColors.lightPink,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primaryPink),
                ),
                onChanged: (v) {
                  tempVille = v.trim().isEmpty ? null : v.trim();
                },
              ),
              const SizedBox(height: 20),

              // ── Disponibilité ──
              _FilterLabel(icon: Icons.schedule_rounded, label: 'Disponibilité'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _disponibilites.map((d) =>
                  GestureDetector(
                    onTap: () => setSheetState(() => tempDispo = tempDispo == d ? null : d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: tempDispo == d ? AppColors.buttonBlue : AppColors.lightPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(d, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: tempDispo == d ? Colors.white : AppColors.textDark)),
                    ),
                  ),
              ).toList()),
              const SizedBox(height: 20),

              // ── Tranche d'âge ──
              _FilterLabel(icon: Icons.child_care_rounded, label: 'Tranche d\'âge enfants'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _tranches.map((t) =>
                  GestureDetector(
                    onTap: () => setSheetState(() => tempTranche = tempTranche == t ? null : t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: tempTranche == t ? AppColors.primaryPink : AppColors.lightPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: tempTranche == t ? Colors.white : AppColors.textDark)),
                    ),
                  ),
              ).toList()),
              const SizedBox(height: 20),

              // ── Prix max ──
              _FilterLabel(icon: Icons.payments_rounded, label: 'Prix max / heure : ${tempPrix != null ? '${tempPrix!.toInt()} DA' : 'Tous'}'),
              Slider(
                value: tempPrix ?? 5000,
                min: 500, max: 5000, divisions: 18,
                activeColor: AppColors.buttonBlue,
                inactiveColor: AppColors.lightPink,
                label: '${(tempPrix ?? 5000).toInt()} DA',
                onChanged: (v) => setSheetState(() => tempPrix = v == 5000 ? null : v),
              ),
              const SizedBox(height: 24),

              // ── Appliquer ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedVille = tempVille;
                      _selectedDisponibilite = tempDispo;
                      _selectedTranche = tempTranche;
                      _maxPrix = tempPrix;
                    });
                    _applyFilters();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Appliquer les filtres',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedVille != null) count++;
    if (_selectedDisponibilite != null) count++;
    if (_selectedTranche != null) count++;
    if (_maxPrix != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Trouver une nounou',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Stack(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _activeFiltersCount > 0 ? AppColors.buttonBlue : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Icon(Icons.tune_rounded,
                            color: _activeFiltersCount > 0 ? Colors.white : AppColors.textDark, size: 22),
                      ),
                      if (_activeFiltersCount > 0)
                        Positioned(top: 0, right: 0,
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
                            child: Center(child: Text('$_activeFiltersCount',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))),
                          ),
                        ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Barre de recherche ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par nom ou ville...',
                      hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textGrey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Chips filtres actifs
                if (_activeFiltersCount > 0)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      if (_selectedVille != null) _FilterChip(icon: Icons.location_on_rounded, label: _selectedVille!, onRemove: () { setState(() => _selectedVille = null); _applyFilters(); }),
                      if (_selectedDisponibilite != null) _FilterChip(icon: Icons.schedule_rounded, label: _selectedDisponibilite!, onRemove: () { setState(() => _selectedDisponibilite = null); _applyFilters(); }),
                      if (_selectedTranche != null) _FilterChip(icon: Icons.child_care_rounded, label: _selectedTranche!, onRemove: () { setState(() => _selectedTranche = null); _applyFilters(); }),
                      if (_maxPrix != null) _FilterChip(icon: Icons.payments_rounded, label: 'Max ${_maxPrix!.toInt()} DA', onRemove: () { setState(() => _maxPrix = null); _applyFilters(); }),
                    ]),
                  ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Résultats ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
                  : _filtered.isEmpty
                  ? _EmptyState()
                  : FadeTransition(
                opacity: _fadeAnim,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _NounouCard(
                    nounou: _filtered[i],
                    onTap: () => Navigator.push(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => NounouProfileScreen(nounouData: _filtered[i]),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 300),
                    )),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Widgets helper ──

class _FilterLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FilterLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: AppColors.primaryPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: AppColors.primaryPink),
    ),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
  ]);
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.icon, required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.buttonBlue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.buttonBlue.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.buttonBlue),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.buttonBlue, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: AppColors.buttonBlue.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 10, color: AppColors.buttonBlue),
        ),
      ),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryPink.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.primaryPink),
      ),
      const SizedBox(height: 16),
      const Text('Aucune nounou trouvée',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Text('Modifiez vos filtres pour voir plus de résultats',
          style: TextStyle(fontSize: 14, color: AppColors.textGrey), textAlign: TextAlign.center),
    ]),
  );
}

class _NounouCard extends StatelessWidget {
  final Map<String, dynamic> nounou;
  final VoidCallback onTap;
  const _NounouCard({required this.nounou, required this.onTap});

  String get _initiales {
    final p = (nounou['prenom'] ?? '');
    final n = (nounou['nom'] ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final prenom = nounou['prenom'] ?? '';
    final nom = nounou['nom'] ?? '';
    final ville = nounou['ville'] ?? 'Ville non renseignée';
    final prix = nounou['prixHeure'];
    final score = (nounou['score'] ?? 0.0).toDouble();
    final nbAvis = nounou['nbAvis'] ?? 0;
    final photoBase64 = nounou['photoBase64'] as String?;
    final disponibilites = List<String>.from(nounou['disponibilites'] ?? []);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPink.withOpacity(0.3), width: 2)),
            child: ClipOval(
              child: photoBase64 != null
                  ? Image.memory(base64Decode(photoBase64), fit: BoxFit.cover)
                  : Container(
                  color: AppColors.primaryPink.withOpacity(0.1),
                  child: Center(child: Text(_initiales,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryPink)))),
            ),
          ),
          const SizedBox(width: 14),

          // Infos
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$prenom $nom', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              if (score > 0) Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 2),
                Text(score.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(' ($nbAvis)', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ]),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppColors.primaryPink),
              const SizedBox(width: 3),
              Text(ville, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              if (prix != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.payments_outlined, size: 13, color: AppColors.buttonBlue),
                const SizedBox(width: 3),
                Text('$prix DA/h', style: const TextStyle(fontSize: 12, color: AppColors.buttonBlue, fontWeight: FontWeight.w600)),
              ],
            ]),
            if (disponibilites.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: disponibilites.take(3).map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.lightPink, borderRadius: BorderRadius.circular(8)),
                child: Text(d, style: const TextStyle(fontSize: 10, color: AppColors.primaryPink, fontWeight: FontWeight.w600)),
              )).toList()),
            ],
          ])),

          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textGrey),
        ]),
      ),
    );
  }
}