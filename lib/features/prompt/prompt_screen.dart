import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/file_exporter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/retro_background.dart';
import 'prompt_controller.dart';

enum ScreenState {
  welcome,
  modeSelect,
  templateEditor,
  enhancerEditor,
  preview,
  history,
  profile,
  settings,
}

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> with TickerProviderStateMixin {
  late PromptController _controller;

  // Text Editing Controller for Website Description
  final TextEditingController _websiteIdeaController = TextEditingController();

  // Text Editing Controller for AI Enhancer
  final TextEditingController _rawInputController = TextEditingController();

  // Auth controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUpMode = false;

  // Profile controllers
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _profileEmailController = TextEditingController();

  // Settings controllers
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Navigation Stack for mobile back operations
  final List<ScreenState> _navigationHistory = [ScreenState.welcome];
  ScreenState _currentScreen = ScreenState.welcome;

  // Preview panel customization state
  double _textSizeMultiplier = 1.0;
  bool _highContrastPreview = false;
  int _selectedTemplateIndex = 0;
  bool _showRawJson = false;

  @override
  void initState() {
    super.initState();
    _controller = PromptController();
    _controller.initController();
    _controller.addListener(_syncControllerToFields);
  }

  void _syncControllerToFields() {
    if (_controller.currentMode == PromptBuilderMode.template) {
      if (_websiteIdeaController.text != _controller.rawPromptInput) {
        _websiteIdeaController.text = _controller.rawPromptInput;
      }
    }
    if (_controller.isAuthenticated) {
      if (_displayNameController.text != (_controller.currentUserDisplayName ?? '')) {
        _displayNameController.text = _controller.currentUserDisplayName ?? '';
      }
      if (_profileEmailController.text != (_controller.currentUserEmail ?? '')) {
        _profileEmailController.text = _controller.currentUserEmail ?? '';
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncControllerToFields);
    _controller.dispose();
    _websiteIdeaController.dispose();
    _rawInputController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _profileEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Navigation Helpers
  void _navigateTo(ScreenState target) {
    setState(() {
      _navigationHistory.add(_currentScreen);
      _currentScreen = target;
    });
  }

  void _goBack() {
    if (_navigationHistory.isNotEmpty) {
      setState(() {
        _currentScreen = _navigationHistory.removeLast();
      });
    }
  }

  // Copy helper
  void _copyToClipboard(String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentCoral,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderBlack, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Copied to Clipboard!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            RetroBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    // Global Header Navigation (Full Width)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: _buildMockHeader(
                        onBack: _currentScreen != ScreenState.welcome ? _goBack : null,
                      ),
                    ),
                    if (_currentScreen != ScreenState.welcome)
                      Container(height: 1.0, color: const Color(0xFFE4E4E7)),
                    
                    // Screen content area
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= AppBreakpoints.tablet;

                          if (isDesktop) {
                            return _buildDesktopLayout();
                          } else {
                            return _buildMobileLayout();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.isTrialExpired && !_controller.isAuthenticated)
              _buildLoginWallOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    if (_currentScreen == ScreenState.welcome) {
      return _buildWelcomeScreen();
    }
    if (_currentScreen == ScreenState.profile) {
      return _buildProfileScreen();
    }
    if (_currentScreen == ScreenState.settings) {
      return _buildSettingsScreen();
    }

    return Row(
      children: [
        // Left Column (Controls, listing or welcome)
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(32.0),
            child: _buildDesktopLeftContent(),
          ),
        ),

        // Vertical divider line
        Container(
          width: 1.5,
          color: AppColors.borderBlack,
        ),

        // Right Column (Output Preview panel always visible)
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(32.0),
            child: _buildOutputPreviewCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLeftContent() {
    switch (_currentScreen) {
      case ScreenState.welcome:
        return _buildWelcomeScreen();
      case ScreenState.modeSelect:
        return _buildModeSelectionScreen();
      case ScreenState.templateEditor:
        return _buildPromptThisFormView();
      case ScreenState.enhancerEditor:
        return _buildAIEnhancerPanel();
      case ScreenState.history:
        return _buildHistoryScreen();
      case ScreenState.preview:
        return _buildPromptThisFormView();
      case ScreenState.profile:
        return _buildProfileScreen();
      case ScreenState.settings:
        return _buildSettingsScreen();
    }
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout() {
    switch (_currentScreen) {
      case ScreenState.welcome:
        return _buildWelcomeScreen();
      case ScreenState.modeSelect:
        return _buildModeSelectionScreen();
      case ScreenState.templateEditor:
        return _buildPromptThisFormView();
      case ScreenState.enhancerEditor:
        return _buildAIEnhancerPanel();
      case ScreenState.preview:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildOutputPreviewCard(),
        );
      case ScreenState.history:
        return _buildHistoryScreen();
      case ScreenState.profile:
        return _buildProfileScreen();
      case ScreenState.settings:
        return _buildSettingsScreen();
    }
  }

  // --- HEADER WIDGET ---
  Widget _buildMockHeader({required VoidCallback? onBack}) {
    final size = MediaQuery.of(context).size;
    final showMiddleLinks = size.width >= 850.0; // Show on wider viewports to fit the text nicely

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _navigateTo(ScreenState.welcome);
            });
          },
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROMPTME',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppColors.textDark, // Pitch black
                ),
              ),
            ],
          ),
        ),
        if (showMiddleLinks)
          Row(
            children: [
              _buildNavHeaderLink('AI Enhancer', ScreenState.enhancerEditor, PromptBuilderMode.enhancer),
              const SizedBox(width: 32),
              _buildNavHeaderLink('Template Builder', ScreenState.templateEditor, PromptBuilderMode.template),
              const SizedBox(width: 32),
              _buildNavHeaderLink('Saved History', ScreenState.history, null),
              if (_controller.isAuthenticated) ...[
                const SizedBox(width: 32),
                _buildNavHeaderLink('Profile', ScreenState.profile, null),
                const SizedBox(width: 32),
                _buildNavHeaderLink('Settings', ScreenState.settings, null),
              ],
            ],
          ),
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: 16),
            ],
            if (_controller.isAuthenticated) ...[
              GestureDetector(
                onTap: () => _navigateTo(ScreenState.profile),
                child: Text(
                  _controller.currentUserEmail ?? 'Profile',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _navigateTo(ScreenState.settings),
                child: const Icon(
                  Icons.settings,
                  color: AppColors.textDark,
                  size: 18,
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: () {
                  _controller.showLoginModal();
                },
                child: const Text(
                  'Login',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _navigateTo(ScreenState.modeSelect),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Try Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavHeaderLink(String title, ScreenState targetScreen, PromptBuilderMode? mode) {
    final isSelected = _currentScreen == targetScreen;
    return GestureDetector(
      onTap: () {
        if (mode != null) {
          _controller.setMode(mode);
        }
        _navigateTo(targetScreen);
      },
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.textDark : AppColors.textMutedDark,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // --- SCREEN 1: SPLASH/WELCOME ---
  Widget _buildWelcomeScreen() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppBreakpoints.tablet;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height - 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Hero Typography & Call-To-Action (Centered)
              Column(
                children: [
                  Text(
                    'Bold Ideas That\nStart With Vision.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: isMobile ? 36.0 : 64.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: AppColors.textDark, // Pitch black
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Text(
                      'We help modern teams engineer high-fidelity prompts that spark breakthrough AI context, clarity, and performance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isMobile ? 13.5 : 15.5,
                        color: AppColors.textMutedDark, // Muted slate gray
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA Get Started Button
                  GestureDetector(
                    onTap: () => _navigateTo(ScreenState.modeSelect),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                fontFamily: 'Inter',
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '↗',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Spacing for hands centerpiece to breathe (the hands are drawn in the retro background behind the column content)
              SizedBox(height: isMobile ? 150 : 280),

              // Social Proof Section (Trusted by + Brand Logos)
              Column(
                children: [
                  Text(
                    'Trusted by teams of every scale',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: AppColors.textMutedDark.withValues(alpha: 0.65),
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandLogos(bool isMobile) {
    final double spacing = isMobile ? 20.0 : 40.0;
    
    return Wrap(
      spacing: spacing,
      runSpacing: 16.0,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildBrandLogo('MERCURY', isBold: true),
        _buildBrandLogo('ramp', isItalic: true),
        _buildBrandLogo('HEX', isMonospace: true),
        _buildBrandLogo('▲ Vercel', isVercel: true),
        _buildBrandLogo('descript', isDescript: true),
        _buildBrandLogo('Cash App', isCashApp: true),
        _buildBrandLogo('SUPERCELL', isSupercell: true),
        _buildBrandLogo('runway', isRunway: true),
      ],
    );
  }

  Widget _buildBrandLogo(
    String name, {
    bool isBold = false,
    bool isItalic = false,
    bool isMonospace = false,
    bool isVercel = false,
    bool isDescript = false,
    bool isCashApp = false,
    bool isSupercell = false,
    bool isRunway = false,
  }) {
    TextStyle style;
    
    if (isMonospace) {
      style = const TextStyle(
        fontFamily: 'Courier',
        fontWeight: FontWeight.w900,
        fontSize: 15.5,
        letterSpacing: 1.0,
      );
    } else if (isItalic) {
      style = const TextStyle(
        fontFamily: 'Inter',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.bold,
        fontSize: 16.0,
        letterSpacing: -0.5,
      );
    } else if (isVercel) {
      style = const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        fontSize: 14.5,
        letterSpacing: 0.2,
      );
    } else if (isSupercell) {
      style = const TextStyle(
        fontFamily: 'Outfit',
        fontWeight: FontWeight.w800,
        fontSize: 13.0,
        letterSpacing: 2.0,
      );
    } else {
      style = TextStyle(
        fontFamily: 'Outfit',
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        fontSize: 15.0,
        letterSpacing: 0.5,
      );
    }

    return Text(
      name,
      style: style.copyWith(
        color: Colors.black.withValues(alpha: 0.55),
      ),
    );
  }



  // --- SCREEN 2: MODE SELECTION ---
  Widget _buildModeSelectionScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Select The Mode\nOf Your Choice',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _ModeCard(
                    title: 'Template Builder',
                    subtitle: 'Input a natural language description of your website to generate a template spec and a precise CLI-ready dev prompt.',
                    actionText: 'Begin Building',
                    onTap: () {
                      _controller.setMode(PromptBuilderMode.template);
                      _navigateTo(ScreenState.templateEditor);
                    },
                  ),
                  const SizedBox(height: 20),
                  _ModeCard(
                    title: 'AI Enhancer',
                    subtitle: 'Input any raw, short prompt idea. The AI transforms it into an optimized, directive-driven prompt.',
                    actionText: 'Begin Enhancing',
                    onTap: () {
                      _controller.setMode(PromptBuilderMode.enhancer);
                      _navigateTo(ScreenState.enhancerEditor);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // --- SCREEN 3: PROMPT->THIS FORM VIEW ---
  Widget _buildPromptThisFormView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Website Description',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe your website idea below. Our smart parser will automatically infer the design theme, color palette, typography, pages structure, tech stack, and key features to build a comprehensive Master Prompt.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMutedDark,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _buildApiStatusWarning(),
            _buildLabel('Describe how your website should be *'),
            TextField(
              controller: _websiteIdeaController,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g., A minimalist dark mode ecommerce store selling custom mechanical keyboards. It should have a clean grid product catalog, a shopping cart drawer, and a secure checkout page. Use React and TailwindCSS with neon orange highlights.',
              ),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: 'Generate Spec & Master Prompt',
              icon: Icons.done_all,
              width: double.infinity,
              onPressed: () {
                if (_websiteIdeaController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please describe your website idea first!')),
                  );
                  return;
                }
                setState(() {
                  _selectedTemplateIndex = 0;
                  _showRawJson = false;
                });
                _controller.generateSpecAndPrompt(_websiteIdeaController.text);
                
                final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
                if (isMobile) {
                  _navigateTo(ScreenState.preview);
                }
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Clear Description',
              icon: Icons.refresh,
              variant: ButtonVariant.secondary,
              width: double.infinity,
              onPressed: () {
                _controller.resetPromptThisFields();
                _websiteIdeaController.clear();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- SCREEN 5: AI ENHANCER EDITOR ---
  Widget _buildAIEnhancerPanel() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            
            const Text(
              'Enhance Prompt',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panelSlate,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderBlack, width: 1.2),
              ),
              child: const Text(
                'Enter a rough statement. The AI will inject a System Role, Background Context, Constraints, and output schema tailored to your domain.',
                style: TextStyle(color: AppColors.textMutedDark, fontSize: 12, height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            _buildApiStatusWarning(),
            _buildLabel('Your Rough Prompt / Idea'),
            TextField(
              controller: _rawInputController,
              onChanged: (val) => _controller.updateRawPromptInput(val),
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g., "explain python decorators to a 10 year old"\nor "code for binary search tree"',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Output Specifications'),
            _buildTuningSlidersCard(),
            const SizedBox(height: 24),

            CustomButton(
              text: _controller.isEnhancing ? 'Refining Prompt...' : 'Enhance Prompt Now',
              icon: Icons.bolt,
              isLoading: _controller.isEnhancing,
              width: double.infinity,
              onPressed: () async {
                if (_rawInputController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please type a rough prompt first!')),
                  );
                  return;
                }
                await _controller.enhancePrompt(_rawInputController.text);
                if (!mounted) return;
                final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
                if (isMobile) {
                  _navigateTo(ScreenState.preview);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.textDark,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // --- RETRO SLIDERS CARD ---
  Widget _buildTuningSlidersCard() {
    return AppTheme.glassmorphismPanel(
      borderRadius: 16,
      blurX: 10,
      blurY: 10,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRetroSlider(
            title: 'Tone',
            value: _controller.toneIndex,
            options: _controller.tones,
            onChanged: (idx) => _controller.updateTone(idx),
          ),
          const SizedBox(height: 12),
          _buildRetroSlider(
            title: 'Detail',
            value: _controller.detailIndex,
            options: _controller.details,
            onChanged: (idx) => _controller.updateDetail(idx),
          ),
          const SizedBox(height: 12),
          _buildRetroSlider(
            title: 'Length',
            value: _controller.lengthIndex,
            options: _controller.lengths,
            onChanged: (idx) => _controller.updateLength(idx),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroSlider({
    required String title,
    required int value,
    required List<String> options,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            Text(
              options[value],
              style: const TextStyle(fontSize: 12, color: AppColors.accentCoral, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accentCoral,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            trackHeight: 3,
            thumbColor: AppColors.accentCoral,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: (options.length - 1).toDouble(),
            divisions: options.length - 1,
            onChanged: (val) => onChanged(val.round()),
          ),
        ),
      ],
    );
  }

  // --- OUTPUT PREVIEW GLASS PANEL ---
  Widget _buildOutputPreviewCard() {
    final promptText = _controller.generatedPrompt;
    final tokenCount = (promptText.length / 4).round();
    final characterCount = promptText.length;

    // Contrast logic matching mockup toggle
    final Color panelBg = _highContrastPreview ? Colors.white : const Color(0xFF1E1E1E);
    final Color textColor = _highContrastPreview ? Colors.black : Colors.white;
    final Color elementColor = _highContrastPreview ? Colors.black : Colors.white;
    final Color muteColor = _highContrastPreview ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

    final parsedSpec = _controller.parsedTemplateSpec;
    final hasTemplates = _controller.currentMode == PromptBuilderMode.template &&
        parsedSpec != null &&
        parsedSpec['templates'] is List &&
        (parsedSpec['templates'] as List).isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderBlack, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: AppColors.borderBlack,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar Actions
          Row(
            children: [
              // Aa Font Size Cycles: 0.85 -> 1.0 -> 1.25
              IconButton(
                tooltip: 'Text Size',
                icon: Row(
                  children: [
                    Icon(Icons.text_fields, color: elementColor, size: 16),
                    Text(
                      ' ${_textSizeMultiplier == 0.85 ? "S" : _textSizeMultiplier == 1.25 ? "L" : "M"}',
                      style: TextStyle(color: elementColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                onPressed: () {
                  setState(() {
                    if (_textSizeMultiplier == 1.0) {
                      _textSizeMultiplier = 1.25;
                    } else if (_textSizeMultiplier == 1.25) {
                      _textSizeMultiplier = 0.85;
                    } else {
                      _textSizeMultiplier = 1.0;
                    }
                  });
                },
              ),
              // High Contrast Toggle
              IconButton(
                tooltip: 'High Contrast',
                icon: Icon(Icons.contrast, color: elementColor, size: 18),
                onPressed: () {
                  setState(() {
                    _highContrastPreview = !_highContrastPreview;
                  });
                },
              ),
              if (hasTemplates) ...[
                const SizedBox(width: 8),
                // Toggle view tab
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: _highContrastPreview ? const Color(0xFFF4F4F5) : const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderBlack, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showRawJson = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: !_showRawJson
                                ? AppColors.accentCoral
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Interactive',
                            style: TextStyle(
                              color: !_showRawJson ? Colors.white : elementColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showRawJson = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _showRawJson
                                ? AppColors.accentCoral
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Raw JSON',
                            style: TextStyle(
                              color: _showRawJson ? Colors.white : elementColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Save / Star active prompt
              IconButton(
                tooltip: 'Save Prompt',
                icon: const Icon(Icons.bookmark, color: AppColors.accentCoral, size: 20),
                onPressed: () {
                  _controller.saveCurrentPromptToHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prompt saved to History!')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Copy Prompt',
                icon: Icon(Icons.copy, color: elementColor, size: 18),
                onPressed: () => _copyToClipboard(promptText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: AppColors.borderBlack.withValues(alpha: 0.3)),

          if (promptText.isNotEmpty && !promptText.startsWith('Your compiled') && !promptText.startsWith('Your enhanced')) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Row(
                children: [
                  Text(
                    'EXPORT PROMPT:',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: muteColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildExportChip(
                    label: '.TXT',
                    icon: Icons.text_snippet_outlined,
                    color: elementColor,
                    bgColor: _highContrastPreview ? const Color(0xFFF4F4F5) : const Color(0xFF27272A),
                    onTap: () {
                      FileExporter.downloadText(
                        content: promptText,
                        filename: _controller.currentMode == PromptBuilderMode.enhancer ? 'enhanced_prompt.txt' : 'master_prompt.txt',
                        mimeType: 'text/plain',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildExportChip(
                    label: '.MD',
                    icon: Icons.article_outlined,
                    color: elementColor,
                    bgColor: _highContrastPreview ? const Color(0xFFF4F4F5) : const Color(0xFF27272A),
                    onTap: () {
                      FileExporter.downloadText(
                        content: promptText,
                        filename: _controller.currentMode == PromptBuilderMode.enhancer ? 'enhanced_prompt.md' : 'master_prompt.md',
                        mimeType: 'text/markdown',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildExportChip(
                    label: '.PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    color: elementColor,
                    bgColor: _highContrastPreview ? const Color(0xFFF4F4F5) : const Color(0xFF27272A),
                    onTap: () async {
                      await FileExporter.downloadPdf(
                        content: promptText,
                        filename: _controller.currentMode == PromptBuilderMode.enhancer ? 'enhanced_prompt.pdf' : 'master_prompt.pdf',
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.borderBlack.withValues(alpha: 0.3)),
          ],

          const SizedBox(height: 12),
          _buildBrowserFrame(),

          // Title Cover Style
          Row(
            children: [
              Text(
                hasTemplates && !_showRawJson ? 'GENERATED TEMPLATES' : 'COMPILED OUTPUT',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: muteColor,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scrollable Reading Panel
          Expanded(
            child: _controller.isEnhancing
                ? _buildShimmerLoading()
                : (hasTemplates && !_showRawJson)
                    ? _buildInteractiveTemplatesPanel(parsedSpec, textColor, muteColor)
                    : Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _highContrastPreview ? Colors.white : const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderBlack, width: 1.5),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            promptText,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 13 * _textSizeMultiplier,
                              color: textColor,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 14),

          // Mock E.reader Stats & Action footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$characterCount Characters',
                    style: TextStyle(fontSize: 11, color: muteColor, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '~$tokenCount Est. Tokens',
                    style: TextStyle(fontSize: 10, color: muteColor),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.arrow_forward, color: AppColors.accentCoral, size: 20),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _copyToClipboard(promptText),
                    child: Text(
                      'Copy Output',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: elementColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTemplatesPanel(Map<String, dynamic> parsedSpec, Color textColor, Color muteColor) {
    final templates = parsedSpec['templates'] as List<dynamic>;
    if (_selectedTemplateIndex >= templates.length) {
      _selectedTemplateIndex = 0;
    }
    final template = templates[_selectedTemplateIndex] as Map<String, dynamic>;
    final name = template['name'] ?? 'Template Name';
    final generationPrompt = template['generationPrompt'] ?? '';

    final Color cardBg = _highContrastPreview ? const Color(0xFFF4F4F5) : const Color(0xFF27272A);
    final Color borderCol = AppColors.borderBlack;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tabs for templates selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(templates.length, (index) {
                final isSelected = index == _selectedTemplateIndex;
                final tName = templates[index]['name'] ?? 'Idea ${index + 1}';
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      tName.length > 20 ? '${tName.substring(0, 18)}...' : tName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.accentCoral,
                    backgroundColor: cardBg,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTemplateIndex = index;
                        });
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Action Bar for Download Template and Prompt
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Download Template',
                    icon: Icons.html,
                    onPressed: () {
                      _controller.downloadTemplateHtml(template, parsedSpec['projectType'] ?? 'Web Application');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading HTML Template: $name'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Download Prompt',
                    icon: Icons.description,
                    variant: ButtonVariant.secondary,
                    onPressed: () {
                      final filename = name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '_') + '_prompt.txt';
                      FileExporter.downloadText(
                        content: generationPrompt,
                        filename: filename,
                        mimeType: 'text/plain',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloading Prompt: $name'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(String hexCode, String label) {
    Color color;
    try {
      final cleanHex = hexCode.replaceFirst('#', '').trim();
      color = Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      color = Colors.grey;
    }
    return Tooltip(
      message: '$label: $hexCode',
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderBlack, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          label[0],
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutItem(String label, dynamic value, Color textColor) {
    if (value == null || value.toString().isEmpty || value.toString().toLowerCase() == 'none') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCoral),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enhancing prompt with AI directives...',
              style: TextStyle(
                color: _highContrastPreview ? AppColors.textDark : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SCREEN 6: HISTORY & ANALYTICS ---
  Widget _buildHistoryScreen() {
    final list = _controller.history;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            // User Profile Row (Elena.H mockup style)
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentCoral,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderBlack, width: 1.5),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prompt.Worm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Title: Prompt Architect',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Statistics dark block (Your History mockup style)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.accentCoral,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderBlack, width: 1.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Statistics',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Icon(Icons.bookmark_outline, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Built nr:', list.length.toString().padLeft(2, '0')),
                      _buildStatColumn('Starred:', list.where((p) => p.isFavorite).length.toString().padLeft(2, '0')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Completed Prompts History',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: list.isEmpty
                  ? _buildEmptyHistoryView()
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final promptItem = list[index];
                        final tokenCount = (promptItem.text.length / 4).round();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderBlack, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.borderBlack,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      promptItem.mode == 'enhancer' ? Icons.bolt : Icons.bookmark,
                                      color: AppColors.accentCoral,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        promptItem.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        promptItem.isFavorite ? Icons.star : Icons.star_border,
                                        size: 18,
                                        color: promptItem.isFavorite ? Colors.amber : AppColors.textMutedDark,
                                      ),
                                      onPressed: () => _controller.toggleFavorite(promptItem.id),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                      onPressed: () => _controller.deletePrompt(promptItem.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mode: ${promptItem.mode.toUpperCase()}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Characters: ${promptItem.text.length}  |  Tokens: ~$tokenCount',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        _controller.loadSavedPrompt(promptItem);
                                        if (promptItem.mode == 'template') {
                                          _websiteIdeaController.text = _controller.rawPromptInput;
                                          _navigateTo(ScreenState.templateEditor);
                                        } else {
                                          _rawInputController.text = _controller.rawPromptInput;
                                          _navigateTo(ScreenState.enhancerEditor);
                                        }
                                        
                                        final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
                                        if (isMobile) {
                                          _navigateTo(ScreenState.preview);
                                        }
                                      },
                                      child: const Row(
                                        children: [
                                          Text(
                                            'Load',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCoral),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.arrow_forward, size: 12, color: AppColors.accentCoral),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, color: AppColors.textMutedDark, size: 40),
          SizedBox(height: 12),
          Text(
            'No saved prompts yet',
            style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Your generated prompts will appear here.',
            style: TextStyle(color: AppColors.textMutedDark, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserFrame() {
    if (_controller.currentMode != PromptBuilderMode.template || _controller.purpose.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = !_highContrastPreview;
    final Color barColor = isDark ? AppColors.panelSlate : AppColors.bgCream;
    final Color borderCol = AppColors.borderBlack;

    // Calculate height dynamically to prevent vertical overflow on smaller viewports
    final screenHeight = MediaQuery.of(context).size.height;
    double mockupHeight = 220.0;
    if (screenHeight < 650) {
      mockupHeight = 90.0;
    } else if (screenHeight < 750) {
      mockupHeight = 130.0;
    } else if (screenHeight < 850) {
      mockupHeight = 175.0;
    }

    final parsedSpec = _controller.parsedTemplateSpec;
    final hasTemplates = _controller.currentMode == PromptBuilderMode.template &&
        parsedSpec != null &&
        parsedSpec['templates'] is List &&
        (parsedSpec['templates'] as List).isNotEmpty;

    Widget previewWidget;
    if (hasTemplates && !_showRawJson) {
      final templatesList = parsedSpec['templates'] as List<dynamic>;
      int idx = _selectedTemplateIndex;
      if (idx >= templatesList.length) idx = 0;
      final template = templatesList[idx] as Map<String, dynamic>;
      previewWidget = _buildDynamicMockupPreview(template, parsedSpec['projectType'] ?? 'Web Application');
    } else {
      previewWidget = _controller.aiImageUrl.isEmpty
          ? Image.asset(
              _controller.detectedImage,
              fit: BoxFit.cover,
              width: double.infinity,
            )
          : Image.network(
              _controller.aiImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCoral),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating design mockup...',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textMutedLight : AppColors.textMutedDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  _controller.detectedImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VISUAL LAYOUT MOCKUP',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.textMutedLight : AppColors.textMutedDark,
                  letterSpacing: 1.0,
                ),
              ),
              const Text(
                'Dynamic AI Preview',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: mockupHeight,
            decoration: BoxDecoration(
              color: isDark ? AppColors.panelSlate : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: borderCol,
                  offset: const Offset(2.5, 2.5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: barColor,
                      border: Border(bottom: BorderSide(color: borderCol, width: 1.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.panelDark : AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'http://localhost:3000/preview-ideas',
                              style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'Courier',
                                color: isDark ? AppColors.textMutedLight : AppColors.textMutedDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: previewWidget,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDynamicMockupPreview(Map<String, dynamic> template, String projectType) {
    final palette = template['colorPalette'] as Map<String, dynamic>? ?? {};
    final primaryHex = palette['primary'] ?? '#3B82F6';
    final secondaryHex = palette['secondary'] ?? '#1E293B';
    final accentHex = palette['accent'] ?? '#F59E0B';
    final bgHex = palette['background'] ?? '#F8FAFC';

    // Parse colors
    Color parseColor(String hex, Color fallback) {
      try {
        final clean = hex.replaceFirst('#', '').trim();
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    final Color bgColor = parseColor(bgHex, const Color(0xFF0F172A));
    final Color primaryColor = parseColor(primaryHex, const Color(0xFF3B82F6));
    final Color secondaryColor = parseColor(secondaryHex, const Color(0xFF1E293B));
    final Color accentColor = parseColor(accentHex, const Color(0xFFF59E0B));
    
    final isDark = bgColor.computeLuminance() < 0.4;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.white60 : Colors.black54;

    final layout = template['layout'] as Map<String, dynamic>? ?? {};
    final headerText = layout['header'] ?? 'Header';
    final sidebarText = layout['sidebar'] ?? 'None';
    final heroText = layout['heroSection'] ?? 'Hero';
    final contentSections = layout['contentSections'] as List<dynamic>? ?? [];
    final footerText = layout['footer'] ?? 'Footer';

    final hasSidebar = sidebarText.toString().isNotEmpty && sidebarText.toString().toLowerCase() != 'none';

    final mainContent = SizedBox(
      width: 480,
      height: 180,
      child: Container(
        color: bgColor,
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.8),
                border: Border(bottom: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'T',
                          style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        template['name'] ?? 'Template',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Text(
                      headerText.toString().length > 30 
                          ? '${headerText.toString().substring(0, 27)}...' 
                          : headerText.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedTextColor, fontSize: 7),
                    ),
                  ),
                ],
              ),
            ),
            
            // Main Body
            Expanded(
              child: Row(
                children: [
                  // Sidebar
                  if (hasSidebar)
                    Container(
                      width: 60,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        border: Border(right: BorderSide(color: textColor.withValues(alpha: 0.1), width: 1)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 30, height: 5, color: primaryColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 6),
                          Container(width: 40, height: 3, color: textColor.withValues(alpha: 0.2)),
                          const SizedBox(height: 3),
                          Container(width: 35, height: 3, color: textColor.withValues(alpha: 0.2)),
                          const Spacer(),
                          Text(
                            sidebarText.toString().length > 15 
                                ? '${sidebarText.toString().substring(0, 12)}...' 
                                : sidebarText.toString(),
                            style: TextStyle(color: mutedTextColor, fontSize: 5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  
                  // Main Content Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero Section
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor.withValues(alpha: 0.25), accentColor.withValues(alpha: 0.1)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  heroText.toString().length > 50 
                                      ? '${heroText.toString().substring(0, 47)}...' 
                                      : heroText.toString(),
                                  style: TextStyle(color: textColor, fontSize: 7, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: const Text('Button', style: TextStyle(color: Colors.white, fontSize: 4, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Content Sections (Row of Expanded cards instead of GridView)
                          Expanded(
                            child: contentSections.isEmpty
                                ? Center(
                                    child: Text('No content sections', style: TextStyle(color: mutedTextColor, fontSize: 7)),
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: List.generate(
                                      contentSections.length > 3 ? 3 : contentSections.length,
                                      (index) {
                                        final sect = contentSections[index].toString();
                                        return Expanded(
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              left: index > 0 ? 3.0 : 0.0,
                                            ),
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(color: textColor.withValues(alpha: 0.1)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: accentColor.withValues(alpha: 0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text('${index + 1}', style: TextStyle(color: textColor, fontSize: 5, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(height: 2),
                                                Expanded(
                                                  child: Align(
                                                    alignment: Alignment.bottomLeft,
                                                    child: Text(
                                                      sect.length > 25 ? '${sect.substring(0, 22)}...' : sect,
                                                      style: TextStyle(color: textColor, fontSize: 5, fontWeight: FontWeight.bold),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
            
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.1), width: 0.5)),
              ),
              alignment: Alignment.center,
              child: Text(
                footerText.toString().length > 60 
                    ? '${footerText.toString().substring(0, 57)}...' 
                    : footerText.toString(),
                style: TextStyle(color: mutedTextColor, fontSize: 5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return FittedBox(
      fit: BoxFit.contain,
      child: mainContent,
    );
  }

  Widget _buildApiStatusWarning() {
    if (!_controller.apiError) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local Mock Mode Active',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _controller.backendReachable
                        ? (_controller.apiKeyConfigured
                            ? 'Live API request failed. Using offline rule-based templates.'
                            : 'Backend/.env has no GROQ_API_KEY. Add your Groq key, save the file, and restart the backend.')
                        : 'Backend is not running at http://127.0.0.1:8000. Start the Python server, then retry.',
                    style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportChip({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderBlack.withValues(alpha: 0.3), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginWallOverlay() {
    final isTrialBlock = _controller.trialInteractions >= 1;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dimmable background and blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
            
            // Centered Glassmorphic Modal
            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 420,
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.85),
                        blurRadius: 64,
                        offset: const Offset(0, 32),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row with Logo & Optional Close Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PROMPTME',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (!isTrialBlock)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              onPressed: () {
                                _controller.hideLoginModal();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Title
                      Text(
                        _isSignUpMode ? 'Create your account' : 'Welcome back',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Message description
                      Text(
                        isTrialBlock 
                            ? 'You have consumed your single anonymous trial. Please sign in or sign up to resume unlimited generations and sync your prompt history.'
                            : 'Sign in to access persistent history, favorites, and unlock unlimited prompt generations.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Form fields
                      // Email Field
                      const Text(
                        'EMAIL ADDRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      const Text(
                        'PASSWORD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Error message if any
                      if (_controller.authErrorMessage != null) ...[
                        Text(
                          _controller.authErrorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 16),
                      
                      // Submit Button
                      ElevatedButton(
                        onPressed: _controller.authLoading
                            ? null
                            : () async {
                                final email = _emailController.text.trim();
                                final password = _passwordController.text;
                                if (email.isEmpty || password.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill in all fields.')),
                                  );
                                  return;
                                }
                                bool success;
                                if (_isSignUpMode) {
                                  success = await _controller.signUp(email, password);
                                  if (!mounted) return;
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Successfully registered and logged in.')),
                                    );
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _navigateTo(ScreenState.welcome);
                                  }
                                } else {
                                  success = await _controller.signIn(email, password);
                                  if (!mounted) return;
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Successfully logged in.')),
                                    );
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _navigateTo(ScreenState.welcome);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _controller.authLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                _isSignUpMode ? 'Create Account' : 'Sign In',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Switch Mode Toggle
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignUpMode = !_isSignUpMode;
                            });
                          },
                          child: Text(
                            _isSignUpMode
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Sign Up",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    final createdDateStr = _controller.currentUserCreatedAt ?? 'N/A';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(36.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.borderBlack, width: 1.5),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderBlack, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'User Profile',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Manage your user profile details below.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Fields
              const Text(
                'USER ID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _controller.currentUserId ?? 'Anonymous',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ACCOUNT CREATED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                createdDateStr,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'DISPLAY NAME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _displayNameController,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter display name',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'EMAIL ADDRESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _profileEmailController,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter email address',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2.0),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),

              if (_controller.authErrorMessage != null) ...[
                Text(
                  _controller.authErrorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              ElevatedButton(
                onPressed: _controller.authLoading
                    ? null
                    : () async {
                        final name = _displayNameController.text.trim();
                        final email = _profileEmailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email cannot be empty.')),
                          );
                          return;
                        }
                        final success = await _controller.updateProfile(name, email);
                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully.')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  elevation: 0,
                ),
                child: _controller.authLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              // Sign Out Button
              OutlinedButton(
                onPressed: () async {
                  await _controller.signOut();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully signed out.')),
                  );
                  _navigateTo(ScreenState.welcome);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(36.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.borderBlack, width: 1.5),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Settings Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderBlack, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Account Settings',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Manage account credentials and security preferences.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Fields
              const Text(
                'NEW PASSWORD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'CONFIRM PASSWORD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMutedDark,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Confirm new password',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2.0),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_controller.authErrorMessage != null) ...[
                Text(
                  _controller.authErrorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              ElevatedButton(
                onPressed: _controller.authLoading
                    ? null
                    : () async {
                        final newPassword = _newPasswordController.text;
                        final confirmPassword = _confirmPasswordController.text;
                        if (newPassword.isEmpty || confirmPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Fields cannot be empty.')),
                          );
                          return;
                        }
                        if (newPassword != confirmPassword) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match.')),
                          );
                          return;
                        }
                        final success = await _controller.updateUserPassword(newPassword);
                        if (!mounted) return;
                        if (success) {
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated successfully.')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.borderBlack, width: 1.5),
                  ),
                  elevation: 0,
                ),
                child: _controller.authLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Change Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              // Sign Out Button
              OutlinedButton(
                onPressed: () async {
                  await _controller.signOut();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully signed out.')),
                  );
                  _navigateTo(ScreenState.welcome);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WireframePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06) // Very subtle lines
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. Draw 3D Cubes on the left
    _drawWireframeCube(canvas, paint, const Offset(60, 100), 50);
    _drawWireframeCube(canvas, paint, const Offset(260, 160), 30);

    // 2. Draw 3D Sphere at the bottom center
    final sphereCenter = Offset(size.width / 2, size.height - 70);
    _drawWireframeSphere(canvas, paint, sphereCenter, 40);

    // 3. Draw Mesh Grid in the top right / background
    _drawMeshGrid(canvas, paint, Offset(size.width - 200, 80), 150, 90);
  }

  void _drawWireframeCube(Canvas canvas, Paint paint, Offset origin, double size) {
    final double dx = size * 0.4;
    final double dy = -size * 0.4;

    final p1 = origin;
    final p2 = Offset(origin.dx + size, origin.dy);
    final p3 = Offset(origin.dx + size, origin.dy + size);
    final p4 = Offset(origin.dx, origin.dy + size);

    final p5 = Offset(origin.dx + dx, origin.dy + dy);
    final p6 = Offset(origin.dx + size + dx, origin.dy + dy);
    final p7 = Offset(origin.dx + size + dx, origin.dy + size + dy);
    final p8 = Offset(origin.dx + dx, origin.dy + size + dy);

    // Front face
    canvas.drawRect(Rect.fromPoints(p1, p3), paint);
    // Back face
    canvas.drawRect(Rect.fromPoints(p5, p7), paint);
    // Connecting edges
    canvas.drawLine(p1, p5, paint);
    canvas.drawLine(p2, p6, paint);
    canvas.drawLine(p3, p7, paint);
    canvas.drawLine(p4, p8, paint);
  }

  void _drawWireframeSphere(Canvas canvas, Paint paint, Offset center, double radius) {
    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Horizontal rings (ellipses)
    for (double h = -radius + 10; h < radius; h += 10) {
      final double r = radius * radius - h * h;
      if (r <= 0) continue;
      final double w = radius * (r / (radius * radius));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy + h), width: w * 2, height: 4),
        paint,
      );
    }

    // Vertical rings (ellipses)
    for (double v = -radius + 10; v < radius; v += 10) {
      final double r = radius * radius - v * v;
      if (r <= 0) continue;
      final double h = radius * (r / (radius * radius));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx + v, center.dy), width: 4, height: h * 2),
        paint,
      );
    }
  }

  void _drawMeshGrid(Canvas canvas, Paint paint, Offset origin, double width, double height) {
    final path = Path();
    final int cols = 8;
    final int rows = 5;

    // Draw horizontal curved lines
    for (int r = 0; r <= rows; r++) {
      final double y = origin.dy + (r / rows) * height;
      path.moveTo(origin.dx, y);
      path.quadraticBezierTo(
        origin.dx + width / 2,
        y + 15 * (r - rows / 2) / (rows / 2),
        origin.dx + width,
        y,
      );
    }

    // Draw vertical curved lines
    for (int c = 0; c <= cols; c++) {
      final double x = origin.dx + (c / cols) * width;
      path.moveTo(x, origin.dy);
      path.quadraticBezierTo(
        x + 10 * (c - cols / 2) / (cols / 2),
        origin.dy + height / 2,
        x,
        origin.dy + height,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -6.0 : 0.0),
          child: AppTheme.glassmorphismPanel(
            borderRadius: 24,
            blurX: 12,
            blurY: 12,
            isHovered: _isHovered,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: const Text(
                        '✨',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMutedDark,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? Colors.black : AppColors.textMutedDark,
                      ),
                      child: Text(widget.actionText),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()
                        ..translate(_isHovered ? 4.0 : 0.0),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: AppColors.accentCoral,
                        size: 20,
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
}
