import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> nounouData;
  const BookingScreen({super.key, required this.nounouData});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _dureeHeures = 2;
  int _nbEnfants = 1;
  bool _isSending = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── Calendrier interactif ──
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr', 'FR'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryPink,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryPink),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryPink,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryPink),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _sendDemande() async {
    if (_selectedDate == null) { _showSnack('Choisissez une date.'); return; }
    if (_selectedTime == null) { _showSnack('Choisissez une heure.'); return; }

    setState(() => _isSending = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Charger infos parent
      final parentDoc = await _db.collection('users').doc(uid).get();
      final parentData = parentDoc.data()!;

      final dateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      final nounouUid = widget.nounouData['uid'] as String;

      // ── Créer la demande dans Firestore ──
      final demandeRef = await _db.collection('demandes').add({
        'parentUid': uid,
        'parentPrenom': parentData['prenom'] ?? '',
        'parentNom': parentData['nom'] ?? '',
        'parentEmail': parentData['email'] ?? '',
        'parentPhone': parentData['phone'] ?? '',
        'nounouUid': nounouUid,
        'nounouPrenom': widget.nounouData['prenom'] ?? '',
        'nounouNom': widget.nounouData['nom'] ?? '',
        'dateTime': Timestamp.fromDate(dateTime),
        'dureeHeures': _dureeHeures,
        'nbEnfants': _nbEnfants,
        'message': _messageController.text.trim(),
        'statut': 'en_attente', // en_attente | acceptée | refusée
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Créer une notification pour la nounou ──
      await _db.collection('notifications').add({
        'destinataireUid': nounouUid,
        'type': 'nouvelle_demande',
        'demandeId': demandeRef.id,
        'titre': 'Nouvelle demande de RDV',
        'message': '${parentData['prenom']} ${parentData['nom']} souhaite un RDV le ${_formatDate(dateTime)}',
        'lu': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackGlobal('Demande envoyée ! La nounou va être notifiée. ✅');
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showSnack('Erreur : $e');
    }
  }

  String _formatDate(DateTime dt) {
    const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${mois[dt.month - 1]} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppColors.primaryPink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSnackGlobal(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  bool get _canSend => _selectedDate != null && _selectedTime != null;

  @override
  Widget build(BuildContext context) {
    final prenom = widget.nounouData['prenom'] ?? '';
    final nom = widget.nounouData['nom'] ?? '';
    final prix = widget.nounouData['prixHeure'];
    final disponibilitesRaw = widget.nounouData['disponibilites'];
    List<String> disponibilites = [];
    if (disponibilitesRaw is List) {
      disponibilites = List<String>.from(disponibilitesRaw);
    } else if (disponibilitesRaw is Map) {
      for (final slots in disponibilitesRaw.values) {
        if (slots is List) disponibilites.addAll(slots.cast<String>());
      }
      disponibilites = disponibilites.toSet().toList();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(slivers: [
            // ── AppBar ──
            SliverAppBar(
              pinned: true, expandedHeight: 120,
              backgroundColor: AppColors.primaryPink,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFFFF8FAB), AppColors.primaryPink]),
                  ),
                  child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 20),
                    const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
                    const SizedBox(height: 6),
                    Text('RDV avec $prenom $nom',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (prix != null)
                      Text('$prix DA/h', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ])),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Disponibilités info ──
                  if (disponibilites.isNotEmpty) ...[
                    _SectionTitle(label: '🕐 Disponibilités de $prenom'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: disponibilites.map((d) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(d, style: const TextStyle(fontSize: 12, color: AppColors.primaryPink, fontWeight: FontWeight.w600)),
                    )).toList()),
                    const SizedBox(height: 24),
                  ],

                  // ── Calendrier ──
                  _SectionTitle(label: '📅 Choisir une date'),
                  const SizedBox(height: 12),
                  _CalendarWidget(
                    selectedDate: _selectedDate,
                    onDateSelected: (d) => setState(() => _selectedDate = d),
                  ),
                  const SizedBox(height: 24),

                  // ── Heure ──
                  _SectionTitle(label: '🕐 Heure de début'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _selectedTime != null ? AppColors.primaryPink : AppColors.inputBorder, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Row(children: [
                        Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.access_time_rounded, color: AppColors.primaryPink, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(child: Text(
                          _selectedTime != null
                              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}h${_selectedTime!.minute.toString().padLeft(2, '0')}'
                              : 'Sélectionner une heure',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: _selectedTime != null ? AppColors.textDark : AppColors.textGrey),
                        )),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Durée ──
                  _SectionTitle(label: '⏱ Durée'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('$_dureeHeures heure${_dureeHeures > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        if (prix != null)
                          Text('= ${prix * _dureeHeures} DA',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.buttonBlue)),
                      ]),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primaryPink,
                          inactiveTrackColor: AppColors.lightPink,
                          thumbColor: AppColors.primaryPink,
                          overlayColor: AppColors.primaryPink.withOpacity(0.1),
                        ),
                        child: Slider(
                          value: _dureeHeures.toDouble(),
                          min: 1, max: 12, divisions: 11,
                          label: '$_dureeHeures h',
                          onChanged: (v) => setState(() => _dureeHeures = v.toInt()),
                        ),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('1h', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                        const Text('12h', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Nombre d'enfants ──
                  _SectionTitle(label: '👶 Nombre d\'enfants'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _CounterBtn(
                        icon: Icons.remove_rounded,
                        onTap: () { if (_nbEnfants > 1) setState(() => _nbEnfants--); },
                        enabled: _nbEnfants > 1,
                      ),
                      const SizedBox(width: 24),
                      Column(children: [
                        Text('$_nbEnfants', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primaryPink)),
                        Text(_nbEnfants == 1 ? 'enfant' : 'enfants',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      ]),
                      const SizedBox(width: 24),
                      _CounterBtn(
                        icon: Icons.add_rounded,
                        onTap: () { if (_nbEnfants < 6) setState(() => _nbEnfants++); },
                        enabled: _nbEnfants < 6,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Message ──
                  _SectionTitle(label: '💬 Message (optionnel)'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    child: TextField(
                      controller: _messageController, maxLines: 4,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Présentez votre situation, besoins particuliers...',
                        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Récap ──
                  if (_canSend) ...[
                    _RecapCard(
                      date: _selectedDate!, time: _selectedTime!,
                      duree: _dureeHeures, nbEnfants: _nbEnfants,
                      prix: prix?.toDouble(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Bouton envoyer ──
                  CustomButton(
                    label: _canSend ? 'Envoyer la demande ✓' : 'Choisissez date & heure',
                    onTap: _canSend ? _sendDemande : () => _showSnack('Choisissez une date et une heure.'),
                    isLoading: _isSending,
                    color: _canSend ? AppColors.primaryPink : AppColors.textGrey,
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

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
  );
}

// ── Calendrier interactif custom ──
class _CalendarWidget extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  const _CalendarWidget({required this.selectedDate, required this.onDateSelected});
  @override
  State<_CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<_CalendarWidget> {
  late DateTime _displayedMonth;
  final now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    final prev = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    if (!prev.isBefore(DateTime(now.year, now.month))) {
      setState(() => _displayedMonth = prev);
    }
  }

  void _nextMonth() => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1));

  static const _jours = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _mois = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)]),
      child: Column(children: [
        // Header mois
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: _prevMonth,
              child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.lightPink, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryPink))),
          Text('${_mois[_displayedMonth.month - 1]} ${_displayedMonth.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          GestureDetector(onTap: _nextMonth,
              child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.lightPink, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryPink))),
        ]),
        const SizedBox(height: 16),
        // Jours de la semaine
        Row(children: _jours.map((j) => Expanded(
          child: Center(child: Text(j, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGrey))),
        )).toList()),
        const SizedBox(height: 8),
        // Grille des jours
        ...List.generate(rows, (row) => Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - startOffset + 1;
            if (dayNum < 1 || dayNum > lastDay.day) return const Expanded(child: SizedBox(height: 40));
            final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
            final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
            final isSelected = widget.selectedDate != null &&
                date.year == widget.selectedDate!.year &&
                date.month == widget.selectedDate!.month &&
                date.day == widget.selectedDate!.day;
            final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

            return Expanded(
              child: GestureDetector(
                onTap: isPast ? null : () => widget.onDateSelected(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryPink
                        : isToday ? AppColors.primaryPink.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected ? Border.all(color: AppColors.primaryPink, width: 1.5) : null,
                  ),
                  child: Center(child: Text('$dayNum',
                    style: TextStyle(
                      fontSize: 14, fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? Colors.white : isPast ? AppColors.inputBorder : AppColors.textDark,
                    ),
                  )),
                ),
              ),
            );
          }),
        )),
      ]),
    );
  }
}

