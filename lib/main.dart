import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unibuzz/interfaces/account_screen.dart';
import 'package:unibuzz/interfaces/create_screen.dart';
import 'package:unibuzz/interfaces/discover_screen.dart';
import 'package:unibuzz/interfaces/feed_screen.dart';
import 'package:unibuzz/interfaces/login_screen.dart';
import 'package:unibuzz/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget? _home;
  ThemeMode _themeMode = ThemeMode.dark;

  static const String _themePrefKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _checkAuth();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themePrefKey);
    if (!mounted) return;
    setState(() {
      _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    });
    _applySystemUiStyle(saved == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _toggleTheme() async {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = next);
    _applySystemUiStyle(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, next == ThemeMode.light ? 'light' : 'dark');
  }

  void _applySystemUiStyle(ThemeMode mode) {
    final isLight = mode == ThemeMode.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isLight ? Colors.white : const Color(0xFF0B0B0B),
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _checkAuth() async {
    final hasValidToken = await AuthService.hasValidAccessToken();
    if (!mounted) return;
    setState(() {
      _home = hasValidToken ? const PrimaryNavShell() : const LoginScreen();
    });
  }

  static ThemeData _darkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B4D8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0B0B),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0B0B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0B0B0B),
        selectedItemColor: Color(0xFF00B4D8),
        unselectedItemColor: Color(0xFF999999),
      ),
    );
  }

  static ThemeData _lightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B4D8),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF00B4D8),
        unselectedItemColor: Color(0xFF777777),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unibuzz',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _themeMode,
      home: _home != null
          ? _wrapWithThemeToggle(_home!)
          : const SizedBox.shrink(),
    );
  }

  Widget _wrapWithThemeToggle(Widget child) {
    if (child is LoginScreen) return child;
    return _ThemeScope(
      themeMode: _themeMode,
      onToggle: _toggleTheme,
      child: child,
    );
  }
}

/// InheritedWidget that carries the current ThemeMode and toggle callback
/// down to PrimaryNavShell and its descendants without prop-drilling.
class _ThemeScope extends InheritedWidget {
  const _ThemeScope({
    required this.themeMode,
    required this.onToggle,
    required super.child,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggle;

  static _ThemeScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ThemeScope>();
  }

  @override
  bool updateShouldNotify(_ThemeScope old) =>
      themeMode != old.themeMode;
}

class PrimaryNavShell extends StatefulWidget {
  const PrimaryNavShell({super.key});

  @override
  State<PrimaryNavShell> createState() => _PrimaryNavShellState();
}

class _PrimaryNavShellState extends State<PrimaryNavShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final Set<int> _loadedTabs = <int>{0};

  /// Key used to call refreshFeed() on the live FeedScreen instance.
  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();

  /// Called by VideoUploadScreen when an upload completes successfully.
  /// Switches to the Feed tab and triggers a refresh.
  void _handleUploadSuccess() {
    _onItemTapped(0);
    // Post-frame so the IndexedStack has committed to tab 0 before refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedKey.currentState?.refreshFeed();
    });
  }

  Widget _buildTabScreen(int index) {
    switch (index) {
      case 0:
        return FeedScreen(key: _feedKey);
      case 1:
        return const DiscoverScreen();
      case 2:
        return CreateScreen(onUploadSuccess: _handleUploadSuccess);
      case 3:
        final scope = _ThemeScope.of(context);
        return AccountScreen(
          onBackPressed: _handleAccountBack,
          themeMode: scope?.themeMode ?? ThemeMode.dark,
          onThemeToggle: scope?.onToggle,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleAccountBack() {
    final int targetIndex = _previousIndex == 3 ? 0 : _previousIndex;
    _onItemTapped(targetIndex);
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(4, (int index) {
          if (!_loadedTabs.contains(index)) return const SizedBox.shrink();
          return _buildTabScreen(index);
        }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
