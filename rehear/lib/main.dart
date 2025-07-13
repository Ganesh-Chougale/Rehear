// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import ProviderScope
import 'home/home_page.dart'; // Import your home page

void main() {
  runApp(
    // Wrap your app with ProviderScope to use Riverpod
    const ProviderScope(
      child: ReHearApp(),
    ),
  );
}

class ReHearApp extends StatelessWidget {
  const ReHearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReHear', // Changed title to ReHear
      theme: ThemeData(
        primarySwatch: Colors.blue, // Using a primary color relevant to ReHear
      ),
      home: const HomePage(), // Your starting page
    );
  }
}