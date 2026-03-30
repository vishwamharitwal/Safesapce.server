import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'dart:ui';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withValues(alpha:0.15),
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
                color: Colors.deepPurple.withValues(alpha:0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 250,
                floating: false,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.background.withValues(alpha:0.8),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: _buildHeader(context),
                  centerTitle: true,
                  title: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Care Rewards',
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
                ),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.05),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDailyStreak(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Active Milestones', context),
                      const SizedBox(height: 16),
                      _buildMilestoneCard(
                        'Listener Champion',
                        'Listen for 100 minutes total',
                        0.65,
                        '65/100 min',
                        Icons.audiotrack_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildMilestoneCard(
                        'Consistent Supporter',
                        'Daily check-in for 7 days',
                        0.42,
                        '3/7 days',
                        Icons.calendar_month_rounded,
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Available Rewards', context),
                      const SizedBox(height: 16),
                      _buildRewardCard(
                        'Golden Heart Badge',
                        'Unlocks at Level 5',
                        'LEVEL 5',
                        Icons.favorite_rounded,
                        true,
                      ),
                      const SizedBox(height: 12),
                      _buildRewardCard(
                        'Expert Listener Tag',
                        'Complete 10 sessions',
                        'CLAIMED',
                        Icons.verified_rounded,
                        false,
                        isClaimed: true,
                      ),
                      const SizedBox(height: 12),
                      _buildRewardCard(
                        'Aura Aurora Theme',
                        'Reach 500 XP',
                        'LOCKED',
                        Icons.palette_rounded,
                        true,
                      ),
                      const SizedBox(height: 60),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryAccent.withValues(alpha:0.1),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 1),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.rewardGold, AppColors.primaryAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rewardGold.withValues(alpha:0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 45,
                backgroundColor: AppColors.background,
                child: Icon(Icons.stars_rounded, color: AppColors.rewardGold, size: 50),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Lvl. 3 Apprentice',
            style: TextStyle(
              color: AppColors.rewardGold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 220,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.rewardGold, Colors.orangeAccent],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.rewardGold.withValues(alpha:0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '350 / 500 XP to Level 4',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyStreak() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha:0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Streak',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3 days of growth',
                    style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.rewardGold.withValues(alpha:0.2),
                      AppColors.rewardGold.withValues(alpha:0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.rewardGold.withValues(alpha:0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: AppColors.rewardGold, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '3',
                      style: TextStyle(color: AppColors.rewardGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              bool completed = index < 3;
              bool isToday = index == 2;
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed 
                        ? AppColors.rewardGold.withValues(alpha:0.1) 
                        : Colors.white.withValues(alpha:0.03),
                      border: isToday 
                        ? Border.all(color: AppColors.rewardGold, width: 2) 
                        : Border.all(color: Colors.white.withValues(alpha:0.05)),
                      boxShadow: isToday ? [
                        BoxShadow(
                          color: AppColors.rewardGold.withValues(alpha:0.2),
                          blurRadius: 10,
                        )
                      ] : null,
                    ),
                    child: Center(
                      child: Icon(
                        completed ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                        color: completed ? AppColors.rewardGold : Colors.white10,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                    style: TextStyle(
                      color: completed ? Colors.white : Colors.white24,
                      fontSize: 11,
                      fontWeight: completed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(String title, String subtitle, double progress, String progressText, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha:0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primaryAccent, size: 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha:0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            progressText,
            style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(String title, String subtitle, String status, IconData icon, bool locked, {bool isClaimed = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha:0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (locked ? Colors.white : AppColors.rewardGold).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon, 
              color: locked ? Colors.white24 : AppColors.rewardGold, 
              size: 24
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: locked ? Colors.white24 : Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: locked ? Colors.white12 : Colors.white.withValues(alpha:0.4), 
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isClaimed 
                  ? Colors.green.withValues(alpha:0.1) 
                  : (locked ? Colors.white.withValues(alpha:0.05) : AppColors.primaryAccent.withValues(alpha:0.1)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isClaimed 
                    ? Colors.green.withValues(alpha:0.2) 
                    : (locked ? Colors.white.withValues(alpha:0.05) : AppColors.primaryAccent.withValues(alpha:0.2))
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isClaimed 
                    ? Colors.greenAccent 
                    : (locked ? Colors.white12 : AppColors.primaryAccent),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
