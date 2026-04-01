import 'package:flutter/material.dart';
import 'package:unibuzz/app_colors.dart';
import 'package:unibuzz/interfaces/comment_filters_screen.dart';
import 'package:unibuzz/interfaces/login_screen.dart';
import 'package:unibuzz/interfaces/my_posts_screen.dart';
import 'package:unibuzz/interfaces/profile_screen.dart';
import 'package:unibuzz/services/auth_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    this.onBackPressed,
    this.themeMode,
    this.onThemeToggle,
  });

  final VoidCallback? onBackPressed;
  final ThemeMode? themeMode;
  final VoidCallback? onThemeToggle;

  void _handleBack(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    onBackPressed?.call();
  }

  void _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AuthService.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = (themeMode ?? ThemeMode.dark) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.primaryText),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Unibuzz',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Text(
                  'Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: context.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        context,
                        icon: Icons.person,
                        label: 'Profile',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        color: context.dividerColor,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.videocam,
                        label: 'My Posts',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyPostsScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        color: context.dividerColor,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.filter_list,
                        label: 'Comment Filters',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CommentFiltersScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        color: context.dividerColor,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      // Theme toggle
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onThemeToggle,
                          splashColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.03),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: context.accent,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    isDark ? 'Light Mode' : 'Dark Mode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: context.primaryText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                Switch(
                                  value: !isDark,
                                  onChanged: (_) => onThemeToggle?.call(),
                                  activeColor: context.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Material(
                        color: context.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: InkWell(
                          onTap: () => _handleLogout(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Center(
                            child: Text(
                              'Logout',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: context.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: context.accent, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: context.chevronColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
