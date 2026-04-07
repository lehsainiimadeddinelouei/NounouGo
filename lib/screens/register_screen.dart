import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import 'babysitter_setup_screen.dart';
import 'parent_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({super.key, required this.role});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _prenomController          = TextEditingController();
  final _nomController             = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _acceptCGU      = false;
  final Set<String> _selectedAgeGroups = {};

  // ── Documents Babysitter (obligatoires) ──
  String? _diplomeB64; String? _diplomeNom;
  String? _cvB64;      String? _cvNom;
  String? _cniB64;     String? _cniNom;
  String? _cnasB64;    String? _cnasNom;
  String? _santeB64;   String? _santeNom;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _prenomController.dispose(); _nomController.dispose();
    _emailController.dispose();  _phoneController.dispose();
    _passwordController.dispose(); _confirmPasswordController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.primaryPink : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));

  Future<void> _pickDoc(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) { _snack('Impossible de lire le fichier.'); return; }
      // Vérifier taille: Firestore limite 1MB/doc, base64 augmente de 33%
      if (bytes.lengthInBytes > 900 * 1024) {
        _snack('❌ Fichier trop volumineux (max 900 KB). Compressez votre document.');
        return;
      }
      final b64 = base64Encode(bytes);
      setState(() {
        if (type == 'diplome') { _diplomeB64 = b64; _diplomeNom = f.name; }
        if (type == 'cv')      { _cvB64 = b64;      _cvNom = f.name; }
        if (type == 'cni')     { _cniB64 = b64;      _cniNom = f.name; }
        if (type == 'cnas')    { _cnasB64 = b64;     _cnasNom = f.name; }
        if (type == 'sante')   { _santeB64 = b64;    _santeNom = f.name; }
      });
    } catch (e) {
      _snack('Erreur: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (_prenomController.text.trim().isEmpty || _nomController.text.trim().isEmpty) {
      _snack('Veuillez saisir votre prénom et nom.'); return;
    }
    if (_emailController.text.trim().isEmpty) {
      _snack('Veuillez saisir votre email.'); return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _snack('Les mots de passe ne correspondent pas.'); return;
    }
    if (_passwordController.text.length < 6) {
      _snack('Le mot de passe doit contenir au moins 6 caractères.'); return;
    }
    if (!_acceptCGU) {
      _snack("Veuillez accepter les conditions d'utilisation."); return;
    }
    // ── Vérification documents obligatoires ──
    if (widget.role == 'Babysitter') {
      if (_diplomeB64 == null) { _snack('📄 Le diplôme est obligatoire.'); return; }
      if (_cvB64 == null)      { _snack("📄 Le CV est obligatoire."); return; }
      if (_cniB64 == null)     { _snack("🪪 La carte d'identité est obligatoire."); return; }
      if (_cnasB64 == null)    { _snack('📄 La CNAS est obligatoire.'); return; }
      if (_santeB64 == null)   { _snack('📄 Le certificat de bonne santé mentale est obligatoire.'); return; }
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      prenom: _prenomController.text, nom: _nomController.text,
      email: _emailController.text,   password: _passwordController.text,
      phone: _phoneController.text,   role: widget.role,
      ageGroups: _selectedAgeGroups.toList(),
    );

    if (!result.success) {
      setState(() => _isLoading = false);
      _snack(result.message);
      return;
    }

    // ── Envoyer les documents dans Firestore → sous-collection séparée ──
    if (widget.role == 'Babysitter') {
      try {
        // Attendre que le token Firebase Auth soit propagé
        await Future.delayed(const Duration(seconds: 2));
        await FirebaseAuth.instance.currentUser?.reload();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw Exception('Utilisateur non connecté');

        final docsRef = FirebaseFirestore.instance
            .collection('users').doc(uid).collection('documents');

        // Diplôme
        try {
          await docsRef.doc('diplome').set({
            'base64': _diplomeB64,
            'name': _diplomeNom,
            'statut': 'en_attente',
            'type': 'diplome',
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          _snack('✅ Diplôme envoyé (${(_diplomeB64!.length / 1024).toStringAsFixed(0)} KB)');
        } catch (e) {
          throw Exception('Échec diplôme (${(_diplomeB64!.length / 1024).toStringAsFixed(0)} KB): $e');
        }

        // CV
        try {
          await docsRef.doc('cv').set({
            'base64': _cvB64,
            'name': _cvNom,
            'statut': 'en_attente',
            'type': 'cv',
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          _snack('✅ CV envoyé (${(_cvB64!.length / 1024).toStringAsFixed(0)} KB)');
        } catch (e) {
          throw Exception('Échec CV (${(_cvB64!.length / 1024).toStringAsFixed(0)} KB): $e');
        }

        // CNI
        try {
          await docsRef.doc('cni').set({
            'base64': _cniB64,
            'name': _cniNom,
            'statut': 'en_attente',
            'type': 'cni',
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          _snack('✅ CNI envoyé (${(_cniB64!.length / 1024).toStringAsFixed(0)} KB)');
        } catch (e) {
          throw Exception('Échec CNI (${(_cniB64!.length / 1024).toStringAsFixed(0)} KB): $e');
        }

        // CNAS
        try {
          await docsRef.doc('cnas').set({
            'base64': _cnasB64,
            'name': _cnasNom,
            'statut': 'en_attente',
            'type': 'cnas',
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          _snack('✅ CNAS envoyée (${(_cnasB64!.length / 1024).toStringAsFixed(0)} KB)');
        } catch (e) {
          throw Exception('Échec CNAS (${(_cnasB64!.length / 1024).toStringAsFixed(0)} KB): $e');
        }

        // Certificat santé mentale
        try {
          await docsRef.doc('sante').set({
            'base64': _santeB64,
            'name': _santeNom,
            'statut': 'en_attente',
            'type': 'sante',
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          _snack('✅ Certificat santé envoyé (${(_santeB64!.length / 1024).toStringAsFixed(0)} KB)');
        } catch (e) {
          throw Exception('Échec certificat santé (${(_santeB64!.length / 1024).toStringAsFixed(0)} KB): $e');
        }

        // Mettre à jour le doc principal
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'diplomePdfName': _diplomeNom,
          'diplomePdfStatut': 'en_attente',
          'cvName': _cvNom,
          'cvStatut': 'en_attente',
          'cniName': _cniNom,
          'cniStatut': 'en_attente',
          'cnasName': _cnasNom,
          'cnasStatut': 'en_attente',
          'santeNom': _santeNom,
          'santeStatut': 'en_attente',
          'hasDocuments': true,
        });

      } catch (e) {
        setState(() => _isLoading = false);
        _snack('Erreur upload documents: $e');
        return;
      }
    }

    setState(() => _isLoading = false);
    _snack(result.message, isError: false);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (widget.role == 'Babysitter') {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const BabysitterSetupScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ), (r) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ParentHomeScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'Parent';
    final accent   = isParent ? AppColors.buttonBlue : AppColors.primaryPink;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
        )),
        child: SafeArea(child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),

              // ── Bouton retour ──
              Align(alignment: Alignment.centerLeft,
                  child: GestureDetector(onTap: () => Navigator.pop(context),
                      child: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark)))),
              const SizedBox(height: 28),

              // ── Titre ──
              const Text('Créer un compte',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isParent ? Icons.family_restroom : Icons.child_care, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Text(widget.role, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                ]),
              )),
              const SizedBox(height: 28),

              // ── Informations personnelles ──
              _SectionLabel(label: 'Informations personnelles'),
              const SizedBox(height: 12),
              _WhiteCard(child: Column(children: [
                Row(children: [
                  Expanded(child: CustomTextField(controller: _prenomController, hintText: 'Prénom', prefixIcon: Icons.person_outline_rounded, accentColor: accent)),
                  const SizedBox(width: 12),
                  Expanded(child: CustomTextField(controller: _nomController, hintText: 'Nom', prefixIcon: Icons.badge_outlined, accentColor: accent)),
                ]),
                const SizedBox(height: 14),
                CustomTextField(controller: _emailController, hintText: 'Adresse email', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, accentColor: accent),
                const SizedBox(height: 14),
                CustomTextField(controller: _phoneController, hintText: 'Numéro de téléphone', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone, accentColor: accent),
              ])),
              const SizedBox(height: 20),

              // ── Documents obligatoires (Babysitter uniquement) ──
              if (!isParent) ...[
                _SectionLabel(label: 'Documents obligatoires'),
                const SizedBox(height: 8),
                // Bandeau informatif
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, color: accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      "Ces 5 documents sont transmis directement à l'administrateur pour validation. "
                          "Sans validation, vous ne pourrez pas travailler. Formats acceptés: PDF, JPG, PNG.",
                      style: TextStyle(fontSize: 12, color: accent, height: 1.5),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                _WhiteCard(child: Column(children: [
                  _DocPicker(
                    label: 'Diplôme (BAFA, CAP petite enfance...)',
                    icon: Icons.school_rounded,
                    color: AppColors.primaryPink,
                    fileName: _diplomeNom,
                    onTap: () => _pickDoc('diplome'),
                  ),
                  const SizedBox(height: 12),
                  _DocPicker(
                    label: 'CV',
                    icon: Icons.description_rounded,
                    color: AppColors.buttonBlue,
                    fileName: _cvNom,
                    onTap: () => _pickDoc('cv'),
                  ),
                  const SizedBox(height: 12),
                  _DocPicker(
                    label: "Carte nationale d'identité",
                    icon: Icons.badge_rounded,
                    color: Colors.teal,
                    fileName: _cniNom,
                    onTap: () => _pickDoc('cni'),
                  ),
                  const SizedBox(height: 12),
                  _DocPicker(
                    label: 'Attestation CNAS',
                    icon: Icons.health_and_safety_rounded,
                    color: Colors.green,
                    fileName: _cnasNom,
                    onTap: () => _pickDoc('cnas'),
                  ),
                  const SizedBox(height: 12),
                  _DocPicker(
                    label: 'Certificat mentale',
                    icon: Icons.psychology_rounded,
                    color: Colors.purple,
                    fileName: _santeNom,
                    onTap: () => _pickDoc('sante'),
                  ),
                ])),
                const SizedBox(height: 20),
              ],

              // ── Sécurité ──
              _SectionLabel(label: 'Sécurité'),
              const SizedBox(height: 12),
              _WhiteCard(child: Column(children: [
                CustomTextField(
                  controller: _passwordController, hintText: 'Mot de passe',
                  prefixIcon: Icons.lock_outline_rounded, obscureText: _obscurePass, accentColor: accent,
                  suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscurePass = !_obscurePass),
                      child: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryPink, size: 20)),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _confirmPasswordController, hintText: 'Confirmer le mot de passe',
                  prefixIcon: Icons.lock_outline_rounded, obscureText: _obscureConfirm, accentColor: accent,
                  suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryPink, size: 20)),
                ),
                const SizedBox(height: 10),
                _PasswordStrengthIndicator(controller: _passwordController, accentColor: accent),
              ])),
              const SizedBox(height: 20),

              // ── CGU ──
              GestureDetector(
                onTap: () => setState(() => _acceptCGU = !_acceptCGU),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _acceptCGU ? accent : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _acceptCGU ? accent : AppColors.inputBorder, width: 2),
                    ),
                    child: _acceptCGU ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: RichText(text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                    children: [
                      const TextSpan(text: "J'accepte les "),
                      TextSpan(text: "Conditions d'utilisation", style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' et la '),
                      TextSpan(text: 'Politique de confidentialité', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                    ],
                  ))),
                ]),
              ),
              const SizedBox(height: 28),
              CustomButton(label: 'Créer mon compte', onTap: _handleRegister, isLoading: _isLoading, color: accent),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Déjà un compte ? ', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Se connecter', style: TextStyle(fontSize: 14, color: accent, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 40),
            ]),
          ),
        ))),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Widgets utilitaires
