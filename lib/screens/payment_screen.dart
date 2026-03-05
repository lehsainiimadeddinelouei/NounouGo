import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> demandeData;
  final String demandeId;

  const PaymentScreen({
    super.key,
    required this.demandeData,
    required this.demandeId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _selectedMethod = 'cash'; // 'cash' | 'card' | 'virement'
  bool _isProcessing = false;

  // Carte crédit
  final _cardNumberCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _obscureCvv = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardNameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  // ── Calculs ──
  double get _prixHeure =>
      (widget.demandeData['prixHeure'] ?? 0).toDouble();
  int get _duree => widget.demandeData['dureeHeures'] ?? 1;
  double get _sousTotal => _prixHeure * _duree;
  double get _fraisService => _selectedMethod == 'card' ? _sousTotal * 0.03 : 0;
  double get _total => _sousTotal + _fraisService;

  String _formatDate() {
    final ts = widget.demandeData['dateTime'] as Timestamp?;
    if (ts == null) return '—';
    final dt = ts.toDate();
    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${dt.day} ${mois[dt.month - 1]} ${dt.year} à ${dt.hour.toString().padLeft(2,'0')}h${dt.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _processPayment() async {
    // Validation carte
    if (_selectedMethod == 'card') {
      if (_cardNumberCtrl.text.replaceAll(' ', '').length < 16) {
        _showSnack('Numéro de carte invalide.'); return;
      }
      if (_cardNameCtrl.text.trim().isEmpty) {
        _showSnack('Saisissez le nom sur la carte.'); return;
      }
      if (_expiryCtrl.text.length < 5) {
        _showSnack('Date d\'expiration invalide.'); return;
      }
      if (_cvvCtrl.text.length < 3) {
        _showSnack('CVV invalide.'); return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final uid = _auth.currentUser!.uid;
      final now = FieldValue.serverTimestamp();

      // ── Enregistrer le paiement dans Firestore ──
      final paymentRef = await _db.collection('paiements').add({
        'demandeId': widget.demandeId,
        'parentUid': widget.demandeData['parentUid'],
        'nounouUid': widget.demandeData['nounouUid'],
        'parentPrenom': widget.demandeData['parentPrenom'],
        'parentNom': widget.demandeData['parentNom'],
        'nounouPrenom': widget.demandeData['nounouPrenom'],
        'nounouNom': widget.demandeData['nounouNom'],
        'methode': _selectedMethod,
        'sousTotal': _sousTotal,
        'fraisService': _fraisService,
        'montantTotal': _total,
        'dureeHeures': _duree,
        'prixHeure': _prixHeure,
        'dateGarde': widget.demandeData['dateTime'],
        'statut': _selectedMethod == 'cash' ? 'en_attente_cash' : 'payé',
        'createdAt': now,
        'payeurUid': uid,
      });

      // ── Marquer la demande comme payée ──
      await _db.collection('demandes').doc(widget.demandeId).update({
        'paiementStatut': _selectedMethod == 'cash' ? 'en_attente_cash' : 'payé',
        'paiementMethode': _selectedMethod,
        'paiementId': paymentRef.id,
        'paiementMontant': _total,
      });

      // ── Notifier la nounou ──
      await _db.collection('notifications').add({
        'destinataireUid': widget.demandeData['nounouUid'],
        'type': 'paiement',
        'titre': _selectedMethod == 'cash'
            ? '💵 Paiement cash prévu'
            : '✅ Paiement reçu',
        'message': _selectedMethod == 'cash'
            ? '${widget.demandeData['parentPrenom']} vous paiera ${_total.toInt()} DA en cash le jour de la garde.'
            : '${widget.demandeData['parentPrenom']} a effectué un paiement de ${_total.toInt()} DA via ${_methodLabel()}.',
        'lu': false,
        'createdAt': now,
      });

      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => PaymentSuccessScreen(
            methode: _selectedMethod,
            montant: _total,
            demandeData: widget.demandeData,
            paiementId: paymentRef.id,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Erreur : $e');
    }
  }

  String _methodLabel() {
    switch (_selectedMethod) {
      case 'card': return 'carte crédit';
      case 'virement': return 'virement bancaire';
      default: return 'cash';
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.primaryPink : Colors.green,
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
              pinned: true, expandedHeight: 110,
              backgroundColor: AppColors.buttonBlue,
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
                      colors: [Color(0xFF4A90D9), AppColors.buttonBlue],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const SizedBox(height: 20),
                      const Icon(Icons.payment_rounded,
                          color: Colors.white, size: 28),
                      const SizedBox(height: 6),
                      const Text('Paiement',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                  // ── Récap de la garde ──
                  _SectionTitle(label: '📋 Récapitulatif de la garde'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDeco(),
                    child: Column(children: [
                      _RecapRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nounou',
                        value:
                            '${widget.demandeData['nounouPrenom']} ${widget.demandeData['nounouNom']}',
                        color: AppColors.primaryPink,
                      ),
                      const _HDivider(),
                      _RecapRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: _formatDate(),
                        color: AppColors.buttonBlue,
                      ),
                      const _HDivider(),
                      _RecapRow(
                        icon: Icons.access_time_rounded,
                        label: 'Durée',
                        value:
                            '$_duree heure${_duree > 1 ? 's' : ''} × ${_prixHeure.toInt()} DA',
                        color: Colors.purple,
                      ),
                      const _HDivider(),
                      _RecapRow(
                        icon: Icons.child_care_rounded,
                        label: 'Enfants',
                        value:
                            '${widget.demandeData['nbEnfants'] ?? 1} enfant(s)',
                        color: Colors.orange,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Choisir méthode ──
                  _SectionTitle(label: '💳 Méthode de paiement'),
                  const SizedBox(height: 12),
                  _PaymentMethodSelector(
                    selected: _selectedMethod,
                    onChanged: (m) => setState(() => _selectedMethod = m),
                  ),
                  const SizedBox(height: 20),

                  // ── Formulaire carte ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim,
                            child: SizeTransition(
                                sizeFactor: anim, child: child)),
                    child: _selectedMethod == 'card'
                        ? _CardForm(
                            key: const ValueKey('card'),
                            numberCtrl: _cardNumberCtrl,
                            nameCtrl: _cardNameCtrl,
                            expiryCtrl: _expiryCtrl,
                            cvvCtrl: _cvvCtrl,
                            obscureCvv: _obscureCvv,
                            onToggleCvv: () =>
                                setState(() => _obscureCvv = !_obscureCvv),
                          )
                        : _selectedMethod == 'virement'
                            ? const _VirementInfo(
                                key: ValueKey('virement'))
                            : const _CashInfo(key: ValueKey('cash')),
                  ),
                  const SizedBox(height: 24),

                  // ── Montant total ──
                  _SectionTitle(label: '💰 Montant'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDeco(),
                    child: Column(children: [
                      _AmountRow(
                          label: 'Sous-total',
                          value: '${_sousTotal.toInt()} DA'),
                      if (_selectedMethod == 'card') ...[
                        const SizedBox(height: 8),
                        _AmountRow(
                          label: 'Frais service (3%)',
                          value: '${_fraisService.toStringAsFixed(0)} DA',
                          isSecondary: true,
                        ),
                      ],
                      const Divider(
                          height: 20, color: Color(0xFFF0E8F5)),
                      _AmountRow(
                        label: 'TOTAL',
                        value: '${_total.toInt()} DA',
                        isBold: true,
                        color: AppColors.buttonBlue,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Bouton payer ──
                  CustomButton(
                    label: _selectedMethod == 'cash'
                        ? '💵 Confirmer - Payer en cash'
                        : _selectedMethod == 'virement'
                            ? '🏦 Confirmer le virement'
                            : '💳 Payer ${_total.toInt()} DA',
                    onTap: _processPayment,
                    isLoading: _isProcessing,
                    color: AppColors.buttonBlue,
                  ),
                  const SizedBox(height: 12),

                  // Note sécurité
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 13, color: AppColors.textGrey),
                    const SizedBox(width: 6),
                    const Text('Paiement sécurisé — vos données sont protégées',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textGrey)),
                  ]),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      );
}

// ════════════════════════════════════════════
// Sélecteur méthode paiement
// ════════════════════════════════════════════
class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;
  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _MethodTile(
        value: 'cash',
        selected: selected,
        icon: Icons.payments_rounded,
        label: 'Cash',
        subtitle: 'Paiement en main propre le jour de la garde',
        color: Colors.green,
        onTap: () => onChanged('cash'),
      ),
      const SizedBox(height: 10),
      _MethodTile(
        value: 'card',
        selected: selected,
        icon: Icons.credit_card_rounded,
        label: 'Carte crédit',
        subtitle: 'Visa / Mastercard — frais service 3%',
        color: AppColors.buttonBlue,
        onTap: () => onChanged('card'),
      ),
      const SizedBox(height: 10),
      _MethodTile(
        value: 'virement',
        selected: selected,
        icon: Icons.account_balance_rounded,
        label: 'Virement bancaire',
        subtitle: 'Transfert CCP / CIB — 24-48h',
        color: Colors.orange,
        onTap: () => onChanged('virement'),
      ),
    ]);
  }
}

class _MethodTile extends StatelessWidget {
  final String value, selected, label, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MethodTile({
    required this.value, required this.selected,
    required this.icon, required this.label,
    required this.subtitle, required this.color,
    required this.onTap,
  });

  bool get _isSelected => value == selected;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isSelected ? color.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isSelected ? color : const Color(0xFFEEE0F5),
              width: _isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _isSelected ? color : AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: _isSelected ? color : AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: _isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ]),
        ),
      );
}

