import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'parent_home_screen.dart';
import 'babysitter_home_screen.dart';
import 'admin_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SPLASH SCREEN — NounouGo
//  Animation séquencée : fond → logo → texte → tagline → redirect
// ═══════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  late AnimationController _bgCtrl;        // gradient de fond
  late AnimationController _orbitCtrl;     // orbites tournantes
  late AnimationController _logoCtrl;      // apparition logo
  late AnimationController _pulseCtrl;     // pulsation logo
  late AnimationController _textCtrl;      // textes
  late AnimationController _shimmerCtrl;   // shimmer ligne
  late AnimationController _exitCtrl;      // fade out final

  // ── Animations ───────────────────────────────────────────────
  late Animation<double> _bgOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotate;
  late Animation<double> _pulse;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _taglineFade;
  late Animation<double> _shimmer;
  late Animation<double> _exitOpacity;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Masquer la status bar pendant le splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // ── Background ──
    _bgCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _bgOpacity = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);

    // ── Orbites ──
    _orbitCtrl = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    // ── Logo ──
    _logoCtrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _logoRotate = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );

    // ── Pulsation ──
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── Textes ──
    _textCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _textCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(
        begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _textCtrl,
          curve: const Interval(0.25, 0.7, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(
        begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic)));
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _textCtrl,
          curve: const Interval(0.55, 1.0, curve: Curves.easeOut)),
    );

    // ── Shimmer ──
    _shimmerCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // ── Exit ──
    _exitCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 1. Fond
    await _bgCtrl.forward();
    // 2. Logo (avec légère superposition)
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    // 3. Textes
    _textCtrl.forward();
    // 4. Attendre que tout soit bien visible + vérifier la session en parallèle
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!_navigated && mounted) {
      _navigated = true;

      // 5. Vérifier si un utilisateur est déjà connecté
      final user = FirebaseAuth.instance.currentUser;
      Widget destination;

      if (user != null) {
        // Utilisateur déjà connecté → récupérer son rôle depuis Firestore
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final role = doc.data()?['role']?.toString().toLowerCase() ?? 'parent';
          if (role == 'nounou' || role == 'babysitter') {
            destination = const BabysitterHomeScreen();
          } else if (role == 'admin') {
            destination = const AdminScreen();
          } else {
            destination = const ParentHomeScreen();
          }
        } catch (_) {
          // En cas d'erreur réseau, renvoyer vers le welcome
          destination = const WelcomeScreen();
        }
      } else {
        // Pas de session active → écran d'accueil
        destination = const WelcomeScreen();
      }

      // 6. Fade out et navigation
      await _exitCtrl.forward();
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => destination,
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _orbitCtrl.dispose();
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2545),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgCtrl,
          _orbitCtrl,
          _logoCtrl,
          _pulseCtrl,
          _textCtrl,
          _shimmerCtrl,
          _exitCtrl,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitOpacity,
            child: Stack(
              children: [
                // ── Fond dégradé animé ──────────────────────────
                FadeTransition(
                  opacity: _bgOpacity,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A2545),
                          Color(0xFF2D3E6F),
                          Color(0xFF3D2545),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Cercles orbitaux décoratifs ─────────────────
                ..._buildOrbits(size),

                // ── Particules flottantes ───────────────────────
                ..._buildParticles(size),

                // ── Contenu central ────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo animé
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: RotationTransition(
                            turns: _logoRotate,
                            child: ScaleTransition(
                              scale: _pulse,
                              child: _buildLogo(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Titre principal
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: _buildTitle(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Sous-titre
                      SlideTransition(
                        position: _subtitleSlide,
                        child: FadeTransition(
                          opacity: _subtitleFade,
                          child: _buildSubtitle(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Ligne shimmer
                      FadeTransition(
                        opacity: _taglineFade,
                        child: _buildShimmerLine(),
                      ),

                      const SizedBox(height: 20),

                      // Tagline
                      FadeTransition(
                        opacity: _taglineFade,
                        child: _buildTagline(),
                      ),
                    ],
                  ),
                ),

                // ── Loader bas de page ──────────────────────────
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _taglineFade,
                    child: _buildLoader(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WIDGETS INTERNES
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8FAB), Color(0xFFE8748A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8748A).withOpacity(0.6),
            blurRadius: 40,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: const Color(0xFFE8748A).withOpacity(0.3),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo intérieur
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          // Icône
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.child_care_rounded, color: Colors.white, size: 52),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Color(0xFFFFFFFF), Color(0xFFFFD6E0), Color(0xFFFFFFFF)],
        stops: [
          (_shimmer.value - 0.5).clamp(0.0, 1.0),
          _shimmer.value.clamp(0.0, 1.0),
          (_shimmer.value + 0.5).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: const Text(
        'NounouGo',
        style: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.5,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.transparent, Color(0xFFE8748A)],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'La garde d\'enfants réinventée',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFFCDD8F0),
            letterSpacing: 0.8,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 30,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8748A), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLine() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        return Container(
          width: 200,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Colors.transparent,
                Color(0xFFE8748A),
                Colors.white,
                Color(0xFFE8748A),
                Colors.transparent,
              ],
              stops: [
                0.0,
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
                1.0,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 48),
      child: Text(
        'Trouvez la nounou parfaite\nen quelques secondes',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF8899CC),
          height: 1.6,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFFE8748A).withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Chargement…',
          style: TextStyle(
            color: Color(0xFF5566AA),
            fontSize: 12,
            letterSpacing: 1.2,
            fontFamily: 'Nunito',
          ),
        ),
      ],
    );
  }

  // ── Orbites ─────────────────────────────────────────────────
  List<Widget> _buildOrbits(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final angle = _orbitCtrl.value * 2 * math.pi;

    return [
      // Orbite 1 — grande
      Positioned.fill(
        child: CustomPaint(
          painter: _OrbitPainter(
            cx: cx,
            cy: cy,
            radius: 180,
            angle: angle,
            color: const Color(0xFFE8748A).withOpacity(0.12),
            dotColor: const Color(0xFFE8748A).withOpacity(0.9),
            dotRadius: 6,
          ),
        ),
      ),
      // Orbite 2 — moyenne, sens inverse
      Positioned.fill(
        child: CustomPaint(
          painter: _OrbitPainter(
            cx: cx,
            cy: cy,
            radius: 230,
            angle: -angle * 0.7,
            color: const Color(0xFF4A7FD4).withOpacity(0.08),
            dotColor: const Color(0xFF4A7FD4).withOpacity(0.8),
            dotRadius: 4,
          ),
        ),
      ),
      // Orbite 3 — petite, rapide
      Positioned.fill(
        child: CustomPaint(
          painter: _OrbitPainter(
            cx: cx,
            cy: cy,
            radius: 140,
            angle: angle * 1.5,
            color: Colors.transparent,
            dotColor: Colors.white.withOpacity(0.6),
            dotRadius: 3,
          ),
        ),
      ),
    ];
  }

  // ── Particules flottantes ────────────────────────────────────
  List<Widget> _buildParticles(Size size) {
    final List<_ParticleData> particles = [
      _ParticleData(0.15, 0.18, 8, const Color(0xFFFF8FAB), 0.0),
      _ParticleData(0.80, 0.12, 5, const Color(0xFF4A7FD4), 0.33),
      _ParticleData(0.10, 0.72, 6, const Color(0xFFE8748A), 0.66),
      _ParticleData(0.85, 0.78, 9, const Color(0xFFFFD6E0), 0.1),
      _ParticleData(0.50, 0.08, 4, Colors.white, 0.5),
      _ParticleData(0.92, 0.45, 5, const Color(0xFF4A7FD4), 0.8),
    ];

    return particles.map((p) {
      final phase = (_orbitCtrl.value + p.phase) % 1.0;
      final dy = math.sin(phase * 2 * math.pi) * 12;

      return Positioned(
        left: size.width * p.x - p.r,
        top: size.height * p.y + dy - p.r,
        child: Container(
          width: p.r * 2,
          height: p.r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.color.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: p.color.withOpacity(0.4),
                blurRadius: p.r * 2,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
//  ORBIT PAINTER
// ═══════════════════════════════════════════════════════════════

class _OrbitPainter extends CustomPainter {
  final double cx, cy, radius, angle;
  final Color color, dotColor;
  final double dotRadius;

  _OrbitPainter({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.angle,
    required this.color,
    required this.dotColor,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Cercle orbital
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), radius, circlePaint);

    // Dot orbitant
    final dotX = cx + radius * math.cos(angle);
    final dotY = cy + radius * math.sin(angle);
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);

    // Traînée lumineuse
    final trailPaint = Paint()
      ..shader = RadialGradient(
        colors: [dotColor.withOpacity(0.6), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(dotX, dotY), radius: dotRadius * 4));
    canvas.drawCircle(Offset(dotX, dotY), dotRadius * 4, trailPaint);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
//  DATA CLASSES
// ═══════════════════════════════════════════════════════════════

class _ParticleData {
  final double x, y, r, phase;
  final Color color;
  const _ParticleData(this.x, this.y, this.r, this.color, this.phase);
}