import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _message = 'Get ready...';
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _message = 'Breathe Out...';
        });
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _message = 'Breathe In...';
        });
        _controller.forward();
      }
    });

    // Start exercise after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _message = 'Breathe In...';
        });
        _controller.forward();
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        _controller.stop();
        setState(() {
          _message = 'You did great!';
        });
      } else {
        if (mounted) {
          setState(() {
            _secondsLeft--;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.primaryAccent.withValues(alpha: 0.05),
              AppColors.background,
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 220 + (80 * _controller.value),
                  height: 220 + (80 * _controller.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.1 * _controller.value),
                        blurRadius: 50,
                        spreadRadius: 30 * _controller.value,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryAccent.withValues(alpha: 0.15),
                        AppColors.primaryAccent.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.2 + (0.3 * _controller.value)),
                      width: 2 + (2 * _controller.value),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.spa_outlined,
                          color: AppColors.primaryAccent.withValues(alpha: 0.5 + (0.5 * _controller.value)),
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _message,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.8 + (0.2 * _controller.value)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 64),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_secondsLeft seconds left',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            if (_secondsLeft == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 10,
                    shadowColor: AppColors.primaryAccent.withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'I FEEL BETTER',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              )
            else
              const Text(
                'Breathe in as the circle expands,\nand breathe out as it contracts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  height: 1.6,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
