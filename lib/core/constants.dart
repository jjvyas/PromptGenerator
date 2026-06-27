import 'package:flutter/material.dart';

class AppColors {
  // Monochrome backdrop colors mapped to matte-white theme
  static const Color bgCream = Color(0xFFFFFFFF); // Stark, ultra-clean matte-white canvas (#ffffff)
  static const Color accentCoral = Color(0xFF000000); // Pitch black (#000000) for primary buttons/elements
  
  // High contrast panel colors mapped to clean white panels
  static const Color panelDark = Color(0xFFFFFFFF); // Clean white card surfaces
  static const Color panelSlate = Color(0xFFF4F4F5); // Hover state / secondary elements (light slate)
  
  // Borders and text colors
  static const Color borderBlack = Color(0xFFE4E4E7); // Thin blueprint border lines
  static const Color textDark = Color(0xFF000000); // Primary typography is pitch black (#000000)
  static const Color textLight = Color(0xFFFFFFFF); // White text inside black capsule buttons
  static const Color textMutedDark = Color(0xFF555555); // Secondary sub-headers (muted slate gray #555555)
  static const Color textMutedLight = Color(0xFF71717A); // Medium grey secondary text
 
  // Deep space dark backgrounds
  static const Color bgDark = Color(0xFF0F111A);
  static const Color bgDarker = Color(0xFF07080D);
  
  // Glowing aurora/nebula gradient colors
  static const Color geminiBlue = Color(0xFF1E3A8A);
  static const Color geminiPurple = Color(0xFF5B21B6);
  static const Color geminiPink = Color(0xFF9D174D);
  static const Color geminiTeal = Color(0xFF0F766E);
  
  // Vibrant accents
  static const Color accentBlue = Color(0xFF4F46E5);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPink = Color(0xFFEC4899);

  // Glassmorphism surfaces
  static const Color glassBg = Color(0x15FFFFFF);
  static const Color glassBgHover = Color(0x22FFFFFF);
  static const Color glassBorder = Color(0x25FFFFFF);
  static const Color glassBorderGlow = Color(0x508B5CF6);
  static const Color glassText = Color(0xFFE2E8F0);
  static const Color glassTextMuted = Color(0xFF94A3B8);

  // General fallback colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}

class AppBreakpoints {
  static const double tablet = 768.0;
  static const double desktop = 1100.0;
}

class PromptCategory {
  final String id;
  final String name;
  final IconData icon;