// ════════════════════════════════════════════
// Formulaire carte crédit
// ════════════════════════════════════════════
class _CardForm extends StatelessWidget {
  final TextEditingController numberCtrl, nameCtrl, expiryCtrl, cvvCtrl;
  final bool obscureCvv;
  final VoidCallback onToggleCvv;
  const _CardForm({
    super.key,
    required this.numberCtrl, required this.nameCtrl,
    required this.expiryCtrl, required this.cvvCtrl,
    required this.obscureCvv, required this.onToggleCvv,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Aperçu carte
        _CardPreview(numberCtrl: numberCtrl, nameCtrl: nameCtrl,
            expiryCtrl: expiryCtrl),
        const SizedBox(height: 20),

        // Numéro
        _CardField(
          controller: numberCtrl,
          label: 'NUMÉRO DE CARTE',
          hint: '0000  0000  0000  0000',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ],
          maxLength: 19,
        ),
        const SizedBox(height: 14),

        // Nom
        _CardField(
          controller: nameCtrl,
          label: 'NOM SUR LA CARTE',
          hint: 'PRÉNOM NOM',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 14),

        // Expiry + CVV
        Row(children: [
          Expanded(
            child: _CardField(
              controller: expiryCtrl,
              label: 'EXPIRATION',
              hint: 'MM/AA',
              icon: Icons.date_range_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ExpiryFormatter(),
              ],
              maxLength: 5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CardField(
              controller: cvvCtrl,
              label: 'CVV',
              hint: '•••',
              icon: Icons.lock_outline_rounded,
              obscureText: obscureCvv,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              suffixIcon: GestureDetector(
                onTap: onToggleCvv,
                child: Icon(
                  obscureCvv
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textGrey, size: 18,
                ),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 14),
        // Badges sécurité
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _SecurityBadge(label: 'Visa'),
          const SizedBox(width: 8),
          _SecurityBadge(label: 'Mastercard'),
          const SizedBox(width: 8),
          _SecurityBadge(label: 'SSL 256-bit'),
        ]),
      ]),
    );
  }
}

// Aperçu visuel de la carte
class _CardPreview extends StatelessWidget {
  final TextEditingController numberCtrl, nameCtrl, expiryCtrl;
  const _CardPreview(
      {required this.numberCtrl,
      required this.nameCtrl,
      required this.expiryCtrl});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([numberCtrl, nameCtrl, expiryCtrl]),
      builder: (_, __) {
        final num = numberCtrl.text.isEmpty
            ? '0000  0000  0000  0000'
            : numberCtrl.text.padRight(19, '0').substring(0, 19);
        final name =
            nameCtrl.text.isEmpty ? 'VOTRE NOM' : nameCtrl.text.toUpperCase();
        final expiry =
            expiryCtrl.text.isEmpty ? 'MM/AA' : expiryCtrl.text;

        return Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2D3561), Color(0xFF4A90D9)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF2D3561).withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 8))
            ],
          ),
          child: Stack(children: [
            // Cercles décoratifs
            Positioned(top: -20, right: -20,
              child: Container(width: 120, height: 120,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle))),
            Positioned(bottom: -30, left: 60,
              child: Container(width: 100, height: 100,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle))),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  const Icon(Icons.contactless_rounded,
                      color: Colors.white70, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('NounouGo Pay',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const Spacer(),
                Text(num,
                    style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('TITULAIRE',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white54,
                            letterSpacing: 1)),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('EXPIRE',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white54,
                            letterSpacing: 1)),
                    Text(expiry,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════
// Info virement
// ════════════════════════════════════════════
class _VirementInfo extends StatelessWidget {
  const _VirementInfo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05), blurRadius: 12)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.account_balance_rounded,
              color: Colors.orange, size: 20)),
        const SizedBox(width: 12),
        const Text('Coordonnées bancaires',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
      ]),
      const SizedBox(height: 16),
      _BankRow(label: 'Banque', value: 'CPA — Crédit Populaire d\'Algérie'),
      const SizedBox(height: 8),
      _BankRow(label: 'Titulaire', value: 'NounouGo SAS'),
      const SizedBox(height: 8),
      _BankRow(label: 'RIB', value: '0070 0123 4567 8901 234'),
      const SizedBox(height: 8),
      _BankRow(label: 'CCP', value: '1234567 — Clé 89'),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Mentionnez la référence de votre demande dans le motif du virement. Délai : 24-48h.',
            style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.4),
          )),
        ]),
      ),
    ]),
  );
}

