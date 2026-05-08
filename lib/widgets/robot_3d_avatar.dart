import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum RobotState { idle, listening, thinking, speaking }

class Robot3DAvatar extends StatefulWidget {
  final RobotState state;
  final Color accentColor;
  final double size;

  const Robot3DAvatar({
    super.key,
    this.state = RobotState.idle,
    this.accentColor = const Color(0xFF00E5CC),
    this.size = 260,
  });

  @override
  State<Robot3DAvatar> createState() => _Robot3DAvatarState();
}

class _Robot3DAvatarState extends State<Robot3DAvatar>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _coreCtrl;
  late AnimationController _speakCtrl;
  late AnimationController _headTiltCtrl;
  late AnimationController _armCtrl;

  late Animation<double> _floatAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _coreAnim;
  late Animation<double> _headTiltAnim;
  late Animation<double> _armAnim;

  bool _isBlinking = false;
  Timer? _blinkTimer;
  final _random = Random();

  // Particles
  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  // Mouth bars for speaking
  final List<double> _mouthBars = List.generate(7, (_) => 0.3);
  Timer? _mouthTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startBlink();
    _startParticles();
  }

  void _initAnimations() {
    _floatCtrl = AnimationController(
        duration: const Duration(milliseconds: 3500), vsync: this)
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this)
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _coreCtrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _coreAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _coreCtrl, curve: Curves.easeInOut));

    _speakCtrl = AnimationController(
        duration: const Duration(milliseconds: 120), vsync: this)
      ..addListener(_updateMouthBars);

    _headTiltCtrl = AnimationController(
        duration: const Duration(milliseconds: 4000), vsync: this)
      ..repeat(reverse: true);
    _headTiltAnim = Tween<double>(begin: -0.03, end: 0.03).animate(
        CurvedAnimation(parent: _headTiltCtrl, curve: Curves.easeInOut));

    _armCtrl = AnimationController(
        duration: const Duration(milliseconds: 2500), vsync: this)
      ..repeat(reverse: true);
    _armAnim = Tween<double>(begin: -0.05, end: 0.05).animate(
        CurvedAnimation(parent: _armCtrl, curve: Curves.easeInOut));
  }

  void _updateMouthBars() {
    if (widget.state == RobotState.speaking && mounted) {
      setState(() {
        for (int i = 0; i < _mouthBars.length; i++) {
          _mouthBars[i] = 0.2 + _random.nextDouble() * 0.8;
        }
      });
    }
  }

  @override
  void didUpdateWidget(Robot3DAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _onStateChanged();
    }
  }

  void _onStateChanged() {
    if (widget.state == RobotState.speaking) {
      _speakCtrl.repeat();
      _mouthTimer?.cancel();
    } else {
      _speakCtrl.stop();
      _mouthTimer?.cancel();
      if (mounted) {
        setState(() {
          for (int i = 0; i < _mouthBars.length; i++) {
            _mouthBars[i] = 0.3;
          }
        });
      }
    }
  }

  void _startBlink() {
    _blinkTimer = Timer.periodic(
      Duration(milliseconds: 2500 + _random.nextInt(2500)), (_) {
        if (mounted) {
          setState(() => _isBlinking = true);
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) setState(() => _isBlinking = false);
          });
        }
      },
    );
  }

  void _startParticles() {
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle.random(_random));
    }
    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          for (var p in _particles) {
            p.update();
            if (p.isDead) p.reset(_random);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _particleTimer?.cancel();
    _mouthTimer?.cancel();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _coreCtrl.dispose();
    _speakCtrl.dispose();
    _headTiltCtrl.dispose();
    _armCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _glowAnim, _coreAnim, _headTiltAnim, _armAnim]),
      builder: (context, _) {
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient particles
              ..._buildParticles(s),
              // Glow background
              _buildGlow(s),
              // Tech rings
              _buildTechRings(s),
              // Sound waves (speaking)
              if (widget.state == RobotState.speaking) _buildSoundWaves(s),
              // Listening ripple
              if (widget.state == RobotState.listening) _buildListeningRipple(s),
              // Robot body (transformed with float)
              Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: _buildRobot(s),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(double s) {
    return _particles.map((p) {
      final x = (s / 2) + p.x * (s / 2);
      final y = (s / 2) + p.y * (s / 2);
      return Positioned(
        left: x - 2,
        top: y - 2,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor.withValues(alpha: p.opacity * 0.6),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: p.opacity * 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildGlow(double s) {
    return Container(
      width: s * 0.7,
      height: s * 0.7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: _glowAnim.value * 0.2),
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildTechRings(double s) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: s * 0.85,
          height: s * 0.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
        ),
        // Middle ring (rotating feel via opacity)
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: s * 0.72,
          height: s * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.12 * _glowAnim.value),
              width: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundWaves(double s) {
    return Stack(
      alignment: Alignment.center,
      children: List.generate(3, (i) {
        final waveSize = s * (0.55 + i * 0.12);
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: (1.0 - i * 0.3) * _glowAnim.value * 0.4,
          child: Container(
            width: waveSize,
            height: waveSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildListeningRipple(double s) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _glowAnim.value * 0.5,
      child: Container(
        width: s * 0.65,
        height: s * 0.65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildRobot(double s) {
    return SizedBox(
      width: s * 0.7,
      height: s * 0.82,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Arms (behind body)
          Positioned(
            top: s * 0.38,
            left: 0,
            right: 0,
            child: _buildArms(s),
          ),
          // Torso
          Positioned(
            bottom: 0,
            child: _buildTorso(s),
          ),
          // Neck
          Positioned(
            top: s * 0.32,
            child: _buildNeck(s),
          ),
          // Head (with tilt)
          Positioned(
            top: s * 0.06,
            child: Transform.rotate(
              angle: _headTiltAnim.value,
              child: _buildHead(s),
            ),
          ),
          // Antenna
          Positioned(
            top: 0,
            child: _buildAntenna(s),
          ),
        ],
      ),
    );
  }

  Widget _buildAntenna(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Antenna tip - glowing ball
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: s * 0.045,
          height: s * 0.045,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: _glowAnim.value * 0.9),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        // Antenna stem
        Container(
          width: 2.5,
          height: s * 0.05,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.accentColor.withValues(alpha: 0.8),
                widget.accentColor.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildHead(double s) {
    final headW = s * 0.42;
    final headH = s * 0.36;
    return Container(
      width: headW,
      height: headH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(headW * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A4A6B),
            Color(0xFF1A3350),
            Color(0xFF122640),
          ],
        ),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: 3,
          ),
          const BoxShadow(
            color: Color(0xFF08111F),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          // Highlight for 3D effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Metallic highlight strip (3D effect)
          Positioned(
            top: 6,
            left: headW * 0.15,
            right: headW * 0.15,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Face
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                // Eyes row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEye(s),
                    SizedBox(width: headW * 0.22),
                    _buildEye(s),
                  ],
                ),
                SizedBox(height: headH * 0.12),
                // Mouth
                _buildMouth(s),
              ],
            ),
          ),
          // Side vents (3D detail)
          Positioned(
            left: 5,
            top: headH * 0.35,
            child: _buildVent(s, true),
          ),
          Positioned(
            right: 5,
            top: headH * 0.35,
            child: _buildVent(s, false),
          ),
        ],
      ),
    );
  }

  Widget _buildVent(double s, bool isLeft) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Container(
        width: s * 0.012,
        height: 2,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.2 + i * 0.1),
          borderRadius: BorderRadius.circular(1),
        ),
      )),
    );
  }

  Widget _buildEye(double s) {
    final eyeSize = s * 0.065;
    final eyeH = _isBlinking ? eyeSize * 0.15 : eyeSize;

    Color eyeColor;
    switch (widget.state) {
      case RobotState.listening:
        eyeColor = const Color(0xFFFF6B6B);
        break;
      case RobotState.speaking:
        eyeColor = const Color(0xFF4FC3F7);
        break;
      case RobotState.thinking:
        eyeColor = const Color(0xFFFFD54F);
        break;
      default:
        eyeColor = widget.accentColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: eyeSize,
      height: eyeH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(eyeSize / 2),
        color: eyeColor,
        boxShadow: [
          BoxShadow(
            color: eyeColor.withValues(alpha: 0.8),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: eyeColor.withValues(alpha: 0.4),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMouth(double s) {
    if (widget.state == RobotState.thinking) {
      return SizedBox(
        width: s * 0.08,
        height: s * 0.08,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            const Color(0xFFFFD54F).withValues(alpha: 0.8)),
        ),
      );
    }

    if (widget.state == RobotState.speaking) {
      // Animated speaking bars
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_mouthBars.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: s * 0.015,
            height: s * 0.06 * _mouthBars[i],
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF4FC3F7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          );
        }),
      );
    }

    // Idle / Listening mouth - a line or gentle curve
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: s * 0.1,
      height: widget.state == RobotState.listening ? s * 0.015 : s * 0.012,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: widget.accentColor.withValues(
          alpha: widget.state == RobotState.listening ? 0.7 : 0.4),
        boxShadow: widget.state == RobotState.listening
            ? [BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                blurRadius: 6)]
            : [],
      ),
    );
  }

  Widget _buildNeck(double s) {
    return Container(
      width: s * 0.06,
      height: s * 0.06,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A3350), Color(0xFF162D4A)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildTorso(double s) {
    final torsoW = s * 0.5;
    final torsoH = s * 0.36;
    return Container(
      width: torsoW,
      height: torsoH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(torsoW * 0.22),
          topRight: Radius.circular(torsoW * 0.22),
          bottomLeft: Radius.circular(torsoW * 0.35),
          bottomRight: Radius.circular(torsoW * 0.35),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF162D4A),
            Color(0xFF102540),
          ],
        ),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0xFF0A1628),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chest plate line
          Positioned(
            top: torsoH * 0.15,
            left: torsoW * 0.2,
            right: torsoW * 0.2,
            child: Container(
              height: 1,
              color: widget.accentColor.withValues(alpha: 0.1),
            ),
          ),
          // Power core
          _buildCore(s),
          // Bottom detail
          Positioned(
            bottom: torsoH * 0.12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Container(
                width: s * 0.015,
                height: s * 0.015,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withValues(alpha: 0.15 + i * 0.1),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCore(double s) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: s * 0.1,
      height: s * 0.1,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.accentColor.withValues(alpha: _coreAnim.value * 0.9),
            widget.accentColor.withValues(alpha: _coreAnim.value * 0.3),
            widget.accentColor.withValues(alpha: 0.0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: _coreAnim.value * 0.5),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: s * 0.04,
          height: s * 0.04,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor.withValues(alpha: _coreAnim.value),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor,
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArms(double s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left arm
        Transform.rotate(
          angle: _armAnim.value + 0.15,
          alignment: Alignment.topRight,
          child: _buildArm(s, true),
        ),
        // Right arm
        Transform.rotate(
          angle: -_armAnim.value - 0.15,
          alignment: Alignment.topLeft,
          child: _buildArm(s, false),
        ),
      ],
    );
  }

  Widget _buildArm(double s, bool isLeft) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upper arm
        Container(
          width: s * 0.04,
          height: s * 0.12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s * 0.02),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E3A5F), Color(0xFF162D4A)],
            ),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Hand
        Container(
          width: s * 0.035,
          height: s * 0.035,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s * 0.01),
            color: const Color(0xFF1E3A5F),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// Simple particle class for ambient effects
