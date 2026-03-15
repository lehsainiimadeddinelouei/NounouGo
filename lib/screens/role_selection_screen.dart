import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────
// ROLE SELECTION SCREEN — Premium animated entry
// ─────────────────────────────────────────────────────────────
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  String? _selectedRole;

  // Animation controllers
  late AnimationController _entryCtrl;
  late AnimationController _bubblesCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;

  // Entry animations
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _card1Fade;
  late Animation<Offset> _card1Slide;
  late Animation<double> _card2Fade;
  late Animation<Offset> _card2Slide;
  late Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bubblesCtrl = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Staggered entry animations
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.2, 0.55, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)),
    );
    _card1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.4, 0.75, curve: Curves.easeOut)),
    );
    _card1Slide = Tween<Offset>(begin: const Offset(-0.3, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic)),
    );
    _card2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.5, 0.85, curve: Curves.easeOut)),
    );
    _card2Slide = Tween<Offset>(begin: const Offset(0.3, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic)),
    );
    _bottomFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.75, 1.0, curve: Curves.easeOut)),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bubblesCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _onRoleSelected(String role) {
    setState(() => _selectedRole = role);
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(role: role),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond dégradé chaud ──────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF5F8),
                  Color(0xFFFFF0F5),
                  Color(0xFFF8F0FF),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Bulles flottantes animées ───────────────────
          AnimatedBuilder(
            animation: _bubblesCtrl,
            builder: (_, __) => CustomPaint(
              size: Size(size.width, size.height),
              painter: _BubblesPainter(_bubblesCtrl.value),
            ),
          ),

          // ── Contenu principal ───────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height
                      - MediaQuery.of(context).padding.top
                      - MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // ── Titre ────────────────────────────
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Column(children: [
                          // "Bienvenue sur" avec icône
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF6B8A), Color(0xFFFFB347)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.child_friendly_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFFF6B8A), Color(0xFF9B59B6)],
                                ).createShader(bounds),
                                child: const Text(
                                  'Bienvenue sur NounouGo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Vous êtes...',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1B2E),
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 48,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B8A), Color(0xFFFFB347)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Cartes de rôle ───────────────────
                    Row(children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: _card1Fade,
                          child: SlideTransition(
                            position: _card1Slide,
                            child: _RoleCard(
                              role: 'Parent',
                              title: 'Je cherche\nune nounou',
                              subtitle: 'Parent',
                              icon: Icons.family_restroom_rounded,
                              decorIcons: const [
                                Icons.home_rounded,
                                Icons.favorite_rounded,
                                Icons.child_care_rounded,
                              ],
                              isSelected: _selectedRole == 'Parent',
                              gradientColors: const [Color(0xFF5B7FFF), Color(0xFF3A5FCC)],
                              accentColor: const Color(0xFF5B7FFF),
                              shimmerCtrl: _shimmerCtrl,
                              pulseCtrl: _pulseCtrl,
                              onTap: () => _onRoleSelected('Parent'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FadeTransition(
                          opacity: _card2Fade,
                          child: SlideTransition(
                            position: _card2Slide,
                            child: _RoleCard(
                              role: 'Babysitter',
                              title: 'Je suis\nune nounou',
                              subtitle: 'Babysitter',
                              icon: Icons.child_care_rounded,
                              decorIcons: const [
                                Icons.stars_rounded,
                                Icons.volunteer_activism_rounded,
                                Icons.emoji_emotions_rounded,
                              ],
                              isSelected: _selectedRole == 'Babysitter',
                              gradientColors: const [Color(0xFFFF6B8A), Color(0xFFE04570)],
                              accentColor: const Color(0xFFFF6B8A),
                              shimmerCtrl: _shimmerCtrl,
                              pulseCtrl: _pulseCtrl,
                              onTap: () => _onRoleSelected('Babysitter'),
                            ),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Bas de page ──────────────────────
                    FadeTransition(
                      opacity: _bottomFade,
                      child: Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Dot(active: true, color: const Color(0xFFFF6B8A)),
                            const SizedBox(width: 6),
                            _Dot(active: false, color: const Color(0xFFFFB7CC)),
                            const SizedBox(width: 6),
                            _Dot(active: false, color: const Color(0xFFFFB7CC)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sélectionnez votre profil pour continuer',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF1E1B2E).withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARTE DE RÔLE — avec shimmer + scale + glow
// ─────────────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final String role;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<IconData> decorIcons;
  final bool isSelected;
  final List<Color> gradientColors;
  final Color accentColor;
  final AnimationController shimmerCtrl;
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.decorIcons,
    required this.isSelected,
    required this.gradientColors,
    required this.accentColor,
    required this.shimmerCtrl,
    required this.pulseCtrl,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  // Petites icônes qui orbitent autour de l'avatar
  List<Widget> _buildOrbitIcons(double pulse) {
    final icons = widget.decorIcons;
    final color = widget.accentColor;
    final isSelected = widget.isSelected;
    final offsets = [
      const Offset(-46, -22),
      const Offset(46, -22),
      const Offset(0, 52),
    ];

    return List.generate(icons.length, (i) {
      final o = offsets[i];
      // Les orbites bougent TOUJOURS — amplitude plus grande si sélectionné
      final amplitude = isSelected ? 4.0 : 2.0;
      return Transform.translate(
        offset: Offset(
          o.dx + math.sin(pulse * math.pi * 2 + i * 2.1) * amplitude,
          o.dy + math.cos(pulse * math.pi * 2 + i * 1.7) * amplitude * 0.7,
        ),
        child: AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.65,
          duration: const Duration(milliseconds: 250),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.22)
                  : color.withValues(alpha: 0.12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.35)
                    : color.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                  : null,
            ),
            child: Icon(
              icons[i],
              size: 13,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _pressCtrl.animateTo(0.93,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeIn);
      },
      onTapUp: (_) {
        _pressCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.elasticOut);
        widget.onTap();
      },
      onTapCancel: () {
        _pressCtrl.animateTo(1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressCtrl, widget.pulseCtrl, widget.shimmerCtrl]),
        builder: (_, __) {
          final pulse = widget.pulseCtrl.value;
          final shimmer = widget.shimmerCtrl.value;

          return Transform.scale(
            scale: _pressCtrl.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: widget.isSelected ? null : Colors.white,
                gradient: widget.isSelected
                    ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.gradientColors[0],
                    widget.gradientColors[1],
                  ],
                )
                    : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.transparent
                      : widget.accentColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35 + pulse * 0.12),
                    blurRadius: 24 + pulse * 8,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // ── Shimmer overlay (when selected) ──
                    if (widget.isSelected)
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset((shimmer * 2 - 1) * 260, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Cercles décoratifs ────────────────
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSelected
                              ? Colors.white.withValues(alpha: 0.1)
                              : widget.accentColor.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -15,
                      bottom: -15,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSelected
                              ? Colors.white.withValues(alpha: 0.07)
                              : widget.accentColor.withValues(alpha: 0.04),
                        ),
                      ),
                    ),

                    // ── Contenu ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        children: [

                          // Avatar icônes avec halo — Stack de taille fixe 110x110
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Halo pulsant
                                if (widget.isSelected)
                                  Container(
                                    width: 86 + pulse * 5,
                                    height: 86 + pulse * 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                // Cercle principal avec icône centrale
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : widget.accentColor.withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: widget.isSelected
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : widget.accentColor.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 32,
                                    color: widget.isSelected
                                        ? Colors.white
                                        : widget.accentColor,
                                  ),
                                ),
                                // Icônes décoratives orbitales
                                ..._buildOrbitIcons(pulse),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Titre
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: widget.isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E1B2E),
                              height: 1.35,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Badge rôle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : widget.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.isSelected
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : widget.accentColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isSelected
                                      ? Icons.check_circle_rounded
                                      : widget.icon,
                                  size: 13,
                                  color: widget.isSelected
                                      ? Colors.white
                                      : widget.accentColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.isSelected
                                      ? 'Sélectionné ✓'
                                      : widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isSelected
                                        ? Colors.white
                                        : widget.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BULLES FLOTTANTES (CustomPainter)
// ─────────────────────────────────────────────────────────────
class _BubblesPainter extends CustomPainter {
  final double t;

  static final _rng = math.Random(42);
  static final List<_Bubble> _bubbles = List.generate(14, (i) {
    return _Bubble(
      x: _rng.nextDouble(),
      yStart: _rng.nextDouble(),
      radius: 6.0 + _rng.nextDouble() * 22,
      speed: 0.12 + _rng.nextDouble() * 0.22,
      phase: _rng.nextDouble() * math.pi * 2,
      opacity: 0.04 + _rng.nextDouble() * 0.08,
      color: _rng.nextBool()
          ? const Color(0xFFFF6B8A)
          : const Color(0xFF5B7FFF),
    );
  });

  _BubblesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bubbles) {
      final y = ((b.yStart - t * b.speed) % 1.0 + 1.0) % 1.0;
      final wobble = math.sin(t * math.pi * 2 * 1.3 + b.phase) * 12;
      final cx = b.x * size.width + wobble;
      final cy = y * size.height;

      final paint = Paint()
        ..color = b.color.withValues(alpha: b.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), b.radius, paint);

      // Contour subtil
      final stroke = Paint()
        ..color = b.color.withValues(alpha: b.opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(cx, cy), b.radius, stroke);
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}

class _Bubble {
  final double x, yStart, radius, speed, phase, opacity;
  final Color color;
  const _Bubble({
    required this.x,
    required this.yStart,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────
// INDICATEUR DE PAGES
// ─────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final bool active;
  final Color color;
  const _Dot({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(colors: [color, color.withValues(alpha: 0.6)])
            : null,
        color: active ? null : color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
    );
  }
}