// ════════════════════════════════════════════
// Info cash
// ════════════════════════════════════════════
class _CashInfo extends StatelessWidget {
  const _CashInfo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05), blurRadius: 12)],
    ),
    child: Column(children: [
      const Icon(Icons.payments_rounded, color: Colors.green, size: 40),
      const SizedBox(height: 12),
      const Text('Paiement en espèces',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Text(
        'Vous paierez directement la nounou le jour de la garde. Prévoyez le montant exact.',
        style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _CashStep(num: '1', label: 'Confirmez ici'),
        const _StepArrow(),
        _CashStep(num: '2', label: 'Jour J'),
        const _StepArrow(),
        _CashStep(num: '3', label: 'Payez en main'),
      ]),
    ]),
  );
}

class _CashStep extends StatelessWidget {
  final String num, label;
  const _CashStep({required this.num, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 36, height: 36,
      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      child: Center(child: Text(num,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey,
        fontWeight: FontWeight.w600), textAlign: TextAlign.center),
  ]);
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 20, left: 6, right: 6),
    child: Icon(Icons.arrow_forward_rounded, color: AppColors.inputBorder, size: 16),
  );
}

// ════════════════════════════════════════════
// Écran succès paiement
// ════════════════════════════════════════════
class PaymentSuccessScreen extends StatelessWidget {
  final String methode, paiementId;
  final double montant;
  final Map<String, dynamic> demandeData;

