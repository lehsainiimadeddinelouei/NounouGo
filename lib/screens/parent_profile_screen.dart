import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'role_selection_screen.dart';
import 'payment_screen.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});
  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isUploadingPhoto = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String _prenom = '', _nom = '', _email = '', _phone = '';
  String? _photoBase64; // photo stockée en base64

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _loadProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    _prenomController.dispose();
    _nomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _prenom = data['prenom'] ?? '';
          _nom = data['nom'] ?? '';
          _email = data['email'] ?? '';
          _phone = data['phone'] ?? '';
          _photoBase64 = data['photoBase64'];
          _prenomController.text = _prenom;
          _nomController.text = _nom;
          _phoneController.text = _phone;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).update({
        'prenom': _prenomController.text.trim(),
        'nom': _nomController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      setState(() {
        _prenom = _prenomController.text.trim();
        _nom = _nomController.text.trim();
        _phone = _phoneController.text.trim();
        _isEditing = false;
        _isSaving = false;
      });
      _showSnack('Profil mis à jour !', isError: false);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Erreur lors de la sauvegarde.');
    }
  }

  // ── Upload photo → base64 → Firestore ──
  Future<void> _pickAndUploadPhoto() async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 300,   // petite taille pour base64
        maxHeight: 300,
        imageQuality: 60,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      // Convertir en base64
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);

      // Vérifier la taille (Firestore limite à 1MB par document)
      if (base64String.length > 900000) {
        setState(() => _isUploadingPhoto = false);
        _showSnack('Image trop grande. Choisissez une image plus petite.');
        return;
      }

      // Sauvegarder dans Firestore
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).update({'photoBase64': base64String});

      setState(() {
        _photoBase64 = base64String;
        _isUploadingPhoto = false;
      });

      _showSnack('Photo mise à jour !', isError: false);
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      _showSnack('Erreur : $e');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.inputBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Choisir une photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _SourceOption(
              icon: Icons.camera_alt_rounded, label: 'Caméra', color: AppColors.buttonBlue,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            )),
            const SizedBox(width: 16),
            Expanded(child: _SourceOption(
              icon: Icons.photo_library_rounded, label: 'Galerie', color: AppColors.primaryPink,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            )),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Changer le mot de passe ──
  Future<void> _showChangePasswordDialog() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? errorMessage;
    bool obscureCurrent = true, obscureNew = true, obscureConfirm = true;
    bool isLoading = false;
    bool passwordChanged = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => WillPopScope(
          onWillPop: () async => !isLoading,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Changer le mot de passe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Colors.red))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                _DialogPasswordField(
                    controller: currentPassCtrl, hint: 'Mot de passe actuel',
                    obscure: obscureCurrent,
                    onToggle: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    accentColor: AppColors.buttonBlue),
                const SizedBox(height: 12),
                _DialogPasswordField(
                    controller: newPassCtrl, hint: 'Nouveau mot de passe',
                    obscure: obscureNew,
                    onToggle: () => setDialogState(() => obscureNew = !obscureNew),
                    accentColor: AppColors.buttonBlue),
                const SizedBox(height: 12),
                _DialogPasswordField(
                    controller: confirmPassCtrl, hint: 'Confirmer le nouveau',
                    obscure: obscureConfirm,
                    onToggle: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    accentColor: AppColors.buttonBlue),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: isLoading ? null : () async {
                  if (currentPassCtrl.text.isEmpty || newPassCtrl.text.isEmpty || confirmPassCtrl.text.isEmpty) {
                    setDialogState(() => errorMessage = 'Remplissez tous les champs.'); return;
                  }
                  if (newPassCtrl.text != confirmPassCtrl.text) {
                    setDialogState(() => errorMessage = 'Les mots de passe ne correspondent pas.'); return;
                  }
                  if (newPassCtrl.text.length < 6) {
                    setDialogState(() => errorMessage = 'Minimum 6 caractères.'); return;
                  }
                  setDialogState(() { isLoading = true; errorMessage = null; });
                  try {
                    final user = _auth.currentUser!;
                    final cred = EmailAuthProvider.credential(
                        email: user.email!, password: currentPassCtrl.text);
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPassCtrl.text);
                    passwordChanged = true;
                    // Fermer dialog immédiatement
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() {
                      isLoading = false;
                      errorMessage = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                          ? 'Mot de passe actuel incorrect.'
                          : 'Erreur : ${e.message}';
                    });
                  } catch (e) {
                    setDialogState(() { isLoading = false; errorMessage = 'Erreur inattendue.'; });
                  }
                },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.buttonBlue))
                    : const Text('Confirmer',
                        style: TextStyle(color: AppColors.buttonBlue, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );

    currentPassCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();

    // Si succès → déconnecter et retourner au login
    if (passwordChanged && mounted) {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    }
  }


  Future<void> _showDeleteAccountDialog() async {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => PopScope(
          canPop: !isLoading,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Expanded(child: Text('Supprimer le compte',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red))),
            ]),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Text('⚠️ Action irréversible. Toutes vos données seront supprimées définitivement.',
                    style: TextStyle(fontSize: 13, color: Colors.red, height: 1.4), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 14),
              if (errorMessage != null) ...[
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(errorMessage!, style: const TextStyle(fontSize: 13, color: Colors.red))),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: passwordCtrl, obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Confirmez avec votre mot de passe',
                  filled: true, fillColor: const Color(0xFFFFF5F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                  suffixIcon: GestureDetector(onTap: () => setD(() => obscure = !obscure),
                      child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey, size: 20)),
                ),
              ),
            ])),
            actions: [
              TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600))),
              TextButton(
                onPressed: isLoading ? null : () async {
                  if (passwordCtrl.text.isEmpty) {
                    setD(() => errorMessage = 'Saisissez votre mot de passe.'); return;
                  }
                  setD(() { isLoading = true; errorMessage = null; });
                  try {
                    final user = _auth.currentUser!;
                    final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
                    await user.reauthenticateWithCredential(cred);
                    await _db.collection('users').doc(user.uid).delete();
                    await user.delete();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } on FirebaseAuthException catch (e) {
                    setD(() { isLoading = false;
                      errorMessage = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                          ? 'Mot de passe incorrect.' : 'Erreur : \${e.message}';
                    });
                  } catch (e) { setD(() { isLoading = false; errorMessage = 'Erreur inattendue.'; }); }
                },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
    passwordCtrl.dispose();
    if (_auth.currentUser == null && mounted) {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ), (route) => false);
    }
  }


  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(color: AppColors.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textGrey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ), (route) => false);
              }
            },
            child: const Text('Déconnecter',
                style: TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.primaryPink : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String get _initiales =>
      '${_prenom.isNotEmpty ? _prenom[0].toUpperCase() : ''}${_nom.isNotEmpty ? _nom[0].toUpperCase() : ''}';

  // ── Widget avatar ──
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickAndUploadPhoto,
      child: Stack(children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            color: Colors.white.withOpacity(0.2),
          ),
          child: _isUploadingPhoto
              ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : ClipOval(
                  child: _photoBase64 != null
                      ? Image.memory(base64Decode(_photoBase64!), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(_initiales,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))))
                      : Center(child: Text(_initiales,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
        ),
        Positioned(bottom: 0, right: 0,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: AppColors.primaryPink, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(20),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.backgroundGradientStart, AppColors.backgroundGradientEnd]),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.buttonBlue))
            : FadeTransition(
                opacity: _fadeAnim,
                child: CustomScrollView(slivers: [
                  // ── AppBar ──
                  SliverAppBar(
                    expandedHeight: 240, pinned: true,
                    backgroundColor: AppColors.buttonBlue,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, color: Colors.white),
                        onPressed: () => setState(() {
                          _isEditing = !_isEditing;
                          if (!_isEditing) {
                            _prenomController.text = _prenom;
                            _nomController.text = _nom;
                            _phoneController.text = _phone;
                          }
                        }),
                      ),
                      IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [AppColors.primaryBlue, AppColors.buttonBlue]),
                        ),
                        child: SafeArea(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(height: 30),
                            _buildAvatar(),
                            const SizedBox(height: 12),
                            Text('$_prenom $_nom',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.family_restroom, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Parent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // ── Contenu ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        _SectionTitle(label: 'Informations personnelles'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(children: [
                            if (_isEditing) ...[
                              Row(children: [
                                Expanded(child: CustomTextField(controller: _prenomController, hintText: 'Prénom',
                                    prefixIcon: Icons.person_outline_rounded, accentColor: AppColors.buttonBlue)),
                                const SizedBox(width: 12),
                                Expanded(child: CustomTextField(controller: _nomController, hintText: 'Nom',
                                    prefixIcon: Icons.badge_outlined, accentColor: AppColors.buttonBlue)),
                              ]),
                              const SizedBox(height: 14),
                              CustomTextField(controller: _phoneController, hintText: 'Téléphone',
                                  prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone,
                                  accentColor: AppColors.buttonBlue),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: AppColors.backgroundGradientEnd, borderRadius: BorderRadius.circular(14)),
                                child: Row(children: [
                                  const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textGrey),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Email', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                    Text(_email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ])),
                                  const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textGrey),
                                ]),
                              ),
                            ] else ...[
                              _InfoRow(icon: Icons.person_outline_rounded, label: 'Prénom', value: _prenom),
                              const _Divider(),
                              _InfoRow(icon: Icons.badge_outlined, label: 'Nom', value: _nom),
                              const _Divider(),
                              _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: _email),
                              const _Divider(),
                              _InfoRow(icon: Icons.phone_outlined, label: 'Téléphone',
                                  value: _phone.isNotEmpty ? _phone : 'Non renseigné'),
                            ],
                          ]),
                        ),

                        if (_isEditing) ...[
                          const SizedBox(height: 16),
                          CustomButton(label: 'Sauvegarder', onTap: _saveProfile,
                              isLoading: _isSaving, color: AppColors.buttonBlue),
                        ],

                        const SizedBox(height: 24),

                        _SectionTitle(label: 'Paiements'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    child: _ActionRow(
                      icon: Icons.history_rounded,
                      label: 'Historique des paiements',
                      color: AppColors.buttonBlue,
                      onTap: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const HistoriquePaiementsScreen(role: 'Parent'),
                        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 350),
                      )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(label: 'Sécurité'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: _cardDecoration(),
                          child: Column(children: [
                            _ActionRow(icon: Icons.lock_outline_rounded, label: 'Changer le mot de passe',
                                color: AppColors.buttonBlue, onTap: _showChangePasswordDialog),
                            const _Divider(),
                            _ActionRow(
                              icon: Icons.verified_user_outlined, label: 'Vérification email',
                              color: Colors.green,
                              trailing: _auth.currentUser?.emailVerified == true
                                  ? _Badge(label: 'Vérifié ✓', color: Colors.green)
                                  : _Badge(label: 'En attente', color: Colors.orange),
                              onTap: () {},
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryPink.withOpacity(0.3), width: 1.5),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.logout_rounded, color: AppColors.primaryPink, size: 20),
                              SizedBox(width: 10),
                              Text('Se déconnecter',
                                  style: TextStyle(fontSize: 15, color: AppColors.primaryPink, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _showDeleteAccountDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withOpacity(0.25), width: 1.5),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 10),
                              Text('Supprimer mon compte',
                                  style: TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ── Widgets helper ──
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2));
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.buttonBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.buttonBlue)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, color: AppColors.textDark, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final String label; final Color color; final Widget? trailing; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, this.trailing, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textDark, fontWeight: FontWeight.w600))),
        trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textGrey),
      ]),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: Color(0xFFF5EEF0), indent: 16, endIndent: 16);
}

class _SourceOption extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _SourceOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

class _DialogPasswordField extends StatelessWidget {
  final TextEditingController controller; final String hint; final bool obscure;
  final VoidCallback onToggle; final Color accentColor;
  const _DialogPasswordField({required this.controller, required this.hint, required this.obscure, required this.onToggle, required this.accentColor});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
      filled: true, fillColor: AppColors.lightPink,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: GestureDetector(onTap: onToggle,
          child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textGrey, size: 20)),
    ),
  );
}
