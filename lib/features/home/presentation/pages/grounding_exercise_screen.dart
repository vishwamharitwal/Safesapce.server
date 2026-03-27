import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';

class GroundingExerciseScreen extends StatefulWidget {
  const GroundingExerciseScreen({super.key});

  @override
  State<GroundingExerciseScreen> createState() => _GroundingExerciseScreenState();
}

class _GroundingExerciseScreenState extends State<GroundingExerciseScreen> {
  int _currentStep = 0;

  final List<GroundingStep> _steps = [
    GroundingStep(
      title: '5 Things You See',
      description: 'Look around and name five things you can see right now.',
      icon: Icons.visibility_outlined,
      color: Colors.blueAccent,
    ),
    GroundingStep(
      title: '4 Things You Feel',
      description: 'Acknowledge four things you can touch, like your clothes or the surface under you.',
      icon: Icons.touch_app_outlined,
      color: Colors.orangeAccent,
    ),
    GroundingStep(
      title: '3 Things You Hear',
      description: 'Listen closely and identify three distinct sounds in your environment.',
      icon: Icons.hearing_outlined,
      color: Colors.greenAccent,
    ),
    GroundingStep(
      title: '2 Things You Smell',
      description: 'Notice two things you can smell, or identify two favorite scents.',
      icon: Icons.air_outlined,
      color: Colors.purpleAccent,
    ),
    GroundingStep(
      title: '1 Thing You Taste',
      description: 'Focus on one thing you can taste, or one flavor you particularly enjoy.',
      icon: Icons.restaurant_outlined,
      color: Colors.redAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              step.color.withValues(alpha: 0.03),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: List.generate(_steps.length, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentStep
                                ? step.color
                                : Colors.white10,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.2, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey<int>(_currentStep),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: step.color.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          step.icon,
                          color: step.color,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 64),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        step.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentStep < _steps.length - 1) {
                        setState(() {
                          _currentStep++;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      _currentStep < _steps.length - 1 ? 'I HAVE FOUND THEM' : 'COMPLETE EXERCISE',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroundingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  GroundingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
