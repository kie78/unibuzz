import 'package:flutter/material.dart';

class FullScreenViewScreen extends StatelessWidget {
  const FullScreenViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: Text('Full Screen View Interface'))),
    );
  }
}
