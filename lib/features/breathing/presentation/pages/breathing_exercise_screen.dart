import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safespace/core/theme/app_colors.dart';

enum BreathingTechnique {
  box(
    name: 'Square/Box',
    description: 'Relieve stress, improve focus.',
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
  ),
  technique478(
    name: '4-7-8 Static',
    description: 'The natural tranquilizer.',
    inhale: 4,
    holdIn: 7,
    exhale: 8,
    holdOut: 0,
  ),
  relax(
    name: 'Deep Relax',
    description: 'Calm the nervous system.',
    inhale: 4,
    holdIn: 2,
    exhale: 6,
    holdOut: 0,
  ),
  focus(
    name: 'Morning Focus',
    description: 'Energize and sharpen mind.',
    inhale: 3,
    holdIn: 1,
    exhale: 3,
    holdOut: 0,
  );

  final String name;
  final String description;
  final int inhale;
  final int holdIn;
  final int exhale;
  final int holdOut;

  const BreathingTechnique({
    required this.name,
    required this.description,
    required this.inhale,
    required this.holdIn,
    required this.exhale,
    required this.holdOut,
  });
}

enum BreathingPhase {
  inhale,
  holdIn,
  exhale,
  holdOut,
  stopped;

  String get label {
    switch (this) {
      case BreathingPhase.inhale:
        return 'Inhale';
      case BreathingPhase.holdIn:
        return 'Hold';
      case BreathingPhase.exhale:
        return 'Exhale';
      case BreathingPhase.holdOut:
        return 'Hold';
      case BreathingPhase.stopped:
        return 'Ready?';
    }
  }
}

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  BreathingTechnique _selectedTechnique = BreathingTechnique.box;
  BreathingPhase _currentPhase = BreathingPhase.stopped;
  int _phaseSecondsRemaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 20.0, end: 60.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _currentPhase = BreathingPhase.inhale;
      _phaseSecondsRemaining = _selectedTechnique.inhale;
    });
    _runPhase();
  }

  void _stopExercise() {
    _timer?.cancel();
    _controller.stop();
    setState(() {
      _currentPhase = BreathingPhase.stopped;
      _phaseSecondsRemaining = 0;
    });
  }

  void _runPhase() {
    _timer?.cancel();
    
    // Set animation target based on phase
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        _controller.duration = Duration(seconds: _selectedTechnique.inhale);
        _controller.forward();
        _vibrate(HapticFeedback.lightImpact);
        break;
      case BreathingPhase.holdIn:
        _controller.stop();
        _vibrate(HapticFeedback.mediumImpact);
        break;
      case BreathingPhase.exhale:
        _controller.duration = Duration(seconds: _selectedTechnique.exhale);
        _controller.reverse();
        _vibrate(HapticFeedback.lightImpact);
        break;
      case BreathingPhase.holdOut:
        _controller.stop();
        _vibrate(HapticFeedback.mediumImpact);
        break;
      default:
        break;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_phaseSecondsRemaining > 1) {
          _phaseSecondsRemaining--;
        } else {
          _nextPhase();
        }
      });
    });
  }

  void _nextPhase() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        if (_selectedTechnique.holdIn > 0) {
          _currentPhase = BreathingPhase.holdIn;
          _phaseSecondsRemaining = _selectedTechnique.holdIn;
        } else {
          _currentPhase = BreathingPhase.exhale;
          _phaseSecondsRemaining = _selectedTechnique.exhale;
        }
        break;
      case BreathingPhase.holdIn:
        _currentPhase = BreathingPhase.exhale;
        _phaseSecondsRemaining = _selectedTechnique.exhale;
        break;
      case BreathingPhase.exhale:
        if (_selectedTechnique.holdOut > 0) {
          _currentPhase = BreathingPhase.holdOut;
          _phaseSecondsRemaining = _selectedTechnique.holdOut;
        } else {
          _currentPhase = BreathingPhase.inhale;
          _phaseSecondsRemaining = _selectedTechnique.inhale;
        }
        break;
      case BreathingPhase.holdOut:
        _currentPhase = BreathingPhase.inhale;
        _phaseSecondsRemaining = _selectedTechnique.inhale;
        break;
      default:
        break;
    }
    _runPhase();
  }

  void _vibrate(Future<void> Function() feedback) async {
    await feedback();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Glows (Consistent with Home/Rewards)
          _buildBackgroundGlows(),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildBreathingCircle(),
                      const SizedBox(height: 60),
                      _buildTechniqueDescription(),
                      const SizedBox(height: 40),
                      _buildTechniqueSelector(),
                      const SizedBox(height: 40),
                      _buildActionButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryAccent.withValues(alpha: 0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple.withValues(alpha: 0.1),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background.withValues(alpha: 0.6),
      pinned: true,
      elevation: 0,
      centerTitle: true,
      title: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Breathe & Calm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildBreathingCircle() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Glow
            Container(
              width: 180 * _scaleAnimation.value,
              height: 180 * _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 4,
                  ),
                ],
              ),
            ),
            // Glass Circle
            Container(
              width: 220 * _scaleAnimation.value,
              height: 220 * _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(150),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPhase.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4,
                          ),
                        ),
                        if (_currentPhase != BreathingPhase.stopped) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$_phaseSecondsRemaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTechniqueDescription() {
    return Column(
      children: [
        Text(
          _selectedTechnique.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedTechnique.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTechniqueSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: BreathingTechnique.values.map((technique) {
            final isSelected = _selectedTechnique == technique;
            return GestureDetector(
              onTap: _currentPhase != BreathingPhase.stopped 
                  ? null 
                  : () => setState(() => _selectedTechnique = technique),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _currentPhase != BreathingPhase.stopped && !isSelected ? 0.3 : 1.0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primaryAccent.withValues(alpha: 0.15) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.primaryAccent.withValues(alpha: 0.3) 
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    technique.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryAccent : Colors.white24,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isRunning = _currentPhase != BreathingPhase.stopped;
    return GestureDetector(
      onTap: isRunning ? _stopExercise : _startExercise,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRunning
                ? [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]
                : [AppColors.primaryAccent, AppColors.primaryAccent.withBlue(200)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isRunning 
              ? [] 
              : [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            isRunning ? 'END SESSION' : 'START EXERCISE',
            style: TextStyle(
              color: isRunning ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
