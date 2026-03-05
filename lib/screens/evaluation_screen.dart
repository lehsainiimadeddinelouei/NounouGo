import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class EvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> demandeData;
  final String demandeId;

  const EvaluationScreen({
    super.key,
    required this.demandeData,
    required this.demandeId,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _commentCtrl = TextEditingController();

  // Note globale
  double _noteGlobale = 0;

  // Critères
  final Map<String, double> _criteres = {
    'Ponctualité': 0,
    'Sérieux': 0,
    'Bienveillance': 0,
    'Communication': 0,
  };

  final Map<String, IconData> _criteresIcons = {
    'Ponctualité': Icons.access_time_rounded,
    'Sérieux': Icons.verified_user_outlined,
    'Bienveillance': Icons.favorite_border_rounded,
    'Communication': Icons.chat_bubble_outline_rounded,
  };

  bool _isSubmitting = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _nounouPrenom => widget.demandeData['nounouPrenom'] ?? '';
  String get _nounouNom => widget.demandeData['nounouNom'] ?? '';
  String get _nounouUid => widget.demandeData['nounouUid'] ?? '';
  String? get _nounouPhoto => widget.demandeData['nounouPhotoBase64'] as String?;

  String _noteLabel() {
    if (_noteGlobale == 0) return 'Appuyez pour noter';
    if (_noteGlobale <= 1) return 'Très insuffisant 😞';
    if (_noteGlobale <= 2) return 'Insuffisant 😕';
    if (_noteGlobale <= 3) return 'Bien 🙂';
    if (_noteGlobale <= 4) return 'Très bien 😊';
    return 'Excellent ! 🌟';
  }

  Color _noteColor() {
    if (_noteGlobale == 0) return AppColors.textGrey;
    if (_noteGlobale <= 2) return Colors.red;
    if (_noteGlobale <= 3) return Colors.orange;
    if (_noteGlobale <= 4) return AppColors.buttonBlue;
    return Colors.green;
  }

  double get _moyenneCriteres {
    final vals = _criteres.values.where((v) => v > 0).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  Future<void> _submit() async {
    if (_noteGlobale == 0) {
      _showSnack('Donnez au moins une note globale.'); return;
    }
    if (_commentCtrl.text.trim().isEmpty) {
      _showSnack('Ajoutez un commentaire.'); return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = _auth.currentUser!.uid;
      final now = FieldValue.serverTimestamp();

      // Note finale = moyenne note globale + critères
      final noteCriteres = _moyenneCriteres;
      final notefinale = noteCriteres > 0
          ? (_noteGlobale + noteCriteres) / 2
          : _noteGlobale;

      // 1. Enregistrer l'avis
      await _db.collection('avis').add({
        'demandeId': widget.demandeId,
        'parentUid': uid,
        'parentPrenom': widget.demandeData['parentPrenom'] ?? '',
        'parentNom': widget.demandeData['parentNom'] ?? '',
        'nounouUid': _nounouUid,
        'noteGlobale': _noteGlobale,
        'criteres': _criteres,
        'noteCriteres': noteCriteres,
        'notefinale': notefinale,
        'commentaire': _commentCtrl.text.trim(),
        'dateGarde': widget.demandeData['dateTime'],
        'createdAt': now,
      });

      // 2. Mettre à jour score moyen de la nounou
      final avisSnap = await _db
          .collection('avis')
          .where('nounouUid', isEqualTo: _nounouUid)
          .get();
      final notes = avisSnap.docs
          .map((d) => (d.data()['notefinale'] ?? 0).toDouble())
          .toList();
      final scoreMoyen = notes.isEmpty
          ? notefinale
          : notes.reduce((a, b) => a + b) / notes.length;

      await _db.collection('users').doc(_nounouUid).update({
        'score': double.parse(scoreMoyen.toStringAsFixed(1)),
        'nbAvis': notes.length,
      });

      // 3. Marquer la demande comme évaluée
      await _db.collection('demandes').doc(widget.demandeId).update({
        'evaluee': true,
      });

      // 4. Notifier la nounou
      await _db.collection('notifications').add({
        'destinataireUid': _nounouUid,
        'type': 'nouvel_avis',
        'titre': '⭐ Nouvel avis reçu',
        'message':
            '${widget.demandeData['parentPrenom']} vous a donné ${notefinale.toStringAsFixed(1)}/5 ✨',
        'lu': false,
        'createdAt': now,
      });

      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => _EvaluationSuccessScreen(
            note: notefinale,
            nounouPrenom: _nounouPrenom,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnack('Erreur : $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primaryPink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(slivers: [

            // ── AppBar ──
            SliverAppBar(
              pinned: true, expandedHeight: 100,
              backgroundColor: AppColors.primaryPink,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: AppColors.textDark),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8FAB), AppColors.primaryPink],
                    ),
                  ),
                  child: SafeArea(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const SizedBox(height: 20),
                    const Icon(Icons.star_rounded, color: Colors.white, size: 26),
                    const SizedBox(height: 6),
                    const Text('Évaluer la garde',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w800, color: Colors.white)),
                  ])),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Carte nounou ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryPink.withOpacity(0.3),
                                width: 2)),
                        child: ClipOval(child: _nounouPhoto != null
                            ? Image.memory(base64Decode(_nounouPhoto!),
                            fit: BoxFit.cover)
                            : Container(
                            color: AppColors.lightPink,
                            child: Center(child: Text(
                              '${_nounouPrenom.isNotEmpty ? _nounouPrenom[0] : ''}${_nounouNom.isNotEmpty ? _nounouNom[0] : ''}',
                              style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryPink),
                            )))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('$_nounouPrenom $_nounouNom',
                            style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        Text('Garde effectuée ✓',
                            style: TextStyle(fontSize: 13,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600)),
                      ])),
                      const Icon(Icons.verified_rounded,
                          color: AppColors.primaryPink, size: 24),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Note globale ──
                  const _SectionTitle(label: '⭐ Note globale'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Column(children: [
                      _StarRating(
                        value: _noteGlobale,
                        size: 44,
                        onChanged: (v) => setState(() => _noteGlobale = v),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(_noteLabel(),
                          key: ValueKey(_noteGlobale),
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _noteColor()),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Critères ──
                  const _SectionTitle(label: '📊 Critères détaillés'),
                  const SizedBox(height: 4),
                  const Text('Optionnel — affine la note globale',
                      style: TextStyle(fontSize: 12,
                          color: AppColors.textGrey)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: _criteres.entries.map((entry) =>
                          _CritereRow(
                            icon: _criteresIcons[entry.key]!,
                            label: entry.key,
                            value: entry.value,
                            onChanged: (v) =>
                                setState(() => _criteres[entry.key] = v),
                          )).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Commentaire ──
                  const _SectionTitle(label: '💬 Commentaire'),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _commentCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 14,
                          color: AppColors.textDark, height: 1.5),
                      decoration: InputDecoration(
                        hintText:
                            'Partagez votre expérience avec cette nounou...',
                        hintStyle: const TextStyle(
                            color: AppColors.textGrey, fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Bouton envoyer ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Envoi...' : 'Publier l\'évaluation',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        disabledBackgroundColor:
                            AppColors.primaryPink.withOpacity(0.5),
                      ),
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

// ── Étoiles interactives ──
class _StarRating extends StatelessWidget {
  final double value;
  final double size;
  final Function(double) onChanged;

  const _StarRating({
    required this.value, required this.size, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(5, (i) {
      final starVal = i + 1.0;
      return GestureDetector(
        onTap: () => onChanged(starVal),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: value >= starVal ? 1.1 : 1.0),
          duration: const Duration(milliseconds: 200),
          builder: (_, scale, child) => Transform.scale(
              scale: scale, child: child),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              value >= starVal ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: value >= starVal ? Colors.amber : AppColors.inputBorder,
            ),
          ),
        ),
      );
    }),
  );
}

// ── Ligne critère ──
class _CritereRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Function(double) onChanged;

  const _CritereRow({
    required this.icon, required this.label,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryPink.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: AppColors.primaryPink),
      ),
      const SizedBox(width: 12),
      SizedBox(width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.textDark))),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(5, (i) {
            final starVal = i + 1.0;
            return GestureDetector(
              onTap: () => onChanged(starVal),
              child: Icon(
                value >= starVal
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 26,
                color: value >= starVal ? Colors.amber : AppColors.inputBorder,
              ),
            );
          }),
        ),
      ),
    ]),
  );
}

// ── Écran succès ──
class _EvaluationSuccessScreen extends StatelessWidget {
  final double note;
  final String nounouPrenom;
  const _EvaluationSuccessScreen(
      {required this.note, required this.nounouPrenom});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 56),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Merci ! ✨',
                style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.w900, color: AppColors.textDark)),
            const SizedBox(height: 12),
            Text(
              'Votre avis sur $nounouPrenom a bien été publié.\n${note.toStringAsFixed(1)}/5 ⭐',
              style: const TextStyle(fontSize: 16,
                  color: AppColors.textGrey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Retour à l\'accueil',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: AppColors.textDark));
}
