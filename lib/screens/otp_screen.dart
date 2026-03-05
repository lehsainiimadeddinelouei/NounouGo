import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/otp_service.dart';

class OtpScreen extends StatefulWidget {
  final String role;
  final String uid;
  final String maskedEmail;
  final String? devCode; // affiché temporairement si email échoue

  const OtpScreen({
    super.key,
    required this.role,
    required this.uid,
    required this.maskedEmail,
    this.devCode,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isVerified = false;
  int _resendSeconds = 60;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { if (_resendSeconds > 0) _resendSeconds--; });
      return _resendSeconds > 0;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _fullCode => _controllers.map((c) => c.text).join();

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.primaryPink : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _handleVerify() async {
    if (_fullCode.length < 6) {
      _showSnack('Veuillez saisir les 6 chiffres du code.');
      return;
    }
    setState(() => _isLoading = true);
    final result = await OtpService.verifyOtp(uid: widget.uid, code: _fullCode);
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _isVerified = true);
    } else {
      _showSnack(result.message);
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
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
                child: _isVerified
                    ? _SuccessView(accentColor: accentColor)
                    : Column(
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(Icons.mark_email_read_outlined, size: 36, color: accentColor),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Vérification',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
                              children: [
                                const TextSpan(text: 'Code envoyé à\n'),
                                TextSpan(
                                  text: widget.maskedEmail,
                                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),

                          // ⚠️ Affiche le code si l'email n'a pas pu être envoyé
                          if (widget.devCode != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Column(children: [
                                const Text('⚠️ Email non envoyé - Code de test :',
                                  style: TextStyle(fontSize: 12, color: Colors.orange),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(widget.devCode!,
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.orange, letterSpacing: 8),
                                  textAlign: TextAlign.center,
                                ),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 36),

                          // ── 6 cases OTP ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (i) => _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              accentColor: accentColor,
                              onChanged: (val) {
                                if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                                else if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                                if (_fullCode.length == 6) _handleVerify();
                              },
                            )),
                          ),

                          const SizedBox(height: 36),

                          CustomButton(
                            label: 'Vérifier le code',
                            onTap: _handleVerify,
                            isLoading: _isLoading,
                            color: accentColor,
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Pas reçu le code ? ', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                              _resendSeconds > 0
                                  ? Text('${_resendSeconds}s', style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w700))
                                  : GestureDetector(
                                      onTap: () {
                                        setState(() => _resendSeconds = 60);
                                        _startCountdown();
                                      },
                                      child: Text('Renvoyer', style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w700)),
                                    ),
                            ],
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;
  final Function(String) onChanged;

  const _OtpBox({required this.controller, required this.focusNode, required this.accentColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accentColor),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: accentColor.withOpacity(0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accentColor.withOpacity(0.2), width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accentColor, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accentColor.withOpacity(0.2), width: 1.5)),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final Color accentColor;
  const _SuccessView({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 100),
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
      const Text('Identité vérifiée !',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text('Vous êtes maintenant connecté.',
        style: TextStyle(fontSize: 14, color: AppColors.textGrey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 48),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () { /* TODO: navigate to home */ },
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text("Accéder à l'application", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