  const PromptCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class PromptTemplate {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final IconData icon;
  final String role;
  final String context;
  final String task;
  final String constraints;
  final String defaultTone;

  const PromptTemplate({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.icon,
    required this.role,
    required this.context,
    required this.task,
    required this.constraints,
    this.defaultTone = 'Professional',
  });
}

final List<PromptCategory> categories = [
  const PromptCategory(id: 'coding', name: 'Coding & Tech', icon: Icons.code),
  const PromptCategory(id: 'writing', name: 'Creative Writing', icon: Icons.edit_note),
  const PromptCategory(id: 'marketing', name: 'Marketing & Biz', icon: Icons.trending_up),
  const PromptCategory(id: 'learning', name: 'Study & Learning', icon: Icons.school),
  const PromptCategory(id: 'general', name: 'General Helper', icon: Icons.assistant),
];

final List<PromptTemplate> templates = [
  // Coding Category
  const PromptTemplate(
    id: 'code_refactor',
    categoryId: 'coding',
    title: 'Code Optimizer & Refactorer',
    description: 'Refactor code for performance, readability, and clean architecture.',
    icon: Icons.auto_awesome,
    role: 'Senior Software Engineer & Clean Code Expert',
    context: 'The provided code is working but requires optimization and restructuring to follow best practices and design patterns.',
    task: 'Analyze the given code block, point out potential bottlenecks, security vulnerabilities, or anti-patterns, and provide a refactored version.',
    constraints: 'Maintain the exact functional logic. Do not add external dependencies. Explain the refactoring decisions in bullet points.',
    defaultTone: 'Technical & Concise',
  ),
  const PromptTemplate(
    id: 'unit_tests',
    categoryId: 'coding',
    title: 'Unit Test Generator',
    description: 'Generate exhaustive unit tests covering edge cases and mock data.',
    icon: Icons.bug_report,
    role: 'QA Automation Engineer specializing in robust test frameworks',
    context: 'We are developing a new critical module and need high test coverage, checking happy paths, error scenarios, and boundary limits.',
    task: 'Write comprehensive unit tests for the provided function or class using standard testing libraries.',
    constraints: 'Include mock setups where necessary. Identify and cover at least 3 edge cases. Group tests logically using describe/test blocks.',
    defaultTone: 'Technical & Concise',
  ),
  // Writing Category
  const PromptTemplate(
    id: 'copywriter',
    categoryId: 'writing',
    title: 'Persuasive Copywriter',
    description: 'Craft catchy, highly engaging product descriptions or sales copy.',
    icon: Icons.rate_review,
    role: 'Conversion Copywriter with 10 years of experience in direct-response marketing',
    context: 'We are launching a new product and need compelling sales copy that resonates with target consumers\' paint points and drives action.',
    task: 'Write a persuasive landing page copy for the product, including a captivating headline, benefits-oriented body copy, and a clear Call-to-Action (CTA).',
    constraints: 'Use the AIDA (Attention, Interest, Desire, Action) framework. Keep it punchy and avoid jargon. Target length is 300 words.',
    defaultTone: 'Persuasive & Enthusiastic',
  ),
  const PromptTemplate(
    id: 'story_starter',
    categoryId: 'writing',
    title: 'Fiction Story Builder',
    description: 'Flesh out plot outlines, characters, or write short fiction stories.',
    icon: Icons.menu_book,
    role: 'Bestselling Science Fiction & Fantasy Novelist',
    context: 'We have a premise of a dystopian world where memories can be bought and sold like commodities, but a black market vendor discovers a memory that belongs to the president.',
    task: 'Write the opening scene of a short story based on this premise, introducing the protagonist and setting a tense atmosphere.',
    constraints: 'Show, don\'t tell. Focus on sensory details (sight, sound, smell). End the scene on a cliffhanger.',
    defaultTone: 'Atmospheric & Captivating',
  ),
  // Marketing Category
  const PromptTemplate(
    id: 'social_media',
    categoryId: 'marketing',
    title: 'Social Media Strategist',
    description: 'Generate a weekly content calendar with hook points and hashtags.',
    icon: Icons.calendar_month,
    role: 'Social Media Manager & Virality Expert',
    context: 'Our brand focuses on sustainable tech gadgets for Gen-Z and Millennial professionals. We want to increase our organic reach on LinkedIn and Instagram.',
    task: 'Generate a 5-day content plan including hooks, caption copy, visual ideas, and relevant hashtags for each day.',
    constraints: 'Optimize LinkedIn posts for intellectual engagement and Instagram posts for visual storytelling and trends. Include call-to-engagements.',
    defaultTone: 'Friendly & Bold',
  ),
  // Learning Category
  const PromptTemplate(
    id: 'feynman_tutor',
    categoryId: 'learning',
    title: 'Feynman Technique Tutor',
    description: 'Learn complex subjects explained simply with analogies and steps.',
    icon: Icons.lightbulb,
    role: 'Empathetic Socratic Educator who excels at clarifying complex scientific concepts',
    context: 'The user wants to grasp a highly complex topic deeply but lacks a advanced academic background in the subject.',
    task: 'Explain the topic using the Feynman Technique. Break it down so a 12-year-old can understand, using an everyday analogy.',
    constraints: 'Avoid jargon. If a technical term must be used, define it immediately. Conclude with a conceptual question to test my understanding.',
    defaultTone: 'Educational & Encouraging',
  ),
];
