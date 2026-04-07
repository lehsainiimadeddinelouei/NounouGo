import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'role_selection_screen.dart'; // ← écran suivant

// ═══════════════════════════════════════════════════════════════
//  WELCOME SCREEN — NounouGo
//  Onboarding 3 pages avec swipe, indicateurs et animations
// ═══════════════════════════════════════════════════════════════

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // ── Pages d'onboarding ──────────────────────────────────────
  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      icon: Icons.search_rounded,
      title: 'Trouvez votre\nnounou idéale',
      description:
          'Parcourez des centaines de profils vérifiés de nounous qualifiées dans votre quartier. Filtrez par disponibilité, expérience et tarif.',
      gradient: [Color(0xFF3D5A8A), Color(0xFF5A7DB5)],
      accentColor: Color(0xFF4A7FD4),
      features: ['Profils vérifiés', 'Géolocalisation', 'Filtres avancés'],
      featureIcons: [Icons.verified_rounded, Icons.location_on_rounded, Icons.tune_rounded],
    ),
    _OnboardPage(
      icon: Icons.calendar_month_rounded,
      title: 'Réservez en\nquelques clics',
      description:
          'Planifiez vos gardes, gérez les horaires et recevez des confirmations instantanées. Tout est centralisé dans votre espace.',
      gradient: [Color(0xFFC8384E), Color(0xFFE8748A)],
      accentColor: Color(0xFFE8748A),
      features: ['Réservation rapide', 'Calendrier intégré', 'Paiement sécurisé'],
      featureIcons: [Icons.bolt_rounded, Icons.date_range_rounded, Icons.lock_rounded],
    ),
    _OnboardPage(
      icon: Icons.star_rounded,
      title: 'Une relation de\nconfiance',
      description:
          'Évaluez les nounous, échangez des messages en temps réel et suivez l\'historique de vos gardes. La sécurité de vos enfants, notre priorité.',
      gradient: [Color(0xFF1E6B4A), Color(0xFF3DAB80)],
      accentColor: Color(0xFF3DAB80),
      features: ['Avis certifiés', 'Messagerie intégrée', 'Suivi en temps réel'],
      featureIcons: [Icons.chat_bubble_rounded, Icons.phone_android_rounded, Icons.shield_rounded],
    ),
  ];

  int _currentPage = 0;
  late PageController _pageCtrl;

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _featureCtrl;

  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _emojiScale;
  late Animation<double> _floatY;
  late Animation<double> _bgProgress;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();

    // Entry
    _entryCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _entryFade = CurvedAnimation(
        parent: _entryCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryCtrl, curve: Curves.easeOutCubic));
    _emojiScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl, curve: const Interval(0.1, 0.8, curve: Curves.elasticOut)),
    );

    // Flottement emoji
    _floatCtrl = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: -10.0, end: 10.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Fond
    _bgCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bgProgress = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    // Features
    _featureCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _entryCtrl.forward();
    _featureCtrl.forward();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _entryCtrl.reset();
    _featureCtrl.reset();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _featureCtrl.forward();
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToApp();
    }
  }

  void _navigateToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _bgCtrl.dispose();
    _featureCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entryCtrl,
          _floatCtrl,
          _featureCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Fond dégradé animé ────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      page.gradient[0],
                      page.gradient[1],
                      Colors.white.withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),

              // ── Cercles décoratifs de fond ────────────────────
              _buildBgDecor(size, page),

              // ── PageView principal ────────────────────────────
              PageView.builder(
                controller: _pageCtrl,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  if (i != _currentPage) {
                    return _buildPage(_pages[i], size, animated: false);
                  }
                  return _buildPage(page, size, animated: true);
                },
              ),

              // ── Barre de navigation bas ───────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomNav(page),
              ),

              // ── Bouton Skip ───────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: _currentPage < _pages.length - 1
                    ? TextButton(
                        onPressed: _navigateToApp,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Passer',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.white.withOpacity(0.8)),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PAGE CONTENT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPage(_OnboardPage page, Size size,
      {required bool animated}) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: MediaQuery.of(context).padding.top + 48,
        bottom: 160,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Icon flottant ────────────────────────────
          animated
              ? Transform.translate(
                  offset: Offset(0, _floatY.value),
                  child: ScaleTransition(
                    scale: _emojiScale,
                    child: _buildEmojiBlob(page),
                  ),
                )
              : _buildEmojiBlob(page),

          const SizedBox(height: 28),

          // ── Titre ────────────────────────────────────
          animated
              ? FadeTransition(
                  opacity: _entryFade,
                  child: SlideTransition(
                    position: _entrySlide,
                    child: _buildTitle(page),
                  ),
                )
              : _buildTitle(page),

          const SizedBox(height: 12),

          // ── Description ──────────────────────────────
          animated
              ? FadeTransition(
                  opacity: _entryFade,
                  child: _buildDescription(page),
                )
              : _buildDescription(page),

          const SizedBox(height: 22),

          // ── Feature chips ─────────────────────────────
          ...List.generate(page.features.length, (i) {
            final delay = i * 0.25;
            final anim = animated
                ? Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(
                      parent: _featureCtrl,
                      curve: Interval(
                          delay.clamp(0.0, 0.6),
                          (delay + 0.4).clamp(0.0, 1.0),
                          curve: Curves.easeOut),
                    ),
                  )
                : const AlwaysStoppedAnimation(1.0);

            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.15, 0),
                  end: Offset.zero,
                ).animate(anim as Animation<double>),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFeatureChip(
                      page.featureIcons[i], page.features[i], page.accentColor),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmojiBlob(_OnboardPage page) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Center(
        child: Icon(page.icon, color: Colors.white, size: 52),
      ),
    );
  }

  Widget _buildTitle(_OnboardPage page) {
    return Text(
      page.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.2,
        fontFamily: 'Nunito',
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDescription(_OnboardPage page) {
    return Text(
      page.description,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: Colors.white.withOpacity(0.82),
        height: 1.65,
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildFeatureChip(IconData iconData, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(iconData, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Nunito',
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomNav(_OnboardPage page) {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            page.gradient[0].withOpacity(0.95),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Indicateurs de page
          Row(
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 8),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Bouton suivant / commencer
          GestureDetector(
            onTap: _nextPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: EdgeInsets.symmetric(
                horizontal: isLast ? 28 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: page.gradient[0],
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      fontFamily: 'Nunito',
                    ),
                    child: Text(isLast ? 'Commencer !' : 'Suivant'),
                  ),
                  if (!isLast) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: page.gradient[0], size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DÉCORATIONS FOND
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBgDecor(Size size, _OnboardPage page) {
    final t = _floatCtrl.value;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BgDecorPainter(
            page: _currentPage,
            t: t,
            accentColor: page.accentColor,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BG DECOR PAINTER
// ═══════════════════════════════════════════════════════════════

class _BgDecorPainter extends CustomPainter {
  final int page;
  final double t;
  final Color accentColor;

  const _BgDecorPainter({
    required this.page,
    required this.t,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Cercle haut-droite
    paint.color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(
      Offset(size.width + 40, -40 + t * 8),
      160,
      paint,
    );

    // Cercle bas-gauche
    paint.color = Colors.white.withOpacity(0.05);
    canvas.drawCircle(
      Offset(-60, size.height + 20 - t * 10),
      180,
      paint,
    );

    // Petits points décoratifs
    paint.color = Colors.white.withOpacity(0.15);
    final dotPositions = [
      Offset(size.width * 0.08, size.height * 0.35 + t * 5),
      Offset(size.width * 0.92, size.height * 0.55 - t * 6),
      Offset(size.width * 0.15, size.height * 0.78 + t * 4),
      Offset(size.width * 0.82, size.height * 0.82 - t * 5),
    ];
    for (final pos in dotPositions) {
      canvas.drawCircle(pos, 5, paint);
    }

    // Accent lumineux haut-gauche
    paint.shader = RadialGradient(
      colors: [
        accentColor.withOpacity(0.25),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.1, size.height * 0.1),
      radius: 200,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.1),
      200,
      paint,
    );
    paint.shader = null;
  }

  @override
  bool shouldRepaint(_BgDecorPainter old) =>
      old.t != t || old.page != page;
}

// ═══════════════════════════════════════════════════════════════
//  DATA MODEL
// ═══════════════════════════════════════════════════════════════

class _OnboardPage {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final Color accentColor;
  final List<String> features;
  final List<IconData> featureIcons;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.accentColor,
    required this.features,
    required this.featureIcons,
  });
}
