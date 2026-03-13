import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────
// SCREEN — Edit babysitter profile fields + photo
// ─────────────────────────────────────────────────────────────
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

  // ── Constants ──────────────────────────────────────────────
  static const _pink = Color(0xFFFF6B8A);
  static const _bg   = Color(0xFFFFF8F9);

  // ── Controllers (one per text field) ──────────────────────
  late final _nameCtrl     = TextEditingController(text: widget.name);
  late final _descCtrl     = TextEditingController(text: widget.description);
  late final _expCtrl      = TextEditingController(text: widget.experience);
  final      _locationCtrl = TextEditingController();
  final      _phoneCtrl    = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // ── Firebase shortcuts ─────────────────────────────────────
  final _auth    = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker  = ImagePicker();

  late final _profileRef = FirebaseFirestore.instance
      .collection('babysitters')
      .doc(_auth.currentUser!.uid);

  // ── Local state ────────────────────────────────────────────
  String       _photoUrl      = '';
  List<String> _skills        = [];
  bool         _saving        = false;
  bool         _uploadingPhoto= false;

  // ──────────────────────────────────────────────────────────
  // LIFECYCLE
  // ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadExtraFields();
  }

  @override
  void dispose() {
    // Always dispose controllers to free memory
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _expCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Load location, phone, photo and skills from Firestore ─
  Future<void> _loadExtraFields() async {
    final doc = await _profileRef.get();
    if (!mounted) return;
    final d = doc.data() ?? {};
    setState(() {
      _locationCtrl.text = d['location'] ?? '';
      _phoneCtrl.text    = d['phone']    ?? '';
      _photoUrl          = d['photoUrl'] ?? '';
      _skills            = List<String>.from(d['skills'] ?? []);
    });
  }

  // ── Pick a photo, upload to Storage, save URL to Firestore ─
  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context); // close the bottom sheet first
    final file = await _picker.pickImage(
        source: source, maxWidth: 600, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final ref = _storage
          .ref()
          .child('profile_photos/${_auth.currentUser!.uid}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      await _profileRef.update({'photoUrl': url});
      await _auth.currentUser?.updatePhotoURL(url);

      setState(() => _photoUrl = url);
    } catch (e) {
      _showSnack('Erreur lors du téléchargement: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Delete profile photo ───────────────────────────────────
  Future<void> _deletePhoto() async {
    Navigator.pop(context);
    setState(() => _uploadingPhoto = true);
    try {
      await _profileRef.update({'photoUrl': FieldValue.delete()});
      await _auth.currentUser?.updatePhotoURL(null);
      setState(() => _photoUrl = '');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Save all fields to Firestore ───────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _profileRef.set({
        'fullName':    _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'experience':  _expCtrl.text.trim(),
        'location':    _locationCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'skills':      _skills,
        'updatedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Keep Firebase Auth display name in sync
      await _auth.currentUser?.updateDisplayName(_nameCtrl.text.trim());

      if (mounted) {
        _showSnack('Profil mis à jour avec succès!');
        Navigator.pop(context, {
          'name':        _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'experience':  _expCtrl.text.trim(),
        });
      }
    } catch (e) {
      _showSnack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Small helper to show a SnackBar message ────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _pink,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _pink,
        elevation: 0,
        title: const Text('Modifier le profil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [

            // ── Photo section ──────────────────────────────
            _PhotoSection(
              photoUrl:      _photoUrl,
              name:          _nameCtrl.text,
              uploading:     _uploadingPhoto,
              onTap:         () => _showPhotoSheet(),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [

                // ── Personal info fields ───────────────────
                _FormSection(
                  title: 'Informations personnelles',
                  children: [
                    _Field(ctrl: _nameCtrl,     label: 'Nom complet',  icon: Icons.person_rounded,
                        validator: (v) => v!.isEmpty ? 'Champ requis' : null),
                    _Field(ctrl: _locationCtrl, label: 'Localisation', icon: Icons.location_on_rounded),
                    _Field(ctrl: _phoneCtrl,    label: 'Téléphone',    icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Professional info fields ───────────────
                _FormSection(
                  title: 'Profil professionnel',
                  children: [
                    _Field(ctrl: _expCtrl,  label: "Années d'expérience", icon: Icons.work_rounded,
                        hint: 'Ex: 3 ans',
                        validator: (v) => v!.isEmpty ? 'Champ requis' : null),
                    _Field(ctrl: _descCtrl, label: 'Description',          icon: Icons.description_rounded,
                        maxLines: 4, hint: 'Décrivez-vous...',
                        validator: (v) => v!.isEmpty ? 'Champ requis' : null),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Skills editor ──────────────────────────
                _FormSection(
                  title: 'Compétences',
                  children: [
                    _SkillsEditor(
                      skills:   _skills,
                      color:    _pink,
                      onDelete: (s) => setState(() => _skills.remove(s)),
                      onAdd:    (s) => setState(() => _skills.add(s)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Save button ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text('Enregistrer les modifications',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Bottom sheet for photo source selection ────────────────
  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 20),
            const Text('Choisir une photo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _pink.withOpacity(0.1),
                child: Icon(Icons.camera_alt_rounded, color: _pink),
              ),
              title: const Text('Prendre une photo'),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _pink.withOpacity(0.1),
                child: Icon(Icons.photo_library_rounded, color: _pink),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            if (_photoUrl.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEEEE),
                  child: Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: Colors.red)),
                onTap: _deletePhoto,
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

// Pink header with circular avatar + camera tap
class _PhotoSection extends StatelessWidget {
  final String photoUrl;
  final String name;
  final bool uploading;
  final VoidCallback onTap;
  const _PhotoSection({
    required this.photoUrl,
    required this.name,
    required this.uploading,
    required this.onTap,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: const BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.white,
              child: uploading
                  ? const CircularProgressIndicator(
                      color: _pink, strokeWidth: 2)
                  : CircleAvatar(
                      radius: 50,
                      backgroundColor: _pink.withOpacity(0.2),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            )
                          : null,
                    ),
            ),
            // Camera icon badge
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: _pink,
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Changer la photo de profil',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }
}

// Card wrapper with a section title for grouping form fields
class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormSection({required this.title, required this.children});

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
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.grey[700])),
            const SizedBox(height: 14),
            // Space out each child field
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

// Single text form field with icon, label and optional hint
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  static const _pink = Color(0xFFFF6B8A);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _pink, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _pink, width: 1.5)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }
}

// Skill chips with delete buttons + an "Add" chip
class _SkillsEditor extends StatelessWidget {
  final List<String> skills;
  final Color color;
  final void Function(String) onDelete;
  final void Function(String) onAdd;

  const _SkillsEditor({
    required this.skills,
    required this.color,
    required this.onDelete,
    required this.onAdd,
  });

  void _showAddDialog(BuildContext context) {
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
              if (s.isNotEmpty) onAdd(s);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing skills with a delete (×) button
        ...skills.map((s) => Chip(
          label: Text(s, style: const TextStyle(fontSize: 12)),
          backgroundColor: color.withOpacity(0.1),
          labelStyle: TextStyle(color: color),
          deleteIcon: Icon(Icons.close_rounded, size: 14, color: color),
          onDeleted: () => onDelete(s),
        )),
        // Add new skill chip
        ActionChip(
          avatar: Icon(Icons.add_rounded, color: color, size: 16),
          label: Text('Ajouter',
              style: TextStyle(color: color, fontSize: 12)),
          backgroundColor: color.withOpacity(0.08),
          onPressed: () => _showAddDialog(context),
        ),
      ],
    );
  }
}
