import 'package:flutter/material.dart';
import 'profile_selection_screen.dart';

void main() {
  runApp(const MeLembraApp());
}

class MeLembraApp extends StatelessWidget {
  const MeLembraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
      ),
      home: const ProfileSelectionScreen(),
    );
  }
}
