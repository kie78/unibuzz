import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unibuzz/interfaces/account_screen.dart';
import 'package:unibuzz/interfaces/create_screen.dart';
import 'package:unibuzz/interfaces/discover_screen.dart';
import 'package:unibuzz/interfaces/feed_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0B0B0B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unibuzz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        useMaterial3: true,
      ),
      home: const PrimaryNavShell(),
    );
  }
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

  Widget _buildTabScreen(int index) {
    switch (index) {
      case 0:
        return const FeedScreen();
      case 1:
        return const DiscoverScreen();
      case 2:
        return const CreateScreen();
      case 3:
        return AccountScreen(onBackPressed: _handleAccountBack);
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleAccountBack() {
    final int targetIndex = _previousIndex == 3 ? 0 : _previousIndex;
    _onItemTapped(targetIndex);
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) {
      return;
    }

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
          if (!_loadedTabs.contains(index)) {
            return const SizedBox.shrink();
          }
          return _buildTabScreen(index);
        }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0B0B0B),
        selectedItemColor: const Color(0xFF00B4D8),
        unselectedItemColor: const Color(0xFF999999),
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
