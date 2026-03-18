import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:safespace/features/session/data/signaling_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safespace/features/auth/presentation/pages/login_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';

class ProfileScreen extends StatefulWidget {
  final String nickname;
  final String avatar;

  const ProfileScreen({
    super.key,
    required this.nickname,
    required this.avatar,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  double _rating = 5.0;
  int _totalTalks = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _topTags = [];

  bool _isEditingNickname = false;
  late String _currentNickname;
  late String _currentAvatar;
  final TextEditingController _nicknameController = TextEditingController();
  final FocusNode _nicknameFocusNode = FocusNode();

  final List<String> _avatars = [
    '👤',
    '🦊',
    '🐱',
    '🐼',
    '🐨',
    '🦁',
    '🐯',
    '🐰',
    '🐻',
    '🦋',
    '🦉',
    '🐢',
  ];
  bool _isUpdatingAvatar = false;
  late Stream<Map<String, dynamic>> _profileStream;

  @override
  void initState() {
    super.initState();
    _currentNickname = widget.nickname;
    _currentAvatar = widget.avatar;
    _nicknameController.text = widget.nickname;
    _initProfileStream();
    _fetchTags();
  }

  void _initProfileStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nickname != oldWidget.nickname ||
        widget.avatar != oldWidget.avatar) {
      setState(() {
        _currentNickname = widget.nickname;
        _currentAvatar = widget.avatar;
        _nicknameController.text = widget.nickname;
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchTags() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_ratings')
          .select('tag_selected')
          .eq('target_id', userId);

      final tagCounts = <String, int>{};
      for (var row in response) {
        final tag = row['tag_selected'] as String?;
        if (tag != null && tag.isNotEmpty) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _topTags = sortedTags
              .map((e) => {'tag': e.key, 'count': e.value})
              .take(10)
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    if (newNickname.trim().length < 2) {
      _showError('Nickname must be at least 2 characters.');
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'nickname': newNickname.trim(), 'avatar': _currentAvatar},
        ),
      );
      await _supabase
          .from('profiles')
          .update({'nickname': newNickname.trim()})
          .eq('id', userId);

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        setState(() {
          _currentNickname = newNickname.trim();
          _isEditingNickname = false;
        });
        _nicknameFocusNode.unfocus();
        scaffoldMessenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Nickname updated! ✓')));
      }
    } catch (e) {
      _showError('Failed to update nickname.');
    }
  }

  Future<void> _updateAvatar(String newAvatar) async {
    if (_isUpdatingAvatar) return;
    setState(() => _isUpdatingAvatar = true);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'nickname': _currentNickname, 'avatar': newAvatar},
        ),
      );
      await _supabase
          .from('profiles')
          .update({'avatar': newAvatar})
          .eq('id', userId);

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        setState(() {
          _currentAvatar = newAvatar;
          _isUpdatingAvatar = false;
        });
        scaffoldMessenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Avatar updated! ✓')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
        _showError('Failed to update avatar.');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
  }

  void _showAvatarSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose an Avatar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _avatars.map((avatar) {
                  final isSelected = _currentAvatar == avatar;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (!isSelected) _updateAvatar(avatar);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryAccent.withValues(alpha: 0.2)
                            : AppColors.cardBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryAccent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final data = snapshot.data!;
            _rating = (data['rating'] as num?)?.toDouble() ?? _rating;
            _totalTalks = data['total_talks'] as int? ?? _totalTalks;
            _currentAvatar = data['avatar'] ?? _currentAvatar;
            _currentNickname = data['nickname'] ?? _currentNickname;
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainStatsCard(),
                      const SizedBox(height: 32),
                      _buildNicknameSection(),
                      const SizedBox(height: 32),
                      _buildTagsSection(),
                      const SizedBox(height: 32),
                      _buildShareAndRateButtons(),
                      const SizedBox(height: 48),
                      _buildLogoutButton(),
                      const SizedBox(height: 16),
                      _buildDeleteAccountButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryAccent.withValues(alpha: 0.15),
                AppColors.background,
              ],
            ),
          ),
          child: Center(child: _buildAvatarHeader()),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white54),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAvatarHeader() {
    return GestureDetector(
      onTap: _showAvatarSelectionBottomSheet,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(_currentAvatar, style: const TextStyle(fontSize: 56)),
            ),
          ),
          if (_isUpdatingAvatar)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'User Rating',
              '${_rating.toStringAsFixed(1)} / 5.0',
              Icons.star_rounded,
              Colors.amber,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _buildStatItem(
              'Total Talks',
              _totalTalks.toString(),
              Icons.forum_rounded,
              AppColors.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Display Name',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (_isEditingNickname)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  focusNode: _nicknameFocusNode,
                  maxLength: 20,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _updateNickname(_nicknameController.text),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isEditingNickname = false),
                icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
              ),
            ],
          )
        else
          InkWell(
            onTap: () => setState(() => _isEditingNickname = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _currentNickname,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.edit_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Badges',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryAccent,
              strokeWidth: 2,
            ),
          )
        else if (_topTags.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02) ,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.military_tech_rounded,
                  color: Colors.white.withValues(alpha: 0.1),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No badges yet',
                  style: TextStyle(color: Colors.white24),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _topTags.map((tagData) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.1),
                      AppColors.primaryAccent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${tagData['tag']} x${tagData['count']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildShareAndRateButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              const String shareText =
                  "I'm using DilSe (SafeSpace) to talk to people anonymously and safely. Join me!\n\nDownload now: https://play.google.com/store/apps/details?id=com.safespace.app";
              await SharePlus.instance.share(ShareParams(text: shareText));
            },
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text('Share App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBackground,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final InAppReview inAppReview = InAppReview.instance;
              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              } else {
                inAppReview.openStoreListing(
                  appStoreId: '...', // Update with real ID later if iOS
                );
              }
            },
            icon: const Icon(Icons.star_rate_rounded, size: 20),
            label: const Text('Rate Us'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              foregroundColor: AppColors.primaryAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.redAccent.withValues(alpha: 0.1), Colors.transparent],
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(
          Icons.power_settings_new_rounded,
          color: Colors.redAccent,
        ),
        label: const Text(
          'Switch Account / Log Out',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.redAccent, width: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: TextButton.icon(
        onPressed: _showDeleteAccountDialog,
        icon: const Icon(
          Icons.delete_forever_rounded,
          color: Colors.white54,
          size: 20,
        ),
        label: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your data, chats, and thoughts will be erased.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        // Disconnect signaling first
        final SignalingService signaling = SignalingService();
        signaling.disconnect();

        // Call the RPC function to delete the user
        await _supabase.rpc('delete_user');

        // Then sign out locally
        await _supabase.auth.signOut();

        if (mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          scaffoldMessenger
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(content: Text('Account deleted successfully.')),
            );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('Failed to delete account: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      
      // 1. Terminate signaling connection
      final SignalingService signaling = SignalingService();
      signaling.disconnect();

      // 2. Sign out from Supabase
      await _supabase.auth.signOut();

      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
