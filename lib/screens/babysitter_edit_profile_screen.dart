import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';

class BabysitterEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const BabysitterEditProfileScreen({super.key, required this.data});

  @override
  State<BabysitterEditProfileScreen> createState() =>
      _BabysitterEditProfileScreenState();
}

class _BabysitterEditProfileScreenState
    extends State<BabysitterEditProfileScreen> {
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  late TextEditingController _bioController;
  late TextEditingController _diplomeController;
  late TextEditingController _competenceController;

  late List<String> _diplomes;
  late List<String> _competences;
  late List<String> _ageGroups;

  // Disponibilités : Map jour → Set<périodes sélectionnées>
  // Structure stockée en Firestore sous forme Map<String, List<String>>
  late Map<String, Set<String>> _disponibilites;

  String? _photoBase64;
  bool _isSaving = false;

  // Documents PDF
  String? _diplomePdfBase64;
  String? _diplomePdfName;
  String? _cvBase64;
  String? _cvName;
  String? _cniBase64;
  String? _cniName;
  bool _loadingDoc = false;

  static const List<String> _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const List<String> _periodes = [
    'Matin', 'Midi', 'Après-midi', 'Soir', 'Nuit',
  ];
  final List<String> _ageGroupsList = [
    '0-1 an', '1-3 ans', '3-6 ans', '6-10 ans', '10+ ans',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _bioController        = TextEditingController(text: d['bio'] ?? '');
    _diplomeController    = TextEditingController();
    _competenceController = TextEditingController();
    _diplomes       = List<String>.from(d['diplomes']      ?? []);
    _competences    = List<String>.from(d['competences']   ?? []);
    _ageGroups      = List<String>.from(d['ageGroups']     ?? []);

    // Load structured disponibilites: Firestore stores Map<String, List<String>>
    // Fallback: if old flat List<String> is stored, treat each entry as a day with no periods
    final rawDispos = d['disponibilites'];
    _disponibilites = {};
    if (rawDispos is Map) {
      rawDispos.forEach((jour, periodes) {
        if (periodes is List) {
          _disponibilites[jour.toString()] =
          Set<String>.from(periodes.map((p) => p.toString()));
        }
      });
    }
    // Pre-populate all days so UI always shows them
    for (final jour in _jours) {
      _disponibilites.putIfAbsent(jour, () => <String>{});
    }
    _photoBase64      = d['photoBase64']      as String?;
    _diplomePdfBase64 = d['diplomePdfBase64'] as String?;
    _diplomePdfName   = d['diplomePdfName']   as String?;
    _cvBase64         = d['cvBase64']         as String?;
    _cvName           = d['cvName']           as String?;
    _cniBase64        = d['cniBase64']        as String?;
    _cniName          = d['cniName']          as String?;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _diplomeController.dispose();
    _competenceController.dispose();
    super.dispose();
  }

  // ── Pick photo ──────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: source, imageQuality: 70, maxWidth: 300, maxHeight: 300);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _photoBase64 = base64Encode(bytes));
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Choisir une photo',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _SourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Caméra',
                  color: AppColors.buttonBlue,
                  onTap: () =>
                      Navigator.pop(context, ImageSource.camera),
                )),
            const SizedBox(width: 16),
            Expanded(
                child: _SourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: AppColors.primaryPink,
                  onTap: () =>
                      Navigator.pop(context, ImageSource.gallery),
                )),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Pick document ───────────────────────────────────────────
  Future<void> _pickDoc(String type) async {
    setState(() => _loadingDoc = true);
    try {
      final extensions =
      type == 'cni' ? ['pdf', 'jpg', 'jpeg', 'png'] : ['pdf'];
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final b64  = base64Encode(result.files.single.bytes!);
        final name = result.files.single.name;
        setState(() {
          if (type == 'diplome') {
            _diplomePdfBase64 = b64;
            _diplomePdfName   = name;
          } else if (type == 'cv') {
            _cvBase64 = b64;
            _cvName   = name;
          } else {
            _cniBase64 = b64;
            _cniName   = name;
          }
        });
      }
    } catch (_) {}
    setState(() => _loadingDoc = false);
  }

  // ── Save ────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final doc      = await _db.collection('users').doc(_uid).get();
      final existing = doc.data() ?? {};

      final diploStatut = _diplomePdfBase64 != existing['diplomePdfBase64']
          ? 'en_attente'
          : (existing['diplomePdfStatut'] ?? 'non_soumis');
      final cvStatut = _cvBase64 != existing['cvBase64']
          ? 'en_attente'
          : (existing['cvStatut'] ?? 'non_soumis');
      final cniStatut = _cniBase64 != existing['cniBase64']
          ? 'en_attente'
          : (existing['cniStatut'] ?? 'non_soumis');

      await _db.collection('users').doc(_uid).update({
        'bio':            _bioController.text.trim(),
        'diplomes':       _diplomes,
        'competences':    _competences,
        // Serialize Map<String, Set<String>> → Map<String, List<String>>
        'disponibilites': _disponibilites.map(
                (jour, periodes) => MapEntry(jour, periodes.toList())),
        'ageGroups':      _ageGroups,
        if (_photoBase64 != null)      'photoBase64':      _photoBase64,
        if (_diplomePdfBase64 != null) 'diplomePdfBase64': _diplomePdfBase64,
        if (_diplomePdfName   != null) 'diplomePdfName':   _diplomePdfName,
        'diplomePdfStatut': diploStatut,
        if (_cvBase64 != null) 'cvBase64': _cvBase64,
        if (_cvName   != null) 'cvName':   _cvName,
        'cvStatut':  cvStatut,
        if (_cniBase64 != null) 'cniBase64': _cniBase64,
        if (_cniName   != null) 'cniName':   _cniName,
        'cniStatut': cniStatut,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Profil mis à jour !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(children: [

            // ── Gradient header ──────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8FAB), AppColors.primaryPink],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Modifier mon profil',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSaving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: _isSaving
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryPink))
                        : const Text(
                      'Enregistrer',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPink),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Scrollable content ───────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  _buildSection('📷 Photo de profil',
                      _buildPhotoSection()),
                  const SizedBox(height: 16),

                  _buildSection('📝 À propos',
                      _buildBioSection()),
                  const SizedBox(height: 16),

                  _buildSection('🎓 Diplômes',
                      _buildListSection(
                        controller: _diplomeController,
                        items:      _diplomes,
                        hint:  'Ex: CAP Petite Enfance',
                        icon:  Icons.school_outlined,
                        color: AppColors.primaryPink,
                      )),
                  const SizedBox(height: 16),

                  _buildSection('⭐ Compétences',
                      _buildListSection(
                        controller: _competenceController,
                        items:      _competences,
                        hint:  'Ex: Premiers secours',
                        icon:  Icons.star_outline_rounded,
                        color: AppColors.buttonBlue,
                      )),
                  const SizedBox(height: 16),

                  _buildSection('🕐 Disponibilités',
                      _buildDisponibilitesSection()),
                  const SizedBox(height: 16),

                  _buildSection("👶 Tranches d'âge",
                      _buildChipsSection(
                        list:     _ageGroupsList,
                        selected: _ageGroups,
                        color:    Colors.teal,
                      )),
                  const SizedBox(height: 16),

                  _buildSection('📄 Documents officiels',
                      _buildDocsSection()),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Section card wrapper ─────────────────────────────────────
  Widget _buildSection(String title, Widget child) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: child,
        ),
      ]);

  // ── Photo section ────────────────────────────────────────────
  Widget _buildPhotoSection() => Center(
    child: GestureDetector(
      onTap: _pickPhoto,
      child: Stack(children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.primaryPink.withOpacity(0.4),
                width: 3),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryPink.withOpacity(0.15),
                  blurRadius: 16)
            ],
          ),
          child: ClipOval(
            child: _photoBase64 != null
                ? Image.memory(base64Decode(_photoBase64!),
                fit: BoxFit.cover)
                : Container(
                color: AppColors.lightPink,
                child: const Icon(Icons.person_rounded,
                    size: 40, color: AppColors.primaryPink)),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: AppColors.primaryPink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 14),
          ),
        ),
      ]),
    ),
  );

  // ── Bio section ──────────────────────────────────────────────
  Widget _buildBioSection() => TextField(
    controller: _bioController,
    maxLines: 4,
    maxLength: 500,
    style:
    const TextStyle(fontSize: 14, color: AppColors.textDark),
    decoration: InputDecoration(
      hintText: 'Présentez-vous en quelques mots...',
      hintStyle: const TextStyle(
          color: AppColors.textGrey, fontSize: 14),
      filled: true,
      fillColor: AppColors.lightPink,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: AppColors.primaryPink, width: 1.5)),
      contentPadding: const EdgeInsets.all(14),
    ),
  );

  // ── List section (diplomas / competences) ───────────────────
  Widget _buildListSection({
    required TextEditingController controller,
    required List<String> items,
    required String hint,
    required IconData icon,
    required Color color,
  }) =>
      Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13),
                filled: true,
                fillColor: AppColors.lightPink,
                prefixIcon: Icon(icon, color: color, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final val = controller.text.trim();
              if (val.isNotEmpty && !items.contains(val)) {
                setState(() {
                  items.add(val);
                  controller.clear();
                });
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...items.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(e.value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark))),
              GestureDetector(
                onTap: () =>
                    setState(() => items.removeAt(e.key)),
                child: Icon(Icons.close_rounded,
                    color: color.withOpacity(0.6), size: 18),
              ),
            ]),
          )),
        ],
      ]);

  // ── Disponibilités section (jour → périodes) ─────────────────
  Widget _buildDisponibilitesSection() {
    return Column(
      children: _jours.asMap().entries.map((entry) {
        final isLast = entry.key == _jours.length - 1;
        final jour   = entry.value;
        final selectedPeriodes = _disponibilites[jour] ?? <String>{};
        final jouActif = selectedPeriodes.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day row header
            Row(children: [
              GestureDetector(
                onTap: () => setState(() {
                  if (jouActif) {
                    _disponibilites[jour] = <String>{};
                  } else {
                    _disponibilites[jour] = Set<String>.from(_periodes);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: jouActif
                        ? const Color(0xFF4CAF50)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: jouActif
                          ? const Color(0xFF4CAF50)
                          : AppColors.textGrey.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: jouActif
                      ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                jour,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: jouActif ? AppColors.textDark : AppColors.textGrey,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Period chips for this day
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _periodes.map((periode) {
                final isSel = selectedPeriodes.contains(periode);
                return GestureDetector(
                  onTap: () => setState(() {
                    final set = _disponibilites[jour] ?? <String>{};
                    if (isSel) {
                      set.remove(periode);
                    } else {
                      set.add(periode);
                    }
                    _disponibilites[jour] = set;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel
                            ? const Color(0xFF4CAF50)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      periode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSel
                            ? Colors.white
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (!isLast) ...[
              const SizedBox(height: 12),
              const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF5EEF0)),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  // ── Chips section (generic — used for âge groups) ────────────
  Widget _buildChipsSection({
    required List<String> list,
    required List<String> selected,
    required Color color,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: list.map((item) {
          final isSel = selected.contains(item);
          return GestureDetector(
            onTap: () => setState(() =>
            isSel ? selected.remove(item) : selected.add(item)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? color : AppColors.lightPink,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSel ? color : Colors.transparent),
              ),
              child: Text(item,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSel
                          ? Colors.white
                          : AppColors.textDark)),
            ),
          );
        }).toList(),
      );

  // ── Documents section ────────────────────────────────────────
  Widget _buildDocsSection() {
    final docs = [
      {
        'type':     'diplome',
        'title':    'Diplôme',
        'subtitle': 'Licence, CAP Petite Enfance... (PDF)',
        'icon':     Icons.school_rounded,
        'color':    AppColors.primaryPink,
        'name':     _diplomePdfName,
        'statut':   widget.data['diplomePdfStatut'] ?? 'non_soumis',
      },
      {
        'type':     'cv',
        'title':    'CV',
        'subtitle': 'Curriculum Vitae (PDF)',
        'icon':     Icons.description_rounded,
        'color':    AppColors.buttonBlue,
        'name':     _cvName,
        'statut':   widget.data['cvStatut'] ?? 'non_soumis',
      },
      {
        'type':     'cni',
        'title':    "Carte d'identité",
        'subtitle': 'Recto/verso (PDF, JPG, PNG)',
        'icon':     Icons.badge_rounded,
        'color':    Colors.teal,
        'name':     _cniName,
        'statut':   widget.data['cniStatut'] ?? 'non_soumis',
      },
    ];

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.amber, size: 18),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                'Les documents sont vérifiés par notre équipe. Un badge ✅ sera affiché sur votre profil une fois validés.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                    height: 1.4),
              )),
        ]),
      ),
      ...docs.map((doc) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _DocCard(
          title:    doc['title']    as String,
          subtitle: doc['subtitle'] as String,
          icon:     doc['icon']     as IconData,
          color:    doc['color']    as Color,
          fileName: doc['name']     as String?,
          statut:   doc['statut']   as String,
          isLoading: _loadingDoc,
          onTap: () => _pickDoc(doc['type'] as String),
          onRemove: () => setState(() {
            if (doc['type'] == 'diplome') {
              _diplomePdfBase64 = null;
              _diplomePdfName   = null;
            } else if (doc['type'] == 'cv') {
              _cvBase64 = null;
              _cvName   = null;
            } else {
              _cniBase64 = null;
              _cniName   = null;
            }
          }),
        ),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// DOC CARD
// ─────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final String title, subtitle, statut;
  final IconData icon;
  final Color color;
  final String? fileName;
  final bool isLoading;
  final VoidCallback onTap, onRemove;

  const _DocCard({
    required this.title,
    required this.subtitle,
    required this.statut,
    required this.icon,
    required this.color,
    required this.fileName,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
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
    final hasFile = fileName != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFile
            ? color.withOpacity(0.04)
            : Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile
              ? color.withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8)
        ],
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: isLoading
                ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textGrey)),
                  ])),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statutColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_statutLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: _statutColor,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        if (hasFile) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.attach_file_rounded,
                size: 14, color: AppColors.textGrey),
            const SizedBox(width: 6),
            Expanded(
                child: Text(fileName!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.red, size: 14),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      hasFile
                          ? Icons.refresh_rounded
                          : Icons.upload_file_rounded,
                      color: color,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(hasFile ? 'Remplacer' : 'Choisir un fichier',
                      style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w700)),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SOURCE OPTION (bottom sheet)
// ─────────────────────────────────────────────────────────────
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    ),
  );
}