  const PaymentSuccessScreen({
    super.key,
    required this.methode, required this.montant,
    required this.demandeData, required this.paiementId,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = methode == 'cash';
    final isVirement = methode == 'virement';
    final color = isCash ? Colors.green : isVirement ? Colors.orange : AppColors.buttonBlue;
    final icon = isCash ? Icons.payments_rounded
        : isVirement ? Icons.account_balance_rounded
        : Icons.credit_card_rounded;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),

              // Animation check
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_rounded,
                      size: 60, color: color),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                isCash ? 'Confirmé ! 💵'
                    : isVirement ? 'Virement initié 🏦'
                    : 'Paiement réussi ! 🎉',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isCash
                    ? 'Préparez ${montant.toInt()} DA en espèces\npour le jour de la garde.'
                    : isVirement
                        ? 'Effectuez le virement de ${montant.toInt()} DA.\nVotre garde sera confirmée sous 24-48h.'
                        : '${montant.toInt()} DA débités avec succès.\nVotre garde est confirmée !',
                style: const TextStyle(fontSize: 15, color: AppColors.textGrey,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Récap paiement
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                      blurRadius: 16)],
                ),
                child: Column(children: [
                  Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 22)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        isCash ? 'Cash' : isVirement ? 'Virement bancaire' : 'Carte crédit',
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                      Text('Réf: ${paiementId.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontSize: 12,
                              color: AppColors.textGrey)),
                    ])),
                    Text('${montant.toInt()} DA',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w900, color: color)),
                  ]),
                  const Divider(height: 24, color: Color(0xFFF0E8F5)),
                  _RecapRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Nounou',
                    value: '${demandeData['nounouPrenom']} ${demandeData['nounouNom']}',
                    color: AppColors.primaryPink,
                  ),
                ]),
              ),

              const Spacer(),

              // Bouton retour
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Retour à l\'accueil',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voir mes demandes',
                    style: TextStyle(color: AppColors.textGrey,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Historique paiements
// ════════════════════════════════════════════
class HistoriquePaiementsScreen extends StatelessWidget {
  final String role;
  const HistoriquePaiementsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final field = role == 'Parent' ? 'parentUid' : 'nounouUid';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)]),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10)]),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppColors.textDark)),
                ),
                const SizedBox(width: 14),
                const Text('Historique paiements',
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('paiements')
                    .where(field, isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AppColors.primaryPink));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('💳', style: TextStyle(fontSize: 60)),
                        SizedBox(height: 16),
                        Text('Aucun paiement',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                      ],
                    ));
                  }
                  // Calcul total
                  final total = docs.fold<double>(0, (sum, doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return sum + ((d['montantTotal'] ?? 0) as num).toDouble();
                  });

                  return Column(children: [
                    // Carte total
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF2D3561), Color(0xFF4A90D9)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 14),
                          Column(crossAxisAlignment:
                              CrossAxisAlignment.start, children: [
                            const Text('Total dépensé',
                                style: TextStyle(fontSize: 12,
                                    color: Colors.white70)),
                            Text('${total.toInt()} DA',
                                style: const TextStyle(fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ]),
                          const Spacer(),
                          Text('${docs.length} paiement${docs.length > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 13,
                                  color: Colors.white70)),
                        ]),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          data['id'] = docs[i].id;
                          return _PaiementCard(data: data, role: role);
                        },
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PaiementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String role;
  const _PaiementCard({required this.data, required this.role});

  Future<void> _confirmDelete(BuildContext context, String paiementId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce paiement ?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Ce paiement sera supprimé de votre historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('paiements').doc(paiementId).delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final methode = data['methode'] ?? 'cash';
    final montant = (data['montantTotal'] ?? 0).toDouble();
    final statut = data['statut'] ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final dt = ts?.toDate();
    final nomAutre = role == 'Parent'
        ? '${data['nounouPrenom']} ${data['nounouNom']}'
        : '${data['parentPrenom']} ${data['parentNom']}';

    final methodeColor = methode == 'cash' ? Colors.green
        : methode == 'virement' ? Colors.orange : AppColors.buttonBlue;
    final methodeIcon = methode == 'cash' ? Icons.payments_rounded
        : methode == 'virement' ? Icons.account_balance_rounded
        : Icons.credit_card_rounded;
    final methodeLabel = methode == 'cash' ? 'Cash'
        : methode == 'virement' ? 'Virement' : 'Carte';

    final statutColor = statut == 'payé' ? Colors.green
        : statut == 'en_attente_cash' ? Colors.orange : Colors.grey;
    final statutLabel = statut == 'payé' ? '✓ Payé'
        : statut == 'en_attente_cash' ? '⏳ Cash prévu' : statut;

    const mois = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    final dateStr = dt != null
        ? '${dt.day} ${mois[dt.month-1]} ${dt.year}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(color: methodeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(methodeIcon, color: methodeColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nomAutre, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 3),
            Row(children: [
              Text(methodeLabel, style: TextStyle(fontSize: 12,
                  color: methodeColor, fontWeight: FontWeight.w600)),
              const Text(' · ', style: TextStyle(color: AppColors.textGrey)),
              Text(dateStr, style: const TextStyle(fontSize: 12,
                  color: AppColors.textGrey)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${montant.toInt()} DA',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statutColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(statutLabel, style: TextStyle(fontSize: 11,
                  color: statutColor, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _confirmDelete(context, data['id'] ?? ''),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 14),
              SizedBox(width: 6),
              Text('Supprimer', style: TextStyle(fontSize: 12,
                  color: Colors.red, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════
// Widgets helper partagés
// ════════════════════════════════════════════
class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  const _CardField({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    this.keyboardType, this.inputFormatters,
    this.maxLength, this.obscureText = false,
    this.suffixIcon, this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, color: AppColors.textGrey,
        letterSpacing: 1.2)),
    const SizedBox(height: 6),
    TextField(
      controller: controller, obscureText: obscureText,
      keyboardType: keyboardType, inputFormatters: inputFormatters,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.buttonBlue, size: 18),
        suffixIcon: suffixIcon,
        filled: true, fillColor: const Color(0xFFF5F0FF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.buttonBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        counterText: '',
      ),
    ),
  ]);
}

class _SecurityBadge extends StatelessWidget {
  final String label;
  const _SecurityBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.buttonBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 10,
        color: AppColors.buttonBlue, fontWeight: FontWeight.w700)),
  );
}

class _BankRow extends StatelessWidget {
  final String label, value;
  const _BankRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 80, child: Text(label,
        style: const TextStyle(fontSize: 12, color: AppColors.textGrey,
            fontWeight: FontWeight.w500))),
    Expanded(child: Text(value,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark,
            fontWeight: FontWeight.w600))),
  ]);
}

class _RecapRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _RecapRow({required this.icon, required this.label,
    required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 13,
          color: AppColors.textGrey, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w700, color: AppColors.textDark)),
    ]),
  );
}

class _AmountRow extends StatelessWidget {
  final String label, value;
  final bool isBold, isSecondary;
  final Color? color;
  const _AmountRow({required this.label, required this.value,
    this.isBold = false, this.isSecondary = false, this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(fontSize: isBold ? 15 : 13,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        color: isSecondary ? AppColors.textGrey : AppColors.textDark)),
    Text(value, style: TextStyle(fontSize: isBold ? 18 : 13,
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
        color: color ?? (isBold ? AppColors.textDark : AppColors.textGrey))),
  ]);
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFF5EEF8));
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.textDark));
}

// ════════════════════════════════════════════
// Formatters
// ════════════════════════════════════════════
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    final digits = newVal.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newVal.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    final digits = newVal.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return newVal.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
