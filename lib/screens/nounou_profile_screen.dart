import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';
import 'historique_screen.dart';
import 'role_selection_screen.dart';

class NounouProfileScreen extends StatefulWidget {
  final Map<String, dynamic> nounouData;
  const NounouProfileScreen(
      {super.key, required this.nounouData});
  @override
  State<NounouProfileScreen> createState() =>
      _NounouProfileScreenState();
}

class _NounouProfileScreenState
    extends State<NounouProfileScreen> {
  String get _initiales {
    final p = (widget.nounouData['prenom'] ?? '');
    final n = (widget.nounouData['nom']    ?? '');
    return '${p.isNotEmpty ? p[0].toUpperCase() : ''}'
        '${n.isNotEmpty ? n[0].toUpperCase() : ''}';
  }

  // Vérifie si c'est la nounou elle-même qui regarde son profil
  bool get _isOwnProfile {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid;
    return currentUid != null &&
        currentUid == widget.nounouData['uid'];
  }

  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;
    bool obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !isLoading,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: const Row(children: [
              Icon(Icons.warning_rounded,
                  color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text('Supprimer le compte',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ]),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius:
                        BorderRadius.circular(12)),
                    child: const Text(
                        '⚠️ Action irréversible. Toutes vos données seront supprimées.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            height: 1.4),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 14),
                  if (errorMsg != null) ...[
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(10)),
                        child: Text(errorMsg!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red))),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Confirmez votre mot de passe',
                      filled: true,
                      fillColor: const Color(0xFFFFF5F7),
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.red, width: 1.5)),
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            set(() => obscure = !obscure),
                        child: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons
                                .visibility_off_outlined,
                            color: Colors.grey,
                            size: 20),
                      ),
                    ),
                  ),
                ]),
            actions: [
              TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style:
                      TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  if (passwordCtrl.text.isEmpty) {
                    set(() => errorMsg =
                    'Saisissez votre mot de passe.');
                    return;
                  }
                  set(() {
                    isLoading = true;
                    errorMsg  = null;
                  });
                  try {
                    final user  = FirebaseAuth
                        .instance.currentUser!;
                    final uid   = user.uid;
                    final email =
                    (user.email ?? '').toLowerCase();
                    final cred =
                    EmailAuthProvider.credential(
                        email: user.email!,
                        password:
                        passwordCtrl.text);
                    await user
                        .reauthenticateWithCredential(
                        cred);
                    try {
                      final docsSnap =
                      await FirebaseFirestore
                          .instance
                          .collection('users')
                          .doc(uid)
                          .collection(
                          'documents')
                          .get();
                      for (final d in docsSnap.docs) {
                        await d.reference.delete();
                      }
                    } catch (_) {}
                    try {
                      await FirebaseFirestore.instance
                          .collection(
                          'deleted_accounts')
                          .doc(uid)
                          .set({
                        'uid':   uid,
                        'email': email,
                        'prenom':
                        widget.nounouData[
                        'prenom'] ??
                            '',
                        'nom':
                        widget.nounouData['nom'] ??
                            '',
                        'deletedAt': FieldValue
                            .serverTimestamp(),
                        'deletedBySelf': true,
                      });
                    } catch (_) {}
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .delete();
                    await user.delete();
                    if (ctx.mounted)
                      Navigator.of(ctx).pop();
                  } on FirebaseAuthException catch (e) {
                    set(() {
                      isLoading = false;
                      errorMsg  =
                      (e.code == 'wrong-password' ||
                          e.code ==
                              'invalid-credential')
                          ? 'Mot de passe incorrect.'
                          : 'Erreur: ${e.code}';
                    });
                  } catch (e) {
                    set(() {
                      isLoading = false;
                      errorMsg  = 'Erreur: $e';
                    });
                  }
                },
                child: isLoading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red))
                    : const Text('Supprimer',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
    passwordCtrl.dispose();

    if (FirebaseAuth.instance.currentUser == null &&
        mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
            const RoleSelectionScreen(),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration:
            const Duration(milliseconds: 400),
          ),
              (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prenom       = widget.nounouData['prenom'] ?? '';
    final nom          = widget.nounouData['nom']    ?? '';
    final ville        =
        widget.nounouData['ville'] ?? 'Non renseignée';
    final prix         = widget.nounouData['prixHeure'];
    final score        =
    (widget.nounouData['score'] ?? 0.0).toDouble();
    final nbAvis       = widget.nounouData['nbAvis'] ?? 0;
    final bio          = widget.nounouData['bio']    ?? '';
    final photoBase64  =
    widget.nounouData['photoBase64'] as String?;
    final diplomes     = List<String>.from(
        widget.nounouData['diplomes']      ?? []);
    final competences  = List<String>.from(
        widget.nounouData['competences']   ?? []);
    final experiences  = List<String>.from(
        widget.nounouData['experiences']   ?? []);
    final ageGroups    = List<String>.from(
        widget.nounouData['ageGroups']     ?? []);
    // Disponibilités: support both new Map<String,List> and legacy List<String>
    final rawDispos = widget.nounouData['disponibilites'];
    Map<String, List<String>> disponibilitesMap = {};
    List<String> disponibilitesFlat = [];
    if (rawDispos is Map) {
      rawDispos.forEach((jour, periodes) {
        if (periodes is List && periodes.isNotEmpty) {
          disponibilitesMap[jour.toString()] =
          List<String>.from(periodes.map((p) => p.toString()));
        }
      });
    } else if (rawDispos is List) {
      disponibilitesFlat = List<String>.from(rawDispos);
    }

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
        child: CustomScrollView(slivers: [

          // ── SliverAppBar ───────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primaryPink,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 16, color: AppColors.textDark),
              ),
            ),
            actions: _isOwnProfile
                ? [
              GestureDetector(
                onTap: _deleteAccount,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Supprimer',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w700)),
                      ]),
                ),
              ),
            ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF8FAB),
                      AppColors.primaryPink
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.12),
                                  blurRadius: 20)
                            ],
                          ),
                          child: ClipOval(
                              child: photoBase64 != null
                                  ? Image.memory(
                                  base64Decode(photoBase64),
                                  fit: BoxFit.cover)
                                  : Container(
                                  color: Colors.white
                                      .withOpacity(0.3),
                                  child: Center(
                                      child: Text(
                                          _initiales,
                                          style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight:
                                              FontWeight.w800,
                                              color:
                                              Colors.white))))),
                        ),
                        const SizedBox(height: 12),
                        Text('$prenom $nom',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                              color:
                              Colors.white.withOpacity(0.2),
                              borderRadius:
                              BorderRadius.circular(20)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.child_care_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Babysitter',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ]),
                        ),
                        const SizedBox(height: 8),
                        // Location + price
                        Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(ville,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70)),
                              if (prix != null) ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.payments_outlined,
                                    size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text('$prix DA/h',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ]),
                        const SizedBox(height: 8),
                        // Stars
                        if (score > 0)
                          Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                ...List.generate(
                                    5,
                                        (i) => Icon(
                                      i < score.floor()
                                          ? Icons.star_rounded
                                          : (i < score
                                          ? Icons
                                          .star_half_rounded
                                          : Icons
                                          .star_outline_rounded),
                                      color: Colors.amber,
                                      size: 18,
                                    )),
                                const SizedBox(width: 6),
                                Text(
                                    '$score ($nbAvis avis)',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight:
                                        FontWeight.w600)),
                              ]),
                      ]),
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    // ── Action buttons ──────────────────────────
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    BookingScreen(
                                        nounouData:
                                        widget.nounouData),
                                transitionsBuilder:
                                    (_, anim, __, child) =>
                                    FadeTransition(
                                        opacity: anim,
                                        child: child),
                                transitionDuration:
                                const Duration(
                                    milliseconds: 350),
                              )),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF8FAB),
                                  AppColors.primaryPink
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                              BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primaryPink
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Prendre RDV',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                          FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    ChatScreen(
                                      otherUid: widget.nounouData[
                                      'uid'] ??
                                          '',
                                      otherPrenom: prenom,
                                      otherNom:    nom,
                                      otherPhotoBase64:
                                      widget.nounouData[
                                      'photoBase64']
                                      as String?,
                                    ),
                                transitionsBuilder:
                                    (_, anim, __, child) =>
                                    SlideTransition(
                                      position: Tween<
                                          Offset>(
                                          begin:
                                          const Offset(
                                              1, 0),
                                          end: Offset
                                              .zero)
                                          .animate(
                                          CurvedAnimation(
                                              parent: anim,
                                              curve: Curves
                                                  .easeOutCubic)),
                                      child: child,
                                    ),
                                transitionDuration:
                                const Duration(
                                    milliseconds: 350),
                              )),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7B9FFF),
                                  AppColors.buttonBlue
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                              BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.buttonBlue
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      Icons
                                          .chat_bubble_outline_rounded,
                                      size: 18,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Message',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                          FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── À propos ─────────────────────────────────
                    if (bio.isNotEmpty) ...[
                      const _SectionTitle(label: 'À propos'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Text(bio,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey,
                                height: 1.6)),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Disponibilités ───────────────────────────
                    if (disponibilitesMap.isNotEmpty) ...[
                      const _SectionTitle(label: '🕐 Disponibilités'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        decoration: _cardDecoration(),
                        child: Column(
                          children: disponibilitesMap.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((outer) {
                            final isLast = outer.key ==
                                disponibilitesMap.entries.length - 1;
                            final jour    = outer.value.key;
                            final periodes = outer.value.value;
                            return Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(jour,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.w700,
                                              color:
                                              AppColors.textDark)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: periodes
                                            .map((p) => Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal:
                                              10,
                                              vertical:
                                              4),
                                          decoration:
                                          BoxDecoration(
                                            color: AppColors
                                                .primaryPink
                                                .withOpacity(
                                                0.1),
                                            borderRadius:
                                            BorderRadius
                                                .circular(
                                                20),
                                            border: Border.all(
                                                color: AppColors
                                                    .primaryPink
                                                    .withOpacity(
                                                    0.2)),
                                          ),
                                          child: Text(p,
                                              style: const TextStyle(
                                                  fontSize:
                                                  12,
                                                  color: AppColors
                                                      .primaryPink,
                                                  fontWeight:
                                                  FontWeight
                                                      .w600)),
                                        ))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFF5EEF0),
                                      indent: 16,
                                      endIndent: 16),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (disponibilitesFlat.isNotEmpty) ...[
                      const _SectionTitle(label: '🕐 Disponibilités'),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: disponibilitesFlat
                              .map((d) => _Tag(
                              label: d,
                              color: AppColors.primaryPink))
                              .toList()),
                      const SizedBox(height: 20),
                    ],

                    // ── Tranches d'âge ───────────────────────────
                    if (ageGroups.isNotEmpty) ...[
                      const _SectionTitle(
                          label: "👶 Tranches d'âge acceptées"),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ageGroups
                              .map((a) => _Tag(
                              label: a,
                              color: AppColors.primaryPink))
                              .toList()),
                      const SizedBox(height: 20),
                    ],

                    // ── Diplômes ─────────────────────────────────
                    if (diplomes.isNotEmpty) ...[
                      const _SectionTitle(label: '🎓 Diplômes'),
                      const SizedBox(height: 10),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 4),
                        decoration: _cardDecoration(),
                        child: Column(
                            children: diplomes.asMap().entries
                                .map((e) => Column(children: [
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10),
                                child: Row(children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: AppColors
                                            .primaryPink
                                            .withOpacity(
                                            0.08),
                                        borderRadius:
                                        BorderRadius.circular(
                                            10)),
                                    child: const Icon(
                                        Icons
                                            .school_outlined,
                                        size: 18,
                                        color: AppColors
                                            .primaryPink),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Text(e.value,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors
                                                  .textDark,
                                              fontWeight:
                                              FontWeight
                                                  .w500))),
                                ]),
                              ),
                              if (e.key <
                                  diplomes.length - 1)
                                const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color:
                                    Color(0xFFF5EEF0),
                                    indent: 16,
                                    endIndent: 16),
                            ]))
                                .toList()),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Compétences ──────────────────────────────
                    if (competences.isNotEmpty) ...[
                      const _SectionTitle(
                          label: '⭐ Compétences'),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: competences
                              .map((c) => _Tag(
                              label: c,
                              color: AppColors.primaryPink))
                              .toList()),
                      const SizedBox(height: 20),
                    ],

                    // ── Expériences ──────────────────────────────
                    if (experiences.isNotEmpty) ...[
                      const _SectionTitle(
                          label: '💼 Expériences'),
                      const SizedBox(height: 10),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 4),
                        decoration: _cardDecoration(),
                        child: Column(
                            children: experiences.asMap().entries
                                .map((e) => Column(children: [
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10),
                                child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Container(
                                        margin:
                                        const EdgeInsets.only(
                                            top: 2),
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                            color: AppColors
                                                .primaryPink
                                                .withOpacity(
                                                0.08),
                                            borderRadius:
                                            BorderRadius.circular(
                                                10)),
                                        child: const Icon(
                                            Icons
                                                .work_outline_rounded,
                                            size: 18,
                                            color: AppColors
                                                .primaryPink),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Text(e.value,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors
                                                      .textDark,
                                                  fontWeight:
                                                  FontWeight
                                                      .w500,
                                                  height:
                                                  1.4))),
                                    ]),
                              ),
                              if (e.key <
                                  experiences.length - 1)
                                const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color:
                                    Color(0xFFF5EEF0),
                                    indent: 16,
                                    endIndent: 16),
                            ]))
                                .toList()),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Avis depuis Firestore ─────────────────────
                    const _SectionTitle(label: '💬 Avis'),
                    const SizedBox(height: 10),
                    AvisNounouSection(
                        nounouUid:
                        widget.nounouData['uid'] ?? ''),

                    const SizedBox(height: 40),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 4))
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textGrey,
        letterSpacing: 1.2),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600)),
  );
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentCard({required this.comment});
  @override
  Widget build(BuildContext context) {
    final auteur = comment['auteur'] ?? 'Anonyme';
    final texte  = comment['texte']  ?? '';
    final note   = (comment['note']  ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                            auteur.isNotEmpty
                                ? auteur[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPink)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(auteur,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                  ]),
                  Row(
                      children: List.generate(
                          5,
                              (i) => Icon(
                            i < note
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 14,
                          ))),
                ]),
            if (texte.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(texte,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                      height: 1.5)),
            ],
          ]),
    );
  }
}
