import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController(); // email ou téléphone
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isPhoneMode = false; // true si l'utilisateur saisit un numéro

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    // Détecter si c'est un numéro de téléphone
    _identifierController.addListener(() {
      final text = _identifierController.text.trim();
      final isPhone = RegExp(r'^[+0-9][0-9\s\-]{5,}$').hasMatch(text);
      if (isPhone != _isPhoneMode) {
        setState(() => _isPhoneMode = isPhone);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogin() async {
    final input = _identifierController.text.trim();
    if (input.isEmpty) {
      _showSnack('Veuillez saisir votre email ou téléphone.');
      return;
    }

    setState(() => _isLoading = true);

    // ── Connexion par TÉLÉPHONE → OTP par email ──
    if (_isPhoneMode) {
      final result = await OtpService.sendOtpByPhone(phone: input);
      setState(() => _isLoading = false);

      if (result.success) {
        if (!mounted) return;
        Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => OtpScreen(
            role: widget.role,
            uid: result.uid!,
            maskedEmail: result.email!,
            devCode: result.devCode,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      } else {
        _showSnack(result.message);
      }
      return;
    }

    // ── Connexion par EMAIL + MOT DE PASSE ──
    if (_passwordController.text.isEmpty) {
      setState(() => _isLoading = false);
      _showSnack('Veuillez saisir votre mot de passe.');
      return;
    }

    final result = await AuthService.login(
      email: input,
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (result.success) {
      _showSnack('Connexion réussie !', isError: false);
      // TODO: navigate to home screen
    } else {
      _showSnack(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'Parent';
    final accentColor =
    isParent ? AppColors.buttonBlue : AppColors.primaryPink;

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

                    // Back
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4))],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: AppColors.textDark),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text('Connexion',
                      style: TextStyle(fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.role == 'Parent'
                          ? 'Trouvez la nounou idéale'
                          : 'Gérez vos missions de baby-sitting',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 30,
                            offset: const Offset(0, 10))],
                      ),
                      child: Column(children: [

                        // ── Champ email ou téléphone ──
                        CustomTextField(
                          controller: _identifierController,
                          hintText: 'Email ou numéro de téléphone',
                          prefixIcon: _isPhoneMode
                              ? Icons.phone_outlined
                              : Icons.mail_outline_rounded,
                          keyboardType: _isPhoneMode
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          accentColor: accentColor,
                        ),

                        // ── Badge indicateur mode ──
                        if (_isPhoneMode) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.info_outline,
                                size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Un code OTP sera envoyé à votre email',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                  fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ],

                        // ── Champ mot de passe (email uniquement) ──
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _isPhoneMode
                              ? const SizedBox.shrink()
                              : Column(children: [
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              hintText: 'Mot de passe',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              accentColor: accentColor,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.primaryPink,
                                  size: 20,
                                ),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 28),

                        CustomButton(
                          label: _isPhoneMode
                              ? 'Envoyer le code OTP'
                              : 'Se connecter',
                          onTap: _handleLogin,
                          isLoading: _isLoading,
                          color: accentColor,
                        ),

                        if (!_isPhoneMode) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) =>
                                      ForgotPasswordScreen(role: widget.role),
                                  transitionsBuilder: (_, anim, __, child) =>
                                      FadeTransition(
                                          opacity: anim, child: child),
                                  transitionDuration:
                                  const Duration(milliseconds: 400),
                                )),
                            child: Text('Mot de passe oublié ?',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            RegisterScreen(role: widget.role),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 400),
                      )),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border:
                          Border.all(color: AppColors.inputBorder, width: 1.5),
                        ),
                        child: Text('Créer un compte',
                          style: TextStyle(
                              fontSize: 15,
                              color: accentColor,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

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
