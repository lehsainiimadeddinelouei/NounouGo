import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'babysitter_home_screen.dart';

class BabysitterSetupScreen extends StatefulWidget {
  const BabysitterSetupScreen({super.key});
  @override
  State<BabysitterSetupScreen> createState() =>
      _BabysitterSetupScreenState();
}

class _BabysitterSetupScreenState
    extends State<BabysitterSetupScreen>
    with SingleTickerProviderStateMixin {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _villeController      = TextEditingController();
  final _bioController        = TextEditingController();
  final _prixController       = TextEditingController();
  final _diplomeController    = TextEditingController();
  final _competenceController = TextEditingController();
  final _experienceController = TextEditingController();

  final List<String> _diplomes     = [];
  final List<String> _competences  = [];
  final List<String> _experiences  = [];
  // Disponibilités structurées : Map jour → Set<périodes>
  final Map<String, Set<String>> _disponibilites = {
    'Lundi': {}, 'Mardi': {}, 'Mercredi': {}, 'Jeudi': {},
    'Vendredi': {}, 'Samedi': {}, 'Dimanche': {},
  };
  final Set<String>  _ageGroups = {};

  // Documents PDF
  String? _diplomePdfBase64;
  String? _diplomePdfName;
  String? _cniBase64;
  String? _cniName;
  bool _loadingPdf = false;

  bool _isSaving    = false;
  int  _currentStep = 0;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  static const List<String> _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const List<String> _periodes = [
    'Matin', 'Midi', 'Après-midi', 'Soir', 'Nuit',
  ];
  final List<String> _ageGroupsList = [
    '0-1 an', '1-3 ans', '3-6 ans', '6-12 ans', '12+ ans'
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  Future<void> _pickPdf(String type) async {
    setState(() => _loadingPdf = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == 'cni'
            ? ['pdf', 'jpg', 'jpeg', 'png']
            : ['pdf'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final bytes     = result.files.single.bytes!;
        final base64str = base64Encode(bytes);
        final name      = result.files.single.name;
        setState(() {
          if (type == 'diplome') {
            _diplomePdfBase64 = base64str;
            _diplomePdfName   = name;
          } else {
            _cniBase64 = base64str;
            _cniName   = name;
          }
        });
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
    setState(() => _loadingPdf = false);
  }

  @override
  void dispose() {
    _animController.dispose();
    _villeController.dispose();
    _bioController.dispose();
    _prixController.dispose();
    _diplomeController.dispose();
    _competenceController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _addItem(TextEditingController ctrl, List<String> list) {
    final val = ctrl.text.trim();
    if (val.isEmpty) return;
    setState(() { list.add(val); ctrl.clear(); });
  }

  void _removeItem(List<String> list, int index) =>
      setState(() => list.removeAt(index));

  Future<void> _saveProfil() async {
    if (_villeController.text.trim().isEmpty) {
      _showSnack('Veuillez saisir votre ville.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).update({
        'ville':            _villeController.text.trim(),
        'bio':              _bioController.text.trim(),
        'prixHeure':        int.tryParse(_prixController.text.trim()) ?? 0,
        'diplomes':         _diplomes,
        'diplomePdfBase64': _diplomePdfBase64,
        'diplomePdfName':   _diplomePdfName,
        'cniBase64':        _cniBase64,
        'cniName':          _cniName,
        'competences':      _competences,
        'experiences':      _experiences,
        // Serialize Map<String, Set<String>> → Map<String, List<String>>
        'disponibilites':   _disponibilites.map(
                (jour, periodes) => MapEntry(jour, periodes.toList())),
        'ageGroups':        _ageGroups.toList(),
        'score':            0.0,
        'nbAvis':           0,
        'commentaires':     [],
        'profilComplet':    true,
      });
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
              const BabysitterHomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration:
              const Duration(milliseconds: 400),
            ),
                (route) => false);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Erreur : $e');
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? AppColors.primaryPink : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    } else {
      _saveProfil();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
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

            // ── Progress header ──────────────────────────────
            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          GestureDetector(
                            onTap: _prevStep,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.06),
                                      blurRadius: 10)
                                ],
                              ),
                              child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 16,
                                  color: AppColors.textDark),
                            ),
                          )
                        else
                          const SizedBox(width: 40),

                        // Animated pill dots
                        Row(
                            children: List.generate(
                                4,
                                    (i) => AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 300),
                                  margin: const EdgeInsets
                                      .symmetric(horizontal: 3),
                                  width: i == _currentStep
                                      ? 24
                                      : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i <= _currentStep
                                        ? AppColors.primaryPink
                                        : AppColors.lightPink,
                                    borderRadius:
                                    BorderRadius.circular(4),
                                  ),
                                ))),

                        Text(
                          '${_currentStep + 1} / 4',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Linear progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 4,
                        backgroundColor: AppColors.lightPink,
                        color: AppColors.primaryPink,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
            ),

            // ── Step content ─────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20),
                  child: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                  ][_currentStep],
                ),
              ),
            ),

            // ── Next / Finish button ─────────────────────────
            Padding(
              padding:
              const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: CustomButton(
                label: _currentStep < 3
                    ? 'Suivant →'
                    : 'Terminer mon profil ✓',
                onTap: _nextStep,
                isLoading: _isSaving,
                color: AppColors.primaryPink,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Section title helper ─────────────────────────────────────
  Widget _sectionTitle(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textGrey,
        letterSpacing: 1.2),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 6))
    ],
  );

  // ── Step 1 : Basic info ──────────────────────────────────────
  Widget _buildStep1() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Informations de base',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('Dites-nous où vous êtes et votre tarif',
            style: TextStyle(
                fontSize: 14, color: AppColors.textGrey)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(children: [
            CustomTextField(
                controller: _villeController,
                hintText: 'Votre ville *',
                prefixIcon: Icons.location_on_outlined,
                accentColor: AppColors.primaryPink),
            const SizedBox(height: 14),
            CustomTextField(
                controller: _prixController,
                hintText: 'Prix / heure (DA)',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                accentColor: AppColors.primaryPink),
            const SizedBox(height: 14),
            TextField(
              controller: _bioController,
              maxLines: 4,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
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
                        color: AppColors.primaryPink,
                        width: 1.5)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Disponibilités'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            children: _jours.asMap().entries.map((entry) {
              final isLast = entry.key == _jours.length - 1;
              final jour   = entry.value;
              final selectedPeriodes = _disponibilites[jour] ?? <String>{};
              final jouActif = selectedPeriodes.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (jouActif) {
                          _disponibilites[jour] = <String>{};
                        } else {
                          _disponibilites[jour] =
                          Set<String>.from(_periodes);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: jouActif
                              ? AppColors.primaryPink
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: jouActif
                                ? AppColors.primaryPink
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
                        color: jouActif
                            ? AppColors.textDark
                            : AppColors.textGrey,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _periodes.map((periode) {
                      final isSel = selectedPeriodes.contains(periode);
                      return GestureDetector(
                        onTap: () => setState(() {
                          final set =
                              _disponibilites[jour] ?? <String>{};
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
                                ? AppColors.primaryPink
                                : AppColors.lightPink,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.primaryPink
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
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle("Tranches d'âge"),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ageGroupsList.map((a) => GestureDetector(
            onTap: () => setState(() =>
            _ageGroups.contains(a)
                ? _ageGroups.remove(a)
                : _ageGroups.add(a)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _ageGroups.contains(a)
                    ? AppColors.buttonBlue
                    : AppColors.lightPink,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _ageGroups.contains(a)
                        ? AppColors.buttonBlue
                        : Colors.transparent),
              ),
              child: Text(a,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ageGroups.contains(a)
                          ? Colors.white
                          : AppColors.textDark)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ]);

  // ── Step 2 : Diplômes + documents ───────────────────────────
  Widget _buildStep2() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Diplômes & Formations',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('Ajoutez vos diplômes et certifications',
            style: TextStyle(
                fontSize: 14, color: AppColors.textGrey)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Row(children: [
            Expanded(
                child: CustomTextField(
                    controller: _diplomeController,
                    hintText: 'Ex: CAP Petite Enfance',
                    prefixIcon: Icons.school_outlined,
                    accentColor: AppColors.primaryPink)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () =>
                  _addItem(_diplomeController, _diplomes),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppColors.primaryPink,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add,
                    color: Colors.white),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_diplomes.isNotEmpty)
          ..._diplomes.asMap().entries.map((e) => _ItemCard(
            text: e.value,
            icon: Icons.school_outlined,
            color: AppColors.primaryPink,
            onRemove: () => _removeItem(_diplomes, e.key),
          )),
        if (_diplomes.isEmpty)
          _EmptyHint(text: 'Aucun diplôme ajouté'),
        const SizedBox(height: 24),
        _sectionTitle('Documents officiels'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.amber.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded,
                color: Colors.amber, size: 18),
            SizedBox(width: 10),
            Expanded(
                child: Text(
                  'Documents vérifiés par notre équipe (facultatif lors de l\'inscription).',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      height: 1.4),
                )),
          ]),
        ),
        _DocumentUploadCard(
          title: 'Diplôme (PDF)',
          subtitle: 'CAP, Licence, certificat...',
          icon: Icons.school_rounded,
          color: AppColors.primaryPink,
          fileName: _diplomePdfName,
          isLoading: _loadingPdf,
          onTap: () => _pickPdf('diplome'),
          onRemove: () => setState(() {
            _diplomePdfBase64 = null;
            _diplomePdfName   = null;
          }),
        ),
        const SizedBox(height: 12),
        _DocumentUploadCard(
          title: "Carte d'identité",
          subtitle: 'Recto/verso (PDF, JPG, PNG)',
          icon: Icons.badge_rounded,
          color: Colors.teal,
          fileName: _cniName,
          isLoading: _loadingPdf,
          onTap: () => _pickPdf('cni'),
          onRemove: () => setState(() {
            _cniBase64 = null;
            _cniName   = null;
          }),
        ),
        const SizedBox(height: 20),
      ]);

  // ── Step 3 : Compétences ─────────────────────────────────────
  Widget _buildStep3() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Compétences',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('Vos atouts et compétences spéciales',
            style: TextStyle(
                fontSize: 14, color: AppColors.textGrey)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Row(children: [
            Expanded(
                child: CustomTextField(
                    controller: _competenceController,
                    hintText: 'Ex: Premiers secours',
                    prefixIcon: Icons.star_outline_rounded,
                    accentColor: AppColors.buttonBlue)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addItem(
                  _competenceController, _competences),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppColors.buttonBlue,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add,
                    color: Colors.white),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_competences.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _competences.asMap().entries.map((e) =>
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.buttonBlue
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.buttonBlue
                            .withOpacity(0.2)),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.value,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.buttonBlue,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        GestureDetector(
                            onTap: () =>
                                _removeItem(_competences, e.key),
                            child: const Icon(Icons.close,
                                size: 14,
                                color: AppColors.buttonBlue)),
                      ]),
                )).toList(),
          ),
        if (_competences.isEmpty)
          _EmptyHint(text: 'Aucune compétence ajoutée'),
        const SizedBox(height: 20),
      ]);

  // ── Step 4 : Expériences ─────────────────────────────────────
  Widget _buildStep4() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Expériences',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('Décrivez vos expériences passées',
            style: TextStyle(
                fontSize: 14, color: AppColors.textGrey)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(children: [
            TextField(
              controller: _experienceController,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText:
                "Ex: 2 ans garde d'enfants famille Dupont...",
                hintStyle: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13),
                filled: true,
                fillColor: AppColors.lightPink,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryPink,
                        width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addItem(
                    _experienceController, _experiences),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter',
                    style: TextStyle(
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_experiences.isNotEmpty)
          ..._experiences.asMap().entries.map((e) => _ItemCard(
            text: e.value,
            icon: Icons.work_outline_rounded,
            color: const Color(0xFF9B59B6),
            onRemove: () =>
                _removeItem(_experiences, e.key),
          )),
        if (_experiences.isEmpty)
          _EmptyHint(text: 'Aucune expérience ajoutée'),
        const SizedBox(height: 20),
      ]);
}

