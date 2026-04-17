import 'package:flutter/material.dart';
import 'package:unibuzz/main.dart';
import 'package:unibuzz/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _courseController;
  late TextEditingController _universityController;
  late TextEditingController _passwordController;
  String? _selectedYear;
  bool _isLoading = false;

  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Graduate',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _courseController = TextEditingController();
    _universityController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _courseController.dispose();
    _universityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _signupError;
  void _handleSignup() async {
    setState(() {
      _isLoading = true;
      _signupError = null;
    });
    try {
      final int yearInt =
          _selectedYear != null ? _yearOptions.indexOf(_selectedYear!) + 1 : 0;
      await AuthService.register(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        universityName: _universityController.text.trim(),
        course: _courseController.text.trim(),
        yearOfStudy: yearInt,
      );
      await AuthService.cacheProfileSnapshot(<String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'university_name': _universityController.text.trim(),
        'course': _courseController.text.trim(),
        'year_of_study': yearInt,
      });
      // After successful registration, perform login to obtain tokens
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const PrimaryNavShell(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _signupError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                const SizedBox(height: 24),

                // Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Student Mental Health Hub',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF00B4D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Username Input
                _buildInputField(
                  label: 'USERNAME',
                  controller: _usernameController,
                  hintText: 'jokello',
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Full Name Input
                _buildInputField(
                  label: 'FULL NAME',
                  controller: _fullNameController,
                  hintText: 'John Okello',
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Email Input
                _buildInputField(
                  label: 'EMAIL',
                  controller: _emailController,
                  hintText: 'your@email.com',
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 20),

                // Course of Study Input
                _buildInputField(
                  label: 'COURSE OF STUDY',
                  controller: _courseController,
                  hintText: 'Computer Science',
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // University Name Input
                _buildInputField(
                  label: 'UNIVERSITY',
                  controller: _universityController,
                  hintText: 'Mbarara University',
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 20),

                // Year and Password Row
                Row(
                  children: [
                    // Year of Study Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YEAR',
                            style: TextStyle(
                              color: const Color(0xFF00B4D8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _selectedYear != null
                                    ? const Color(0xFF00B4D8)
                                    : Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              onSelected: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedYear = value);
                                    },
                              itemBuilder: (context) => _yearOptions
                                  .map(
                                    (year) => PopupMenuItem<String>(
                                      value: year,
                                      child: Text(
                                        year,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              color: const Color(0xFF1A1A1A),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedYear ?? 'Select Year',
                                      style: TextStyle(
                                        color: _selectedYear != null
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(
                                      Icons.expand_more,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Password Input
                    Expanded(
                      child: _buildInputField(
                        label: 'PASSWORD',
                        controller: _passwordController,
                        hintText: 'Password',
                        enabled: !_isLoading,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Join Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Material(
                    color: const Color(0xFF00B4D8),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _isLoading ? null : _handleSignup,
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Join Unibuzz',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                if (_signupError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _signupError!,
                      style: const TextStyle(
                        color: Color(0xFFFF4D4D),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF00B4D8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: controller.text.isNotEmpty && enabled
                  ? const Color(0xFF00B4D8)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: (value) => setState(() {}),
            obscureText: obscureText,
            style: TextStyle(
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: InputBorder.none,
            ),
            keyboardType: keyboardType,
          ),
        ),
      ],
    );
  }
}
