import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/profile/presentation/pages/chat_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String nickname;
  final String avatar;

  const ProfileScreen({
    super.key,
    required this.nickname,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Avatar & Name
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2C2442), // Dark purple background from mock
              ),
              child: Center(
                child: Text(avatar, style: const TextStyle(fontSize: 60)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              nickname,
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 32),
            ),

            const SizedBox(height: 32),

            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Trust Rating',
                      value: '4.8',
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber,
                      subtitle: 'Excellent',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Connections',
                      value: '14',
                      icon: Icons.people_alt_rounded,
                      iconColor: AppColors.primaryAccent,
                      subtitle: 'Total Talks',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Connections & Requests Section
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: AppColors.primaryAccent,
                        labelColor: AppColors.primaryAccent,
                        unselectedLabelColor: AppColors.textSecondary,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Connections'),
                          Tab(text: 'Requests (2)'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Connections Tab
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _ConnectionItem(
                                  avatar: '🐼',
                                  name: 'RestingPanda',
                                  isRequest: false,
                                ),
                                _ConnectionItem(
                                  avatar: '🦊',
                                  name: 'SilentFox',
                                  isRequest: false,
                                ),
                              ],
                            ),
                            // Requests Tab
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _ConnectionItem(
                                  avatar: '🐱',
                                  name: 'NightCat',
                                  isRequest: true,
                                ),
                                _ConnectionItem(
                                  avatar: '☁️',
                                  name: 'DriftingCloud',
                                  isRequest: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: iconColor.withOpacity(0.8), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ConnectionItem extends StatelessWidget {
  final String avatar;
  final String name;
  final bool isRequest;

  const _ConnectionItem({
    required this.avatar,
    required this.name,
    required this.isRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: Center(
              child: Text(avatar, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isRequest) ...[
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(avatar: avatar, name: name),
                  ),
                );
              },
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primaryAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