class _Particle {
  double x, y, vx, vy, opacity, size, life, maxLife;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.opacity,
    required this.size,
    required this.life,
    required this.maxLife,
  });

  factory _Particle.random(Random r) {
    return _Particle(
      x: (r.nextDouble() - 0.5) * 1.8,
      y: (r.nextDouble() - 0.5) * 1.8,
      vx: (r.nextDouble() - 0.5) * 0.005,
      vy: -0.002 - r.nextDouble() * 0.005,
      opacity: 0.3 + r.nextDouble() * 0.5,
      size: 1.5 + r.nextDouble() * 3,
      life: 0,
      maxLife: 80 + r.nextInt(120).toDouble(),
    );
  }

  void update() {
    x += vx;
    y += vy;
    life++;
    opacity = (1.0 - (life / maxLife)) * 0.5;
  }

  bool get isDead => life >= maxLife;

  void reset(Random r) {
    x = (r.nextDouble() - 0.5) * 1.8;
    y = 0.5 + r.nextDouble() * 0.3;
    vx = (r.nextDouble() - 0.5) * 0.005;
    vy = -0.003 - r.nextDouble() * 0.005;
    opacity = 0.3 + r.nextDouble() * 0.5;
    size = 1.5 + r.nextDouble() * 3;
    life = 0;
    maxLife = 80 + r.nextInt(120).toDouble();
  }
}
