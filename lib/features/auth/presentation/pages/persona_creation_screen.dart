import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safespace/features/home/presentation/pages/main_layout_screen.dart';

class PersonaCreationScreen extends StatefulWidget {
  const PersonaCreationScreen({super.key});

  @override
  State<PersonaCreationScreen> createState() => _PersonaCreationScreenState();
}

class _PersonaCreationScreenState extends State<PersonaCreationScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedAvatarIndex = 0;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  final List<String> _avatars = [
    '🐰',
    '🦊',
    '🐼',
    '🐱',
    '🐶',
    '🐯',
    '🐸',
    '🐙',
    '👾',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
              const SizedBox(height: 24),
              Text(
                'Create your Persona',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick an avatar and a nickname for your safe space.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),

              // Avatar Selection
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.avatarBubbleLeft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryAccent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _avatars[_selectedAvatarIndex],
                      style: const TextStyle(fontSize: 60),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Avatar grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: List.generate(_avatars.length, (index) {
                  final isSelected = _selectedAvatarIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatarIndex = index;
                      });
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
                          _avatars[index],
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 48),

              // Nickname Input
              const Text(
                'NICKNAME',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. WanderingCloud',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Legal Disclaimer Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.primaryAccent,
                      onChanged: (val) {
                        setState(() {
                          _agreedToTerms = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I agree that this is a safe space for peer-to-peer sharing,',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'not a medical or professional mental health service.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Continue Button
              ElevatedButton(
                onPressed: _agreedToTerms && !_isLoading
                    ? () async {
                        setState(() {
                          _isLoading = true;
                        });

                        final nickname = _nameController.text.trim().isEmpty
                            ? 'Guest'
                            : _nameController.text.trim();
                        final avatar = _avatars[_selectedAvatarIndex];

                        try {
                          await Supabase.instance.client.auth.updateUser(
                            UserAttributes(
                              data: {'nickname': nickname, 'avatar': avatar},
                            ),
                          );

                          // Also sync to profiles table (permanent fix)
                          final userId =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (userId != null) {
                            await Supabase.instance.client
                                .from('profiles')
                                .upsert({
                                  'id': userId,
                                  'nickname': nickname,
                                  'avatar': avatar,
                                });
                          }

                          if (!context.mounted) return;

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainLayoutScreen(
                                nickname: nickname,
                                avatar: avatar,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('Error saving persona: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: AppColors.background,
                  disabledBackgroundColor: AppColors.primaryAccent.withValues(
                    alpha: 0.2,
                  ),
                  disabledForegroundColor: AppColors.background.withValues(
                    alpha: 0.2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text(
                        'Continue to Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
