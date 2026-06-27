import 'features/prompt/prompt_screen.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prompt Generator',
      theme: AppTheme.retroTheme,
      home: const PromptScreen(),
    );
  }
}