// ─────────────────────────────────────────────────────────────
// ITEM CARD
// ─────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onRemove;
  const _ItemCard({
    required this.text,
    required this.icon,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2))
      ],
    ),
    child: Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500))),
      GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.delete_outline_rounded,
              size: 16, color: Colors.red),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// EMPTY HINT
// ─────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppColors.lightPink,
        borderRadius: BorderRadius.circular(14)),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textGrey),
        textAlign: TextAlign.center),
  );
}

// ─────────────────────────────────────────────────────────────
// DOCUMENT UPLOAD CARD
// ─────────────────────────────────────────────────────────────
class _DocumentUploadCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final String? fileName;
  final bool isLoading;
  final VoidCallback onTap, onRemove;

  const _DocumentUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.fileName,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;
    return GestureDetector(
      onTap: hasFile ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? color.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            width: hasFile ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10)
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading
                ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color))
                : Icon(
                hasFile ? Icons.check_circle_rounded : icon,
                color: hasFile ? Colors.green : color,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(
                      hasFile ? fileName! : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        hasFile ? Colors.green.shade700 : AppColors.textGrey,
                        fontWeight:
                        hasFile ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ])),
          if (hasFile)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.red, size: 16),
              ),
            )
          else
            Icon(Icons.upload_file_rounded,
                color: color.withOpacity(0.5), size: 20),
        ]),
      ),
    );
  }
}