// ═══════════════════════════════════════════════

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: child,
  );
}

class _DocPicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? fileName;
  final VoidCallback onTap;
  const _DocPicker({required this.label, required this.icon, required this.color, required this.fileName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = fileName != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: done ? color.withOpacity(0.07) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? color.withOpacity(0.5) : Colors.orange.withOpacity(0.45),
            width: done ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: done ? color : AppColors.textDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(' *', style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 3),
            Text(done ? '✓  $fileName' : 'Appuyer pour sélectionner...',
                style: TextStyle(fontSize: 11, color: done ? color.withOpacity(0.75) : AppColors.textGrey),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 10),
          Icon(done ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              color: done ? color : Colors.orange.shade300, size: 24),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2));
}

class _PasswordStrengthIndicator extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;
  const _PasswordStrengthIndicator({required this.controller, required this.accentColor});
  @override
  State<_PasswordStrengthIndicator> createState() => _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState extends State<_PasswordStrengthIndicator> {
  int _strength = 0;
  @override
  void initState() { super.initState(); widget.controller.addListener(_evaluate); }
  void _evaluate() {
    final p = widget.controller.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    setState(() => _strength = s);
  }
  @override
  void dispose() { widget.controller.removeListener(_evaluate); super.dispose(); }
  Color get _barColor { if (_strength <= 1) return const Color(0xFFFF6B6B); if (_strength == 2) return const Color(0xFFFFB347); if (_strength == 3) return const Color(0xFF7BC67E); return const Color(0xFF4CAF50); }
  String get _label { if (_strength == 0) return ''; if (_strength <= 1) return 'Faible'; if (_strength == 2) return 'Moyen'; if (_strength == 3) return 'Fort'; return 'Très fort'; }
  @override
  Widget build(BuildContext context) {
    if (_strength == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: List.generate(4, (i) => Expanded(child: Container(
        margin: EdgeInsets.only(right: i < 3 ? 4 : 0), height: 4,
        decoration: BoxDecoration(color: i < _strength ? _barColor : AppColors.inputBorder, borderRadius: BorderRadius.circular(2)),
      )))),
      const SizedBox(height: 4),
      Text(_label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _barColor)),
    ]);
  }
}