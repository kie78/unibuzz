import 'package:flutter/material.dart';
import 'package:unibuzz/interfaces/login_screen.dart';
import 'package:unibuzz/interfaces/my_posts_screen.dart';
import 'package:unibuzz/interfaces/profile_screen.dart';
import 'package:unibuzz/interfaces/report_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.onBackPressed});

  final VoidCallback? onBackPressed;

  void _handleBack(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    onBackPressed?.call();
  }

  void _handleLogout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'Unibuzz',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF00B4D8),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Page Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Text(
                  'Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Settings List Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Profile Item
                      _buildSettingsItem(
                        context,
                        icon: Icons.person,
                        label: 'Profile',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        color: Color(0xFF2A2A2A),
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      // My Posts Item
                      _buildSettingsItem(
                        context,
                        icon: Icons.videocam,
                        label: 'My Posts',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  const MyPostsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        color: Color(0xFF2A2A2A),
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      // Report Item
                      _buildSettingsItem(
                        context,
                        icon: Icons.flag,
                        label: 'Report',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  const ReportScreen(),
                            ),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Logout Button
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
                        color: const Color(0xFF1A1A1A),
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
                                    color: const Color(0xFF00B4D8),
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
    bool isLast = false,
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
              Icon(icon, color: const Color(0xFF00B4D8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
