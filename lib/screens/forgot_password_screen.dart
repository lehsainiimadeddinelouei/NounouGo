import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String role;
  const ForgotPasswordScreen({super.key, required this.role});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  String _selectedMethod = 'email';
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;

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
    _emailController.dispose();
    _phoneController.dispose();
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

  Future<void> _handleSend() async {
    if (_selectedMethod == 'email') {
      if (_emailController.text.trim().isEmpty) {
        _showSnack('Veuillez saisir votre adresse email.');
        return;
      }
      setState(() => _isLoading = true);
      // Appel Firebase réel
      final result = await AuthService.sendPasswordReset(email: _emailController.text);
      setState(() => _isLoading = false);

      if (result.success) {
        setState(() => _codeSent = true);
      } else {
        _showSnack(result.message);
      }
    } else {
      // SMS — nécessite Firebase Phone Auth (à configurer séparément)
      if (_phoneController.text.trim().isEmpty) {
        _showSnack('Veuillez saisir votre numéro de téléphone.');
        return;
      }
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));
      setState(() { _isLoading = false; _codeSent = true; });
      // TODO: implement Firebase Phone Auth
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
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
                child: _codeSent
                    ? _SuccessView(
                        accentColor: accentColor,
                        method: _selectedMethod,
                        value: _selectedMethod == 'email' ? _emailController.text : _phoneController.text,
                        onBack: () => Navigator.pop(context),
                        onResend: _handleSend,
                      )
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                        const SizedBox(height: 32),
                        Center(child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.lock_reset_rounded, size: 36, color: accentColor),
                        )),
                        const SizedBox(height: 20),
                        const Text('Mot de passe oublié ?',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text('Choisissez comment recevoir\nvotre lien de réinitialisation',
                          style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // Toggle Email / SMS
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: Row(children: [
                            _MethodTab(label: 'Email', icon: Icons.mail_outline_rounded, isSelected: _selectedMethod == 'email', accentColor: accentColor, onTap: () => setState(() => _selectedMethod = 'email')),
                            _MethodTab(label: 'Téléphone', icon: Icons.phone_outlined, isSelected: _selectedMethod == 'phone', accentColor: accentColor, onTap: () => setState(() => _selectedMethod = 'phone')),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(anim), child: child)),
                          child: _selectedMethod == 'email'
                              ? _InputCard(key: const ValueKey('email'), label: 'ADRESSE EMAIL', hint: 'exemple@email.com', icon: Icons.mail_outline_rounded, controller: _emailController, keyboardType: TextInputType.emailAddress, info: 'Nous vous enverrons un lien de réinitialisation par email.', accentColor: accentColor)
                              : _InputCard(key: const ValueKey('phone'), label: 'NUMÉRO DE TÉLÉPHONE', hint: '+213 6 00 00 00 00', icon: Icons.phone_outlined, controller: _phoneController, keyboardType: TextInputType.phone, info: 'Nous vous enverrons un SMS avec un code de vérification.', accentColor: accentColor),
                        ),

                        const SizedBox(height: 32),
                        CustomButton(
                          label: _selectedMethod == 'email' ? 'Envoyer le lien' : 'Envoyer le code SMS',
                          onTap: _handleSend, isLoading: _isLoading, color: accentColor,
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textGrey),
                            const SizedBox(width: 6),
                            const Text('Retour à la connexion', style: TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        const SizedBox(height: 40),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String label, hint, info;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final Color accentColor;

  const _InputCard({super.key, required this.label, required this.hint, required this.icon, required this.controller, required this.keyboardType, required this.info, required this.accentColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textGrey, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      CustomTextField(controller: controller, hintText: hint, prefixIcon: icon, keyboardType: keyboardType, accentColor: accentColor),
      const SizedBox(height: 10),
      Text(info, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
    ]),
  );
}

class _MethodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  const _MethodTab({required this.label, required this.icon, required this.isSelected, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textGrey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textGrey)),
        ]),
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final Color accentColor;
  final String method, value;
  final VoidCallback onBack, onResend;
  const _SuccessView({required this.accentColor, required this.method, required this.value, required this.onBack, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final isEmail = method == 'email';
    return Column(children: [
      const SizedBox(height: 80),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, size: 50, color: accentColor),
        ),
      ),
      const SizedBox(height: 28),
      Text(isEmail ? 'Email envoyé !' : 'SMS envoyé !',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(isEmail ? 'Un lien de réinitialisation a été envoyé à' : 'Un code a été envoyé au',
        style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accentColor), textAlign: TextAlign.center),
      const SizedBox(height: 48),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: onBack,
        style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
        child: const Text('Retour à la connexion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),
      TextButton(
        onPressed: onResend,
        child: Text('Renvoyer le ${isEmail ? "lien" : "code"}',
          style: const TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
      ),
      const SizedBox(height: 40),
    ]);
  }
}
