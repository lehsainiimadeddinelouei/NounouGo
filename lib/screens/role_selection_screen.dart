import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onRoleSelected(String role) {
    setState(() => _selectedRole = role);
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(role: role),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.backgroundGradientStart, AppColors.backgroundGradientEnd],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      errorBuilder: (_, __, ___) => const Text(
                        'NounouGo',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Vous êtes...',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            role: 'Parent',
                            label: 'Cherche\nnounou',
                            subtitle: 'Parent',
                            imagePath: 'assets/images/parent.png',
                            isSelected: _selectedRole == 'Parent',
                            selectedColor: AppColors.primaryBlue,
                            accentColor: AppColors.buttonBlue,
                            onTap: () => _onRoleSelected('Parent'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _RoleCard(
                            role: 'Babysitter',
                            label: 'Nounou\n♥',
                            subtitle: 'Babysitter',
                            imagePath: 'assets/images/babysitter.png',
                            isSelected: _selectedRole == 'Babysitter',
                            selectedColor: AppColors.primaryPink,
                            accentColor: AppColors.primaryPink,
                            onTap: () => _onRoleSelected('Babysitter'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dot(active: true),
                        const SizedBox(width: 6),
                        _Dot(active: false),
                        const SizedBox(width: 6),
                        _Dot(active: false),
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

class _RoleCard extends StatefulWidget {
  final String role, label, subtitle, imagePath;
  final bool isSelected;
  final Color selectedColor, accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role, required this.label, required this.subtitle,
    required this.imagePath, required this.isSelected,
    required this.selectedColor, required this.accentColor, required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this, lowerBound: 0.95, upperBound: 1.0, value: 1.0,
    );
  }

  @override
  void dispose() { _scaleController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) { _scaleController.forward(); widget.onTap(); },
      onTapCancel: () => _scaleController.forward(),
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (_, child) => Transform.scale(scale: _scaleController.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected ? widget.selectedColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.isSelected ? widget.accentColor : Colors.transparent, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text(widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: widget.isSelected ? widget.accentColor : AppColors.textDark, height: 1.3)),
            const SizedBox(height: 16),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accentColor.withValues(alpha: 0.1)),
              child: ClipOval(child: Image.asset(widget.imagePath, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      widget.role == 'Parent' ? Icons.family_restroom : Icons.child_care,
                      size: 48, color: widget.accentColor))),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isSelected ? widget.accentColor : widget.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(widget.subtitle,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: widget.isSelected ? Colors.white : widget.accentColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 8, height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryPink : AppColors.softPink,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
