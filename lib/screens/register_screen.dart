import 'package:flutter/material.dart';
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
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptCGU = false;
  final Set<String> _selectedAgeGroups = {};

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _handleRegister() async {
    if (_prenomController.text.trim().isEmpty || _nomController.text.trim().isEmpty) {
      _showSnack('Veuillez saisir votre prénom et nom.'); return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnack('Veuillez saisir votre email.'); return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack('Les mots de passe ne correspondent pas.'); return;
    }
    if (_passwordController.text.length < 6) {
      _showSnack('Le mot de passe doit contenir au moins 6 caractères.'); return;
    }
    if (!_acceptCGU) {
      _showSnack('Veuillez accepter les conditions d\'utilisation.'); return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      prenom: _prenomController.text,
      nom: _nomController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      role: widget.role,
      ageGroups: _selectedAgeGroups.toList(),
    );

    setState(() => _isLoading = false);

    if (result.success) {
      _showSnack(result.message, isError: false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        if (widget.role == 'Babysitter') {
          // Babysitter → écran de complétion du profil
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const BabysitterSetupScreen(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        } else {
          // Parent → accueil
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ParentHomeScreen(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        }
      }
    } else {
      _showSnack(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'Parent';
    final accentColor = isParent ? AppColors.buttonBlue : AppColors.primaryPink;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundGradientStart, Color(0xFFF8EEFF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Créer un compte',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isParent ? Icons.family_restroom : Icons.child_care, size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Text(widget.role, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(label: 'Informations personnelles'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: CustomTextField(controller: _prenomController, hintText: 'Prénom', prefixIcon: Icons.person_outline_rounded, accentColor: accentColor)),
                          const SizedBox(width: 12),
                          Expanded(child: CustomTextField(controller: _nomController, hintText: 'Nom', prefixIcon: Icons.badge_outlined, accentColor: accentColor)),
                        ]),
                        const SizedBox(height: 14),
                        CustomTextField(controller: _emailController, hintText: 'Adresse email', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, accentColor: accentColor),
                        const SizedBox(height: 14),
                        CustomTextField(controller: _phoneController, hintText: 'Numéro de téléphone', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone, accentColor: accentColor),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    if (!isParent) ...[
                      _SectionLabel(label: 'Votre profil nounou'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Tranches d\'âge gardés',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                          const SizedBox(height: 10),
                          _AgeGroupSelector(
                            accentColor: accentColor,
                            selected: _selectedAgeGroups,
                            onChanged: (g) => setState(() {
                              if (_selectedAgeGroups.contains(g)) _selectedAgeGroups.remove(g);
                              else _selectedAgeGroups.add(g);
                            }),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SectionLabel(label: 'Sécurité'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(children: [
                        CustomTextField(
                          controller: _passwordController,
                          hintText: 'Mot de passe',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          accentColor: accentColor,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            child: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryPink, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirmer le mot de passe',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          accentColor: accentColor,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryPink, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PasswordStrengthIndicator(controller: _passwordController, accentColor: accentColor),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => setState(() => _acceptCGU = !_acceptCGU),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: _acceptCGU ? accentColor : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _acceptCGU ? accentColor : AppColors.inputBorder, width: 2),
                          ),
                          child: _acceptCGU ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                            children: [
                              const TextSpan(text: 'J\'accepte les '),
                              TextSpan(text: 'Conditions d\'utilisation', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
                              const TextSpan(text: ' et la '),
                              TextSpan(text: 'Politique de confidentialité', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
                            ],
                          )),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    CustomButton(label: 'Créer mon compte', onTap: _handleRegister, isLoading: _isLoading, color: accentColor),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Déjà un compte ? ', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Se connecter', style: TextStyle(fontSize: 14, color: accentColor, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
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

class _AgeGroupSelector extends StatelessWidget {
  final Color accentColor;
  final Set<String> selected;
  final Function(String) onChanged;
  const _AgeGroupSelector({required this.accentColor, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const groups = ['0-1 an', '1-3 ans', '3-6 ans', '6-12 ans', '12+ ans'];
    return Wrap(spacing: 8, runSpacing: 8, children: groups.map((g) {
      final isSelected = selected.contains(g);
      return GestureDetector(
        onTap: () => onChanged(g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? accentColor : accentColor.withOpacity(0.2)),
          ),
          child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : accentColor)),
        ),
      );
    }).toList());
  }
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
