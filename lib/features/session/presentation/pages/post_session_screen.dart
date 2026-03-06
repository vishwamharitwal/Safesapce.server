import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class PostSessionScreen extends StatefulWidget {
  final bool isEarlyExit;
  final bool isUserReported;

  const PostSessionScreen({
    super.key,
    this.isEarlyExit = false,
    this.isUserReported = false,
  });

  @override
  State<PostSessionScreen> createState() => _PostSessionScreenState();
}

class _PostSessionScreenState extends State<PostSessionScreen> {
  // null = no selection, true = thumbs up, false = thumbs down
  bool? _isThumbsUp;

  // null = no selection, 0 = happy, 1 = neutral, 2 = sad
  int? _feelingIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    widget.isUserReported
                        ? 'User Reported'
                        : widget.isEarlyExit
                        ? 'Session ended early'
                        : 'Thank you for sharing!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isUserReported
                        ? 'Thank you for keeping our community safe.'
                        : widget.isEarlyExit
                        ? 'Your partner disconnected from the session.'
                        : 'We hope this helped',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  // How was your session Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardBackground,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'How was your session?',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FeedbackButton(
                              icon: Icons.thumb_up_alt_outlined,
                              isSelected: _isThumbsUp == true,
                              activeColor: Colors.greenAccent,
                              onTap: () {
                                setState(() {
                                  _isThumbsUp = true;
                                });
                              },
                            ),
                            const SizedBox(width: 24),
                            _FeedbackButton(
                              icon: Icons.thumb_down_alt_outlined,
                              isSelected: _isThumbsUp == false,
                              activeColor: Colors.redAccent,
                              onTap: () {
                                setState(() {
                                  _isThumbsUp = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Do you feel better Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardBackground,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Do you feel better?',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FeedbackButton(
                              icon: Icons.sentiment_satisfied_alt,
                              isSelected: _feelingIndex == 0,
                              activeColor: Colors.blueAccent,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 0;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            _FeedbackButton(
                              icon: Icons.sentiment_neutral,
                              isSelected: _feelingIndex == 1,
                              activeColor: Colors.amber,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 1;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            _FeedbackButton(
                              icon: Icons.sentiment_dissatisfied,
                              isSelected: _feelingIndex == 2,
                              activeColor: Colors.pinkAccent,
                              onTap: () {
                                setState(() {
                                  _feelingIndex = 2;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Hide Extend Session if it was an early exit or reported
                  if (!widget.isEarlyExit && !widget.isUserReported) ...[
                    // Extend Session Button
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Extend session',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Done Button
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.cardBackground.withOpacity(
                        0.5,
                      ),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (!widget.isUserReported)
                    // Report TextButton
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.background,
                            title: const Text('Report User'),
                            content: const Text(
                              'Are you sure you want to report this user? This will flag them for review.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondaryAccent,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User has been reported.'),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Report',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.flag_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      label: const Text(
                        'Report User',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.2)
              : AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isSelected ? activeColor : AppColors.textSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
