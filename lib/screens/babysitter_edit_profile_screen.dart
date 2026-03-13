import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class BabysitterEditProfileScreen extends StatefulWidget {
  final String name;
  final String description;
  final String experience;

  const BabysitterEditProfileScreen({
    super.key,
    required this.name,
    required this.description,
    required this.experience,
  });

  @override
  State<BabysitterEditProfileScreen> createState() =>
      _BabysitterEditProfileScreenState();
}

class _BabysitterEditProfileScreenState
    extends State<BabysitterEditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _expController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;

  final Color primaryColor = const Color(0xFFFF6B8A);
  final Color bgColor = const Color(0xFFFFF8F9);
  final _formKey = GlobalKey<FormState>();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String _currentPhotoUrl = '';
  List<String> _skills = [];

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _descController = TextEditingController(text: widget.description);
    _expController = TextEditingController(text: widget.experience);
    _locationController = TextEditingController();
    _phoneController = TextEditingController();
    _loadExtraFields();
  }

  // ── Load location, phone, photo, skills from Firestore ────────────────────
  Future<void> _loadExtraFields() async {
    final doc =
        await _db.collection('babysitters').doc(_uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _locationController.text = data['location'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _currentPhotoUrl = data['photoUrl'] ?? '';
      _skills = List<String>.from(data['skills'] ?? []);
    });
  }

  // ── Pick photo from gallery or camera ─────────────────────────────────────
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    Navigator.pop(context); // close bottom sheet
    final XFile? picked = await _picker.pickImage(
        source: source, maxWidth: 600, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ref = _storage
          .ref()
          .child('profile_photos')
          .child('$_uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _db.collection('babysitters').doc(_uid).update({
        'photoUrl': url,
      });
      // Keep Auth profile in sync
      await _auth.currentUser?.updatePhotoURL(url);
      setState(() => _currentPhotoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    Navigator.pop(context);
    setState(() => _isUploadingPhoto = true);
    try {
      await _db
          .collection('babysitters')
          .doc(_uid)
          .update({'photoUrl': FieldValue.delete()});
      await _auth.currentUser?.updatePhotoURL(null);
      setState(() => _currentPhotoUrl = '');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Save all fields to Firestore ───────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updates = {
        'fullName': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'experience': _expController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'skills': _skills,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('babysitters')
          .doc(_uid)
          .set(updates, SetOptions(merge: true));

      // Keep Auth displayName in sync
      await _auth.currentUser
          ?.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil mis à jour avec succès!'),
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'experience': _expController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _expController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text('Modifier le profil',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 16),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Informations personnelles',
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nom complet',
                          icon: Icons.person_rounded,
                          validator: (v) => v!.isEmpty
                              ? 'Veuillez entrer votre nom'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _locationController,
                          label: 'Localisation',
                          icon: Icons.location_on_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Téléphone',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Profil professionnel',
                      children: [
                        _buildTextField(
                          controller: _expController,
                          label: "Années d'expérience",
                          icon: Icons.work_rounded,
                          hint: 'Ex: 3 ans',
                          validator: (v) => v!.isEmpty
                              ? 'Veuillez entrer votre expérience'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _descController,
                          label: 'Description / À propos de moi',
                          icon: Icons.description_rounded,
                          maxLines: 4,
                          hint: 'Décrivez-vous en quelques mots...',
                          validator: (v) => v!.isEmpty
                              ? 'Veuillez entrer une description'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Compétences',
                      children: [_buildSkillsEditor()],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : const Text(
                                'Enregistrer les modifications',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo section ──────────────────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showPhotoOptions(context),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.white,
                  child: _isUploadingPhoto
                      ? CircularProgressIndicator(
                          color: primaryColor, strokeWidth: 2)
                      : CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              primaryColor.withOpacity(0.2),
                          backgroundImage: _currentPhotoUrl.isNotEmpty
                              ? NetworkImage(_currentPhotoUrl)
                              : null,
                          child: _currentPhotoUrl.isEmpty
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                )
                              : null,
                        ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: primaryColor,
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Changer la photo de profil',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),
              const Text('Choisir une photo',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.camera_alt_rounded,
                      color: primaryColor),
                ),
                title: const Text('Prendre une photo'),
                onTap: () =>
                    _pickAndUploadPhoto(ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.photo_library_rounded,
                      color: primaryColor),
                ),
                title: const Text('Choisir depuis la galerie'),
                onTap: () =>
                    _pickAndUploadPhoto(ImageSource.gallery),
              ),
              if (_currentPhotoUrl.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEEEE),
                    child: Icon(Icons.delete_rounded,
                        color: Colors.red),
                  ),
                  title: const Text('Supprimer la photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: _deletePhoto,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
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
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.grey[700])),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: primaryColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        labelStyle:
            TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  // ── Skills editor with Firestore-backed list ───────────────────────────────
  Widget _buildSkillsEditor() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._skills.map((s) => Chip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              backgroundColor: primaryColor.withOpacity(0.1),
              labelStyle: TextStyle(color: primaryColor),
              deleteIcon: Icon(Icons.close_rounded,
                  size: 14, color: primaryColor),
              onDeleted: () =>
                  setState(() => _skills.remove(s)),
            )),
        ActionChip(
          avatar: Icon(Icons.add_rounded, color: primaryColor, size: 16),
          label: Text('Ajouter',
              style: TextStyle(color: primaryColor, fontSize: 12)),
          backgroundColor: primaryColor.withOpacity(0.08),
          onPressed: _showAddSkillDialog,
        ),
      ],
    );
  }

  void _showAddSkillDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter une compétence'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: Soins aux nourrissons',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final s = ctrl.text.trim();
              if (s.isNotEmpty && !_skills.contains(s)) {
                setState(() => _skills.add(s));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ajouter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
