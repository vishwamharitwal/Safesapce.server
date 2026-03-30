import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dilse/core/theme/app_colors.dart';

class AppShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.primaryAccent.withValues(alpha: 0.1),
      highlightColor: AppColors.primaryAccent.withValues(alpha: 0.3),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget listLoading({int itemCount = 5}) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: AppShimmer(width: double.infinity, height: 80.0, borderRadius: 16.0),
        );
      },
    );
  }

  static Widget profileLoading() {
    return const Column(
      children: [
        SizedBox(height: 24),
        AppShimmer(width: 120, height: 120, borderRadius: 60),
        SizedBox(height: 16),
        AppShimmer(width: 200, height: 24),
        SizedBox(height: 8),
        AppShimmer(width: 150, height: 16),
      ],
    );
  }

  static Widget chatBubbleLoading(bool isMe) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe) const Padding(padding: EdgeInsets.only(right: 8), child: AppShimmer(width: 32, height: 32, borderRadius: 16)),
        const AppShimmer(width: 200, height: 50, borderRadius: 16),
      ],
    );
  }

  static Widget chatListLoading() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: AppShimmer(width: 200, height: 50, borderRadius: 16),
        );
      },
    );
  }

  static Widget chatHubLoading() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: AppShimmer(
            width: double.infinity,
            height: 90.0,
            borderRadius: 24.0,
          ),
        );
      },
    );
  }

  static Widget listItemLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AppShimmer(width: double.infinity, height: 80.0, borderRadius: 16.0),
    );
  }
}
