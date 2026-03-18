import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:safespace/features/session/presentation/pages/matchmaking_screen.dart';
import 'package:safespace/core/services/presence_service.dart';

class TopicSelectionScreen extends StatefulWidget {
  final String role; // 'talk' or 'listen'
  final String nickname;
  final String avatar;

  const TopicSelectionScreen({
    super.key,
    required this.role,
    required this.nickname,
    required this.avatar,
  });

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen> {
  int? _selectedIndex;
  PresenceService? _presenceService;

  final List<Map<String, dynamic>> _topics = [
    {
      'title': 'Overthinking',
      'icon': Icons.psychology_rounded,
      'color': const Color(0xFF382F44),
    },
    {
      'title': 'Relationships',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFF3C2A35),
    },
    {
      'title': 'Study/Career',
      'icon': Icons.school_rounded,
      'color': const Color(0xFF3B332F),
    },
    {
      'title': 'Loneliness/Anxiety',
      'icon': Icons.cloud_rounded,
      'color': const Color(0xFF2C3E50),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Using a generic guest id since nickname isn't passed to this screen
    final uniqueId = 'topic_selector_${DateTime.now().millisecondsSinceEpoch}';
    _presenceService = PresenceService(userId: uniqueId);
    _presenceService!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceService?.dispose();
    super.dispose();
  }

  void _handleFindSomeone() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          role: widget.role,
          topic: _topics[_selectedIndex!]['title'],
          nickname: widget.nickname,
          avatar: widget.avatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  label: const Text(
                    'Back',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "What's on your mind?",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a topic to discuss',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  physics:
                      const NeverScrollableScrollPhysics(), // Disables scrolling
                  itemCount: _topics.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        1.4, // Adjusted for slightly flatter cards to fit better
                  ),
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    final isSelected = _selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(
                          0,
                          isSelected ? -4 : 0,
                          0,
                        ),
                        decoration: BoxDecoration(
                          color: topic['color'],
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primaryAccent,
                                  width: 2,
                                )
                              : Border.all(color: Colors.transparent, width: 2),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  topic['icon'],
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  topic['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Active Online Users Count
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF42D7C3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _presenceService?.onlineUsersCount == null
                        ? 'Connecting to safe space...'
                        : '${_presenceService!.onlineUsersCount} people are online right now',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _selectedIndex != null ? _handleFindSomeone : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.primaryAccent.withValues(
                    alpha: 0.2,
                  ),
                  disabledForegroundColor: AppColors.background.withValues(
                    alpha: 0.2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Find someone',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