// ── Récap de la demande ──
class _RecapCard extends StatelessWidget {
  final DateTime date; final TimeOfDay time;
  final int duree, nbEnfants; final double? prix;
  const _RecapCard({required this.date, required this.time, required this.duree, required this.nbEnfants, this.prix});

  String _formatDate() {
    const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    const jours = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${jours[date.weekday]} ${date.day} ${mois[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primaryPink, Color(0xFFFF8FAB)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.primaryPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📋 Récapitulatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white70)),
      const SizedBox(height: 12),
      _RecapRow(icon: Icons.calendar_today_rounded, text: _formatDate()),
      const SizedBox(height: 8),
      _RecapRow(icon: Icons.access_time_rounded, text: '${time.hour.toString().padLeft(2, '0')}h${time.minute.toString().padLeft(2, '0')} — $duree heure${duree > 1 ? 's' : ''}'),
      const SizedBox(height: 8),
      _RecapRow(icon: Icons.child_care_rounded, text: '$nbEnfants enfant${nbEnfants > 1 ? 's' : ''}'),
      if (prix != null) ...[
        const SizedBox(height: 8),
        _RecapRow(icon: Icons.payments_outlined, text: 'Estimé : ${(prix! * duree).toInt()} DA'),
      ],
    ]),
  );
}

class _RecapRow extends StatelessWidget {
  final IconData icon; final String text;
  const _RecapRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Colors.white, size: 16),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
  ]);
}

class _CounterBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool enabled;
  const _CounterBtn({required this.icon, required this.onTap, required this.enabled});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: enabled ? AppColors.primaryPink : AppColors.lightPink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: enabled ? Colors.white : AppColors.textGrey, size: 22),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark));
}