import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/file_exporter.dart';
import 'prompt_service.dart';

enum PromptBuilderMode { template, enhancer }

class SavedPrompt {
  final String id;
  final String text;
  final String title;
  final DateTime timestamp;
  final String mode;
  bool isFavorite;

  SavedPrompt({
    required this.id,
    required this.text,
    required this.title,
    required this.timestamp,
    required this.mode,
    this.isFavorite = false,
  });
}

class PromptController extends ChangeNotifier {
  PromptBuilderMode _currentMode = PromptBuilderMode.template;
  PromptBuilderMode get currentMode => _currentMode;

  Map<String, dynamic>? get parsedTemplateSpec {
    try {
      if (_enhancedPromptOutput.isEmpty) return null;
      return json.decode(_enhancedPromptOutput) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  final PromptService _service = PromptService();

  bool _apiError = false;
  String _lastErrorMessage = '';
  bool _backendReachable = false;
  bool _apiKeyConfigured = false;
  bool get apiError => _apiError;
  String get lastErrorMessage => _lastErrorMessage;
  bool get backendReachable => _backendReachable;
  bool get apiKeyConfigured => _apiKeyConfigured;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isTrialExpired = false;
  bool get isTrialExpired => _isTrialExpired;

  int _trialInteractions = 0;
  int get trialInteractions => _trialInteractions;

  bool _authLoading = false;
  bool get authLoading => _authLoading;

  String? _authErrorMessage;
  String? get authErrorMessage => _authErrorMessage;

  String? get currentUserEmail => Supabase.instance.client.auth.currentUser?.email;
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;
  String? get currentUserCreatedAt => Supabase.instance.client.auth.currentUser?.createdAt;
  String? get currentUserDisplayName => Supabase.instance.client.auth.currentUser?.userMetadata?['displayName'] as String?;

  StreamSubscription<AuthState>? _authSubscription;

  PromptController() {
    checkBackendHealth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> initController() async {
    final session = Supabase.instance.client.auth.currentSession;
    _isAuthenticated = session != null;

    final prefs = await SharedPreferences.getInstance();
    _trialInteractions = prefs.getInt('trial_interactions') ?? 0;

    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final newAuth = session != null;
      if (newAuth != _isAuthenticated) {
        _isAuthenticated = newAuth;
        if (_isAuthenticated) {
          _isTrialExpired = false;
          await syncLocalHistoryToSupabase();
          await loadHistoryFromSupabase();
        } else {
          _history.clear();
        }
        notifyListeners();
      }
    });

    if (_isAuthenticated) {
      await loadHistoryFromSupabase();
    }
    notifyListeners();
  }

  Future<bool> checkTrialLimitAndTrigger() async {
    if (_isAuthenticated) return true;

    if (_trialInteractions < 1) {
      return true; // One anonymous sandbox cycle allowed
    }

    _isTrialExpired = true;
    notifyListeners();
    return false;
  }

  void showLoginModal() {
    _isTrialExpired = true;
    notifyListeners();
  }

  void hideLoginModal() {
    _isTrialExpired = false;
    notifyListeners();
  }

  Future<void> incrementTrialCount() async {
    if (_isAuthenticated) return;
    _trialInteractions++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trial_interactions', _trialInteractions);
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _authLoading = true;
    _authErrorMessage = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _authLoading = false;
      notifyListeners();
      return response.session != null;
    } catch (e) {
      _authErrorMessage = e.toString();
      _authLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _authLoading = true;
    _authErrorMessage = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      _authLoading = false;
      notifyListeners();
      return response.session != null;
    } catch (e) {
      _authErrorMessage = e.toString();
      _authLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _isAuthenticated = false;
    _isTrialExpired = false;
    _history.clear();
    notifyListeners();
  }

  Future<bool> updateProfile(String displayName, String email) async {
    _authLoading = true;
    _authErrorMessage = null;
    notifyListeners();

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          email: email,
          data: {'displayName': displayName},
        ),
      );
      _authLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authErrorMessage = e.toString();
      _authLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserPassword(String password) async {
    _authLoading = true;
    _authErrorMessage = null;
    notifyListeners();

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      _authLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authErrorMessage = e.toString();
      _authLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> syncLocalHistoryToSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _history.isEmpty) return;

    for (final item in _history) {
      try {
        await Supabase.instance.client.from('prompt_history').upsert({
          'id': item.id,
          'user_id': user.id,
          'text': item.text,
          'title': item.title,
          'mode': item.mode,
          'is_favorite': item.isFavorite,
          'created_at': item.timestamp.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error syncing history item ${item.id}: $e');
      }
    }
  }

  Future<void> loadHistoryFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('prompt_history')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      _history.clear();
      for (final row in data) {
        _history.add(SavedPrompt(
          id: row['id'] ?? '',
          text: row['text'] ?? '',
          title: row['title'] ?? '',
          timestamp: DateTime.parse(row['created_at'] ?? DateTime.now().toIso8601String()),
          mode: row['mode'] ?? 'template',
          isFavorite: row['is_favorite'] ?? false,
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading history from Supabase: $e');
    }
  }

  Future<void> checkBackendHealth() async {
    try {
      final health = await _service.checkHealth();
      _backendReachable = true;
      _apiKeyConfigured = health['api_key_configured'] == true;
      if (!_apiKeyConfigured) {
        _apiError = true;
        _lastErrorMessage = health['message']?.toString() ??
            'GROQ_API_KEY not found in Backend/.env';
      } else {
        _apiError = false;
        _lastErrorMessage = '';
      }
    } catch (e) {
      _backendReachable = false;
      _apiKeyConfigured = false;
      _apiError = true;
      _lastErrorMessage =
          'Cannot reach backend at http://127.0.0.1:8000. Start it with: cd Backend && .\\venv\\Scripts\\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000';
    }
    notifyListeners();
  }

  // Mode Selection
  void setMode(PromptBuilderMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  // --- PROMPT->THIS STATE ---
  String _purpose = '';
  String _audience = '';
  String _pages = '';
  String _design = '';
  String _colors = '';
  String _typography = '';
  String _techStack = '';
  String _features = '';
  String _contentTone = '';
  String _constraintsThis = '';
  String _projectContext = '';
  String _detectedImage = 'assets/images/general_mockup.png';
  String _aiImageUrl = '';

  String get purpose => _purpose;
  String get audience => _audience;
  String get pages => _pages;
  String get design => _design;
  String get colors => _colors;
  String get typography => _typography;
  String get techStack => _techStack;
  String get features => _features;
  String get contentTone => _contentTone;
  String get constraintsThis => _constraintsThis;
  String get projectContext => _projectContext;
  String get detectedImage => _detectedImage;
  String get aiImageUrl => _aiImageUrl;

  void updatePromptThisField({
    String? purpose,
    String? audience,
    String? pages,
    String? design,
    String? colors,
    String? typography,
    String? techStack,
    String? features,
    String? contentTone,
    String? constraintsThis,
    String? projectContext,
  }) {
    if (purpose != null) _purpose = purpose;
    if (audience != null) _audience = audience;
    if (pages != null) _pages = pages;
    if (design != null) _design = design;
    if (colors != null) _colors = colors;
    if (typography != null) _typography = typography;
    if (techStack != null) _techStack = techStack;
    if (features != null) _features = features;
    if (contentTone != null) _contentTone = contentTone;
    if (constraintsThis != null) _constraintsThis = constraintsThis;
    if (projectContext != null) _projectContext = projectContext;
    notifyListeners();
  }

  void resetPromptThisFields() {
    _purpose = '';
    _audience = '';
    _pages = '';
    _design = '';
    _colors = '';
    _typography = '';
    _techStack = '';
    _features = '';
    _contentTone = '';
    _constraintsThis = '';
    _projectContext = '';
    _enhancedPromptOutput = '';
    _detectedImage = 'assets/images/general_mockup.png';
    _aiImageUrl = '';
    notifyListeners();
  }

  // Smart Parser for single website idea bar calling real API with local fallback
  Future<void> generateSpecAndPrompt(String idea) async {
    if (idea.trim().isEmpty) return;

    final allowed = await checkTrialLimitAndTrigger();
    if (!allowed) return;

    _rawPromptInput = idea;
    _enhancedPromptOutput = '';
    _isEnhancing = true;
    _apiError = false;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      final response = await _service.generateTemplateSpec(
        idea: idea,
        token: token,
        isTrial: !_isAuthenticated,
      );
      
      _purpose = response['projectType'] ?? 'Web Application';
      _audience = response['targetAudience'] ?? 'General Audience';
      _design = response['recommendedStyle'] ?? 'Modern UI';
      
      // Clean previous fields
      _pages = '';
      _colors = '';
      _typography = '';
      _techStack = '';
      _features = '';
      _contentTone = '';
      _constraintsThis = '';
      _projectContext = '';

      final JsonEncoder encoder = JsonEncoder.withIndent('  ');
      _enhancedPromptOutput = encoder.convert(response);
      
      final styleLower = _design.toLowerCase();
      final ideaLower = idea.toLowerCase();
      if (styleLower.contains('ecommerce')) {
        _detectedImage = 'assets/images/ecommerce_mockup.png';
      } else if (styleLower.contains('portfolio')) {
        _detectedImage = 'assets/images/portfolio_mockup.png';
      } else if (styleLower.contains('saas') || styleLower.contains('dashboard') || styleLower.contains('fintech') || styleLower.contains('analytics')) {
        _detectedImage = 'assets/images/saas_mockup.png';
      } else if (styleLower.contains('blog') || styleLower.contains('education')) {
        _detectedImage = 'assets/images/blog_mockup.png';
      } else {
        if (ideaLower.contains('space') ||
            ideaLower.contains('cosmic') ||
            ideaLower.contains('cyber') ||
            ideaLower.contains('dark') ||
            ideaLower.contains('neon')) {
          _detectedImage = 'assets/images/saas_mockup.png';
        } else {
          _detectedImage = 'assets/images/general_mockup.png';
        }
      }
      
      _aiImageUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent('website UI UX design mockup layout of: $idea. Clean grid structure, professional color palette, highly aesthetic modern web interface, high-resolution desktop view.')}';
    } catch (e) {
      _apiError = true;
      _lastErrorMessage = e.toString();
      _runLocalRuleBasedParser(idea);
    } finally {
      _isEnhancing = false;
      notifyListeners();
      await incrementTrialCount();
      saveCurrentPromptToHistory();
    }
  }

  void _runLocalRuleBasedParser(String idea) {
    final normalized = idea.toLowerCase();
    
    // Determine category
    bool isSpace = _matchesAny(normalized, ['space', 'galaxy', 'universe', 'cosmic', 'astronomy', 'nasa', 'sci-fi', 'futuristic', 'cyberpunk', 'neon', 'nebula']);
    bool isEcommerce = _matchesAny(normalized, ['shop', 'store', 'ecommerce', 'e-commerce', 'buy', 'sell', 'market', 'product', 'merch', 'keyboard', 'shoes', 'clothing', 'retail', 'checkout', 'cart']);
    bool isPortfolio = _matchesAny(normalized, ['portfolio', 'resume', 'personal', 'photographer', 'photography', 'developer', 'designer', 'cv', 'artist', 'creative', 'work', 'gallery']);
    bool isBlog = _matchesAny(normalized, ['blog', 'news', 'article', 'writing', 'magazine', 'read', 'publication', 'journal', 'feed']);
    
    String projectType = 'Web Application';
    String targetAudience = 'General web users and customers';
    String recommendedStyle = 'Minimal SaaS';
    
    if (isSpace) {
      projectType = 'Space exploration / Sci-Fi Portal';
      targetAudience = 'Sci-Fi enthusiasts, astronomy researchers, and gamers';
      recommendedStyle = 'Dark Professional';
    } else if (isEcommerce) {
      projectType = 'E-commerce Store';
      targetAudience = 'Online shoppers and retail consumers';
      recommendedStyle = 'Ecommerce';
    } else if (isPortfolio) {
      projectType = 'Professional Portfolio';
      targetAudience = 'Recruiters, clients, and technical managers';
      recommendedStyle = 'Portfolio';
    } else if (isBlog) {
      projectType = 'Blog and News Platform';
      targetAudience = 'Avid readers and industry followers';
      recommendedStyle = 'Minimal SaaS';
    }
    
    List<Map<String, dynamic>> templates = [];
    
    // Generate 5 templates
    for (int i = 1; i <= 5; i++) {
      String name = '';
      String style = '';
      String description = '';
      String bestFor = '';
      Map<String, dynamic> layout = {};
      List<String> components = [];
      Map<String, String> colorPalette = {};
      String generationPrompt = '';
      
      if (isSpace) {
        if (i == 1) {
          name = 'Nebula Mission Control';
          style = 'Dark Professional';
          description = 'Immersive dashboard representing command controls and space telemetry.';
          bestFor = 'Space simulation systems and cosmic dashboards';
          layout = {
            'header': 'Glowing telemetry navbar with mission clocks',
            'sidebar': 'HUD settings panel and spacecraft checklist navigation',
            'navigation': 'Futuristic left-hand sidebar navigation list',
            'heroSection': 'Planetary orbit visualizer and telemetry live feeds',
            'contentSections': ['Spacecraft system telemetry panels', 'Constellation tracker grid', 'Comet radar monitor chart'],
            'footer': 'Command center status codes and connection quality meters'
          };
          components = ['Telemetry Grid', 'Constellation Tracker', 'Alert Banners', 'System Checklists'];
          colorPalette = {
            'primary': '#8B5CF6',
            'secondary': '#06B6D4',
            'accent': '#FF2E93',
            'background': '#0A0A12'
          };
          generationPrompt = 'A sci-fi command HUD design with deep space black background, glowing celestial purple and planetary cyan highlights, detailed widgets, and Orbitron font.';
        } else if (i == 2) {
          name = 'Planetary Grid';
          style = 'Minimal SaaS';
          description = 'Minimalist clean interface showcasing cataloged stars and planet profiles.';
          bestFor = 'Astronomers and digital space catalogs';
          layout = {
            'header': 'Clean top search bar with celestial filters',
            'sidebar': 'None',
            'navigation': 'Horizontal top bar',
            'heroSection': 'Clean bold heading "EXPLORE THE GALAXY" and quick search inputs',
            'contentSections': ['Planetary profile grid cards', 'Spectral classification table', 'Constellation map viewer'],
            'footer': 'NASA data credit and contact copyright links'
          };
          components = ['Profile Grid', 'Search Filters', 'Spectral Table', 'Constellation Map'];
          colorPalette = {
            'primary': '#0284C7',
            'secondary': '#64748B',
            'accent': '#F59E0B',
            'background': '#FFFFFF'
          };
          generationPrompt = 'A high-minimalist grid dashboard for space cataloging, pure white backgrounds, clean sky blue accent elements, and Courier code typography.';
        } else if (i == 3) {
          name = 'Galactic HUD Explorer';
          style = 'Glassmorphic';
          description = 'Beautiful glass-hud layout over a simulated space nebula backdrop.';
          bestFor = 'High-fidelity visual presentations and portfolio websites';
          layout = {
            'header': 'Glassmorphic transparent header with blur background',
            'sidebar': 'Interactive visual orbit control selector overlay',
            'navigation': 'Floating pill nav bar',
            'heroSection': 'Large space nebula animation background with floating intro cards',
            'contentSections': ['Translucent planet detail overlays', 'Atmospheric composition charts', 'Star map coords list'],
            'footer': 'Copyright details and social links rendered on glass panels'
          };
          components = ['Glass Panels', 'Orbit Controls', 'Floating Pills', 'Detail Overlays'];
          colorPalette = {
            'primary': '#A855F7',
            'secondary': '#EC4899',
            'accent': '#10B981',
            'background': '#020205'
          };
          generationPrompt = 'Create a premium space visual portal with translucent glass cards over deep purple/magenta space nebula background, Outfit font, and glowing neon green border buttons.';
        } else if (i == 4) {
          name = 'Fintech Space Economy';
          style = 'Fintech';
          description = 'Analytical dashboard representing simulated asteroid mining economy stats.';
          bestFor = 'Data-dense systems and dashboard apps';
          layout = {
            'header': 'Standard financial navigation with account details',
            'sidebar': 'Interactive stock trackers and asset checklists',
            'navigation': 'Top navigation tabs',
            'heroSection': 'Mining output analytics with charts showing cumulative gains',
            'contentSections': ['Asteroid mining value chart', 'Refinery asset status listings', 'Market valuation table'],
            'footer': 'System status updates and database connection flags'
          };
          components = ['Analytics Charts', 'Asset Lists', 'Market Tables', 'Stock Trackers'];
          colorPalette = {
            'primary': '#10B981',
            'secondary': '#3B82F6',
            'accent': '#EAB308',
            'background': '#0F172A'
          };
          generationPrompt = 'A highly aesthetic fintech dashboard styled for space operations, emerald green positive tickers, slate backgrounds, and Inter system fonts.';
        } else {
          name = 'Cosmic Storyteller';
          style = 'Modern Startup';
          description = 'A content platform/blog with large full-bleed cosmic space imagery.';
          bestFor = 'Blogs, articles, magazines, and content creators';
          layout = {
            'header': 'Simple brand logo and category tags switcher',
            'sidebar': 'None',
            'navigation': 'Top horizontal links',
            'heroSection': 'Full-bleed space imagery with large header text overlay',
            'contentSections': ['Featured articles feed', 'Trending cosmic news tiles', 'Newsletter subscription card'],
            'footer': 'Editorial bio block and social share rows'
          };
          components = ['Articles Grid', 'Newsletter Panel', 'Featured Banners', 'Category Selectors'];
          colorPalette = {
            'primary': '#F43F5E',
            'secondary': '#475569',
            'accent': '#06B6D4',
            'background': '#FAF8F6'
          };
          generationPrompt = 'An editorial cosmic magazine layout, warm paper backgrounds, rose accents, large headers, and Playfair Display typography.';
        }
      } else if (isEcommerce) {
        if (i == 1) {
          name = 'Structured Product Catalog';
          style = 'Ecommerce';
          description = 'Clean card-white product grids with detailed specifications.';
          bestFor = 'B2C retail stores and product directories';
          layout = {
            'header': 'Standard storefront header with shopping cart counter',
            'sidebar': 'Category filters drawer',
            'navigation': 'Top category navbar',
            'heroSection': 'Promotional discount banner with bold typography and promo codes',
            'contentSections': ['Structured product grid', 'Customer testimonials row', 'FAQ dropdown collapse list'],
            'footer': 'Help center links and newsletter email inputs'
          };
          components = ['Product Grid', 'Cart Drawer', 'Discount Banner', 'Testimonials Carousel'];
          colorPalette = {
            'primary': '#2563EB',
            'secondary': '#1E293B',
            'accent': '#EF4444',
            'background': '#F8FAFC'
          };
          generationPrompt = 'Modern clean e-commerce layout with blue details, card grids, shadow boxes, and Inter font.';
        } else if (i == 2) {
          name = 'Neo-Boutique Store';
          style = 'Modern Startup';
          description = 'High-impact lifestyle photography blocks with clean overlay buttons.';
          bestFor = 'Bespoke apparel, jewelry, or design items';
          layout = {
            'header': 'Minimal brand mark and absolute navbar links',
            'sidebar': 'None',
            'navigation': 'Floating page navigation menu',
            'heroSection': 'Full screen video loop overlay with center CTA',
            'contentSections': ['Lifestyle product editorial grids', 'Brand mission statements block', 'Store locator locator'],
            'footer': 'Detailed custom policy links and newsletter sign-up'
          };
          components = ['Video Hero', 'Editorial Grids', 'Store Locator', 'Newsletter Box'];
          colorPalette = {
            'primary': '#111111',
            'secondary': '#6B7280',
            'accent': '#D97706',
            'background': '#FAF9F6'
          };
          generationPrompt = 'Luxury modern boutique layout, warm sand background, serif typography, high-resolution lifestyle images.';
        } else if (i == 3) {
          name = 'Minimal Keyboard Store';
          style = 'Minimal SaaS';
          description = 'Ultra-clean layouts designed for custom keyboard listings.';
          bestFor = 'Single product lines or mechanical hardware niches';
          layout = {
            'header': 'Clean brand mark with quick links',
            'sidebar': 'Keyboard builder configurator options panel',
            'navigation': 'Top navigation bar',
            'heroSection': 'High-angle mechanical keyboard mockup shot with custom spec cards',
            'contentSections': ['Switch selection selectors', 'Keycap profile options grid', 'Customer reviews feed'],
            'footer': 'Join mechanical community Discord links and social links'
          };
          components = ['Keyboard Mockups', 'Configurator Panels', 'Reviews Feed', 'Option Grids'];
          colorPalette = {
            'primary': '#F43F5E',
            'secondary': '#1E293B',
            'accent': '#10B981',
            'background': '#FFFFFF'
          };
          generationPrompt = 'A mechanical keyboard shop design with thin clean grid lines, pure white backgrounds, warm coral red details, and Outfit font.';
        } else if (i == 4) {
          name = 'Glassmorphic checkout interface';
          style = 'Glassmorphic';
          description = 'A payment/billing screen using frosted glass overlays.';
          bestFor = 'Modern checkout modules and online payments';
          layout = {
            'header': 'Secure checkout page header with transaction IDs',
            'sidebar': 'None',
            'navigation': 'Back to store breadcrumbs links',
            'heroSection': 'Frosted glass transaction panel displaying billing totals and checkout details',
            'contentSections': ['Payment form inputs', 'Order details billing checkout items list', 'Secure SSL trust badges'],
            'footer': 'Refund policy guidelines and payment terms footer'
          };
          components = ['Billing Totals', 'Payment Inputs', 'Trust Badges', 'Frosted Glass Panel'];
          colorPalette = {
            'primary': '#4F46E5',
            'secondary': '#374151',
            'accent': '#059669',
            'background': '#EEF2F6'
          };
          generationPrompt = 'Glassmorphic billing checkout screen, frosted card panels, modern payment forms, secure badges, soft blue backdrops.';
        } else {
          name = 'B2B Wholesale Catalog';
          style = 'Enterprise Dashboard';
          description = 'Large table listings with bulk order toggles.';
          bestFor = 'Wholesale retailers, supply directories, B2B marketplaces';
          layout = {
            'header': 'Client profile header with tier status indicators',
            'sidebar': 'Wholesale category filters list',
            'navigation': 'Top header dropdowns',
            'heroSection': 'Search inventory form with total inventory item trackers',
            'contentSections': ['Bulk inventory table listing', 'Discount tiers metrics cards', 'Order confirmation modal'],
            'footer': 'Supply support channels contact information and terms guidelines'
          };
          components = ['Inventory Table', 'Metrics Cards', 'Order Modals', 'Filters List'];
          colorPalette = {
            'primary': '#0F172A',
            'secondary': '#475569',
            'accent': '#F59E0B',
            'background': '#F1F5F9'
          };
          generationPrompt = 'Dense wholesale logistics catalog, clean system tables, bulk quantity selectors, gray enterprise dashboards.';
        }
      } else {
        // Fallbacks for SaaS, Portfolio, Blog, and General
        if (i == 1) {
          name = 'Standard SaaS Platform';
          style = 'Minimal SaaS';
          description = 'Sleek interface showcasing service features and plans.';
          bestFor = 'Software startups, applications, and landing pages';
          layout = {
            'header': 'Clean navbar with logo, pricing links, and CTA button',
            'sidebar': 'None',
            'navigation': 'Horizontal top bar',
            'heroSection': 'Centered bold heading, descriptive paragraph, and primary/secondary button row',
            'contentSections': ['Feature grid with icons', 'Customer testimonials slider', 'Simple pricing matrix'],
            'footer': 'Standard 4-column footer with links and social icons'
          };
          components = ['Navbar', 'Hero Section', 'Feature Cards', 'Pricing Table', 'Footer'];
          colorPalette = {
            'primary': '#2563EB',
            'secondary': '#1E293B',
            'accent': '#EAB308',
            'background': '#F8FAFC'
          };
          generationPrompt = 'A clean SaaS layout with blue primary accents, slate backgrounds, and modern grid structures.';
        } else if (i == 2) {
          name = 'Enterprise Dashboard Console';
          style = 'Enterprise Dashboard';
          description = 'Data-dense metrics console for analytics.';
          bestFor = 'Business monitoring dashboards and analytics portals';
          layout = {
            'header': 'Control panel header with system statuses',
            'sidebar': 'Analytical menu tabs list',
            'navigation': 'Left sidebar menu',
            'heroSection': 'Core stats cards row showing performance metrics',
            'contentSections': ['Interactive lines chart', 'Actionable logs tables', 'Recent operations logs list'],
            'footer': 'Server diagnostics details and database uptime charts'
          };
          components = ['Metrics Cards', 'Lines Charts', 'Logs Tables', 'System Status'];
          colorPalette = {
            'primary': '#4F46E5',
            'secondary': '#1F2937',
            'accent': '#10B981',
            'background': '#F3F4F6'
          };
          generationPrompt = 'A business command console with indigo colors, detailed bar charts, slate grey panel boundaries, and Inter typography.';
        } else if (i == 3) {
          name = 'Creative Designer CV';
          style = 'Portfolio';
          description = 'Clean spaces showcasing projects, typography, and personal info.';
          bestFor = 'Designers, creators, developers, and creative consultants';
          layout = {
            'header': 'Simple brand logo, contact buttons',
            'sidebar': 'None',
            'navigation': 'Top navigation bar',
            'heroSection': 'Large geometric text greeting "HI, I AM A CREATIVE" with profile bio description',
            'contentSections': ['Visual project grids card', 'Resume work timeline', 'Validated feedback contact cards'],
            'footer': 'Social handles footer lists'
          };
          components = ['Project Card', 'Bio Display', 'Contact Forms', 'Timeline Grid'];
          colorPalette = {
            'primary': '#E11D48',
            'secondary': '#475569',
            'accent': '#F59E0B',
            'background': '#FCFBF9'
          };
          generationPrompt = 'Clean Swiss-style designer CV, warm paper canvas backdrop, bold rose highlights, heavy typography hierarchy, and thin black borders.';
        } else if (i == 4) {
          name = 'B2C Glassmorphic Card';
          style = 'Glassmorphism';
          description = 'Translucent card layouts over bright background spots.';
          bestFor = 'Modern startups, web3 projects, and visual presentation pages';
          layout = {
            'header': 'Frosted glass header with blurring backdrop filters',
            'sidebar': 'None',
            'navigation': 'Top pill-button selectors',
            'heroSection': 'Bold main heading with frosted content cards overlaying gradient bubbles',
            'contentSections': ['Frosted glass feature cards', 'FAQ list section', 'Beta registration form'],
            'footer': 'Social lists and policy notes in translucent layout panels'
          };
          components = ['Frosted Cards', 'Gradient Bubbles', 'Registration Forms', 'Pill Buttons'];
          colorPalette = {
            'primary': '#9333EA',
            'secondary': '#3B82F6',
            'accent': '#F43F5E',
            'background': '#0B0F19'
          };
          generationPrompt = 'Frosted glass layout design over glowing violet and pink background spots, white borders, Outfit headers, and responsive glass cards.';
        } else {
          name = 'B2C Editorial Feed';
          style = 'Modern Startup';
          description = 'Editorial writing articles lists with newsletter signup cards.';
          bestFor = 'Magazines, news blogs, newsletter feeds';
          layout = {
            'header': 'Simple brand name, categories menu dropdowns',
            'sidebar': 'None',
            'navigation': 'Top horizontal links',
            'heroSection': 'Large featured article row with high-impact editorial image details',
            'contentSections': ['Sub-articles list cards', 'Category search tags', 'Newsletter opt-in cards'],
            'footer': 'Editorial bio block and custom details policy links'
          };
          components = ['Articles Grid', 'Newsletter Form', 'Category Switchers', 'Featured Articles'];
          colorPalette = {
            'primary': '#DB2777',
            'secondary': '#4B5563',
            'accent': '#10B981',
            'background': '#FAF9F6'
          };
          generationPrompt = 'High-contrast editorial newspaper layout, clean warm paper backgrounds, rose accents, serif fonts (Playfair Display), and responsive grid blocks.';
        }
      }
      
      templates.add({
        'id': 'template_${i}',
        'name': name,
        'style': style,
        'description': description,
        'bestFor': bestFor,
        'layout': layout,
        'components': components,
        'colorPalette': colorPalette,
        'generationPrompt': generationPrompt
      });
    }
    
    final Map<String, dynamic> responseMap = {
      'projectType': projectType,
      'targetAudience': targetAudience,
      'recommendedStyle': recommendedStyle,
      'templates': templates
    };
    
    _purpose = projectType;
    _audience = targetAudience;
    _design = recommendedStyle;
    
    // Clean previous fields
    _pages = '';
    _colors = '';
    _typography = '';
    _techStack = '';
    _features = '';
    _contentTone = '';
    _constraintsThis = '';
    _projectContext = '';

    final JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _enhancedPromptOutput = encoder.convert(responseMap);

    if (recommendedStyle.toLowerCase().contains('ecommerce')) {
      _detectedImage = 'assets/images/ecommerce_mockup.png';
    } else if (recommendedStyle.toLowerCase().contains('portfolio')) {
      _detectedImage = 'assets/images/portfolio_mockup.png';
    } else if (recommendedStyle.toLowerCase().contains('saas') || recommendedStyle.toLowerCase().contains('dashboard') || recommendedStyle.toLowerCase().contains('fintech') || recommendedStyle.toLowerCase().contains('analytics')) {
      _detectedImage = 'assets/images/saas_mockup.png';
    } else if (recommendedStyle.toLowerCase().contains('blog') || recommendedStyle.toLowerCase().contains('education')) {
      _detectedImage = 'assets/images/blog_mockup.png';
    } else {
      if (normalized.contains('space') ||
          normalized.contains('cosmic') ||
          normalized.contains('cyber') ||
          normalized.contains('dark') ||
          normalized.contains('neon')) {
        _detectedImage = 'assets/images/saas_mockup.png';
      } else {
        _detectedImage = 'assets/images/general_mockup.png';
      }
    }
    
    _aiImageUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent('website UI UX design mockup layout of: $idea. Clean grid structure, professional color palette, highly aesthetic modern web interface, high-resolution desktop view.')}';
  }

  // Sliders for AI Enhancer tuning
  int _toneIndex = 2;
  int _detailIndex = 1;
  int _lengthIndex = 1;

  int get toneIndex => _toneIndex;
  int get detailIndex => _detailIndex;
  int get lengthIndex => _lengthIndex;

  final List<String> tones = ['Casual', 'Friendly', 'Professional', 'Creative', 'Authoritative'];
  final List<String> details = ['Basic', 'Standard', 'Advanced (Expert)'];
  final List<String> lengths = ['Short & Concise', 'Balanced', 'Detailed & Verbose'];

  void updateTone(int index) {
    _toneIndex = index;
    notifyListeners();
  }

  void updateDetail(int index) {
    _detailIndex = index;
    notifyListeners();
  }

  void updateLength(int index) {
    _lengthIndex = index;
    notifyListeners();
  }

  // --- ENHANCER MODE STATE ---
  String _rawPromptInput = '';
  String _enhancedPromptOutput = '';
  bool _isEnhancing = false;

  String get rawPromptInput => _rawPromptInput;
  String get enhancedPromptOutput => _enhancedPromptOutput;
  bool get isEnhancing => _isEnhancing;

  void updateRawPromptInput(String input) {
    _rawPromptInput = input;
    notifyListeners();
  }

  // System instruction template that governs how the enhancer refines prompts.
  static const String _enhancerSystemInstruction = '''
Task: Transform the user's rough input into a clear, detailed, and effective prompt that an AI can understand easily and respond to accurately.

Instructions:
- Do NOT answer the task itself.
- Only generate an improved prompt.
- Preserve the user's original intent.
- Add clarity, structure, and missing details when necessary.
- Use simple, precise language.
- If relevant, include role, context, constraints, and expected output format.
''';

  String get enhancerSystemInstruction => _enhancerSystemInstruction;

  Future<void> enhancePrompt(String input) async {
    if (input.trim().isEmpty) return;

    final allowed = await checkTrialLimitAndTrigger();
    if (!allowed) return;

    _rawPromptInput = input;
    _isEnhancing = true;
    _enhancedPromptOutput = '';
    _apiError = false;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      final result = await _service.generateMasterPrompt(
        rawInput: input,
        tone: tones[_toneIndex],
        detailLevel: details[_detailIndex],
        lengthConstraint: lengths[_lengthIndex],
        token: token,
        isTrial: !_isAuthenticated,
      );
      _enhancedPromptOutput = result;
    } catch (e) {
      _apiError = true;
      _lastErrorMessage = e.toString();
      _runLocalRuleBasedEnhancer(input);
    } finally {
      _isEnhancing = false;
      notifyListeners();
      await incrementTrialCount();
      saveCurrentPromptToHistory();
    }
  }

  void _runLocalRuleBasedEnhancer(String input) {
    final normalized = input.toLowerCase();

    // --- Intent Detection ---
    String detectedRole = 'a knowledgeable and helpful AI assistant';
    String detectedContext = '';
    String refinedTask = input.trim();
    List<String> detectedConstraints = [];
    String outputFormat = 'Provide a well-organized response using clear headings, bullet points, and concise paragraphs where appropriate.';

    // Space & Sci-Fi UI
    if (_matchesAny(normalized, ['space', 'cosmic', 'galaxy', 'nasa', 'astronomy', 'sci-fi', 'futuristic', 'cyberpunk', 'neon', 'nebula'])) {
      detectedRole = 'a futuristic UI/UX designer and systems architect specializing in high-fidelity sci-fi HUDs and space exploration interfaces';
      detectedContext = 'The user is building or designing a space-themed or futuristic UI interface. The output should be immersive, detailed, and focus on stellar visuals, telemetry widgets, and high-tech aesthetics.';
      refinedTask = 'Design a comprehensive futuristic UI layout specification and code directives for:\n\n"$input"\n\nInclude cosmic color palettes, high-tech components, and detailed step-by-step layout implementation instructions.';
      detectedConstraints = [
        'Use a dark, immersive color palette (nebula purples, star-gaze cyans, obsidian black).',
        'Incorporate telemetry widgets, starfield canvas backgrounds, or orbital visual mockups.',
        'Ensure the design system utilizes futuristic typography and high-contrast glowing border lines.',
        'Detail responsive HUD panel structures with precise flex/grid placement.',
      ];
      outputFormat = 'Structure as: Role Persona → Cosmic Design Spec → Core HUD Panels → Technical Guidelines → Implementation Steps.';
    }
    // Learning & Explanation
    else if (_matchesAny(normalized, ['study', 'learn', 'explain', 'what is', 'how does', 'teach', 'understand', 'tutorial', 'guide', 'difference between', 'compare', 'why does', 'concept', 'theory', 'definition', 'roadmap', 'how to'])) {
      detectedRole = 'a patient and experienced educator who excels at breaking down complex topics using the Feynman Technique';
      detectedContext = 'The user wants to deeply understand a concept. The explanation should be accessible, layered from simple to advanced, and include relatable analogies.';
      refinedTask = _refineForLearning(input);
      detectedConstraints = [
        'Start with a simple, jargon-free definition that a beginner could understand.',
        'Include at least one everyday analogy to anchor the concept.',
        'Define any technical terms immediately when first introduced.',
        'Build understanding progressively: simple → intermediate → advanced.',
        'End with 2-3 conceptual check questions to test comprehension.',
      ];
      outputFormat = 'Structure as: Simple Definition → Detailed Explanation → Real-World Analogy → Deeper Dive → Comprehension Check Questions.';
    }
    // Coding & Development
    else if (_matchesAny(normalized, ['code', 'python', 'javascript', 'flutter', 'dart', 'bug', 'api', 'function', 'class', 'database', 'sql', 'react', 'html', 'css', 'debug', 'error', 'compile', 'algorithm', 'data structure', 'backend', 'frontend'])) {
      detectedRole = 'a senior software engineer with deep expertise in clean architecture, testing, and production-grade code';
      detectedContext = 'The user needs help with a software development task. They may be building, debugging, or optimizing code.';
      refinedTask = _refineForCoding(input);
      detectedConstraints = [
        'Write complete, runnable code — no placeholders or pseudo-code unless explicitly requested.',
        'Follow SOLID principles and use descriptive naming conventions.',
        'Include brief inline comments for complex logic.',
        'Handle edge cases and potential errors gracefully.',
        'If multiple approaches exist, recommend the most performant one and explain why.',
      ];
      outputFormat = 'Output complete code blocks with language annotations. Follow each code block with a brief explanation of the approach and any assumptions made.';
    }
    // Creative Writing & Content
    else if (_matchesAny(normalized, ['write', 'story', 'essay', 'email', 'blog', 'copy', 'article', 'poem', 'letter', 'script', 'novel', 'content', 'draft', 'headline', 'tagline', 'slogan'])) {
      detectedRole = 'an expert copywriter and creative writing coach with 10+ years of experience crafting compelling narratives';
      detectedContext = 'The user wants to create engaging written content. The output should be polished, original, and audience-aware.';
      refinedTask = _refineForWriting(input);
      detectedConstraints = [
        'Use a compelling hook in the opening line.',
        'Apply the "Show, Don\'t Tell" technique to maximize reader engagement.',
        'Ensure smooth paragraph transitions and logical flow.',
        'Avoid clichés, filler words, and unnecessary jargon.',
        'Tailor the voice and vocabulary to the intended audience.',
      ];
      outputFormat = 'Structure with a clear introduction, body sections with subheadings, and a strong conclusion. Use formatting (bold, italics) sparingly for emphasis.';
    }
    // Marketing & Business Strategy
    else if (_matchesAny(normalized, ['marketing', 'business', 'sale', 'strategy', 'pitch', 'brand', 'startup', 'revenue', 'growth', 'campaign', 'social media', 'seo', 'ads', 'customer', 'pricing', 'competitor'])) {
      detectedRole = 'a senior business strategist and growth marketing consultant who specializes in data-driven decision making';
      detectedContext = 'The user needs actionable business or marketing guidance. Recommendations should be practical, measurable, and grounded in current industry best practices.';
      refinedTask = _refineForBusiness(input);
      detectedConstraints = [
        'Base all recommendations on current industry trends and proven frameworks.',
        'Include realistic KPIs and success metrics wherever applicable.',
        'Identify potential risks alongside each recommendation.',
        'Prioritize action items by impact and effort.',
        'Avoid vague advice — every suggestion should be specific and implementable.',
      ];
      outputFormat = 'Provide a structured executive summary, followed by numbered action items. Use tables or frameworks (e.g., SWOT, AIDA) where they add clarity.';
    }
    // Data & Analysis
    else if (_matchesAny(normalized, ['analyze', 'data', 'chart', 'graph', 'statistics', 'trend', 'report', 'dashboard', 'metric', 'insight', 'forecast', 'predict'])) {
      detectedRole = 'a data analyst and insights specialist skilled in translating raw data into actionable business intelligence';
      detectedContext = 'The user needs analytical help — interpreting data, generating insights, or structuring findings into a digestible format.';
      refinedTask = _refineForAnalysis(input);
      detectedConstraints = [
        'Clearly distinguish between correlation and causation.',
        'State all assumptions and data limitations explicitly.',
        'Provide both quantitative findings and qualitative interpretation.',
        'Suggest next steps or follow-up analyses where relevant.',
      ];
      outputFormat = 'Present findings with clear section headers. Use numbered lists for key insights and suggest visual representations (chart types) where applicable.';
    }
    // General / Unclassified
    else {
      detectedContext = 'The user has provided a general request that needs to be structured into a clear, actionable prompt.';
      refinedTask = _refineGeneral(input);
      detectedConstraints = [
        'Be thorough but concise — avoid unnecessary filler.',
        'Organize the response with clear structure and logical flow.',
        'If the request is ambiguous, address the most likely interpretation and note alternatives.',
      ];
    }

    // --- Assemble the Refined Prompt ---
    final StringBuffer refined = StringBuffer();

    refined.writeln('**Role:** You are $detectedRole.');
    refined.writeln();

    if (detectedContext.isNotEmpty) {
      refined.writeln('**Context:** $detectedContext');
      refined.writeln();
    }

    refined.writeln('**Task:**');
    refined.writeln(refinedTask);
    refined.writeln();

    if (detectedConstraints.isNotEmpty) {
      refined.writeln('**Constraints:**');
      for (final c in detectedConstraints) {
        refined.writeln('- $c');
      }
      refined.writeln();
    }

    refined.writeln('**Stylistic Guidelines:**');
    refined.writeln('- Adopt a **${tones[_toneIndex]}** tone throughout.');
    refined.writeln('- Provide a **${details[_detailIndex]}** level of depth and detail.');
    refined.writeln('- Target output length: **${lengths[_lengthIndex]}**.');
    refined.writeln();

    refined.writeln('**Expected Output Format:**');
    refined.writeln(outputFormat);

    _enhancedPromptOutput = refined.toString().trim();
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  String _refineForCoding(String input) {
    return 'Write a complete, production-ready implementation for the following request:\n\n"$input"\n\nInclude error handling, follow best practices for the relevant language/framework, and explain your design decisions briefly after the code.';
  }

  String _refineForWriting(String input) {
    return 'Create a polished, publication-ready piece of writing based on the following brief:\n\n"$input"\n\nEnsure the content is original, engaging, and tailored to the target audience. Provide the complete text, not just an outline.';
  }

  String _refineForBusiness(String input) {
    return 'Develop a comprehensive, actionable strategy based on the following business need:\n\n"$input"\n\nInclude specific recommendations, timeline estimates, and measurable success criteria.';
  }

  String _refineForLearning(String input) {
    return 'Provide a thorough, beginner-friendly explanation of the following topic:\n\n"$input"\n\nBuild understanding progressively, using relatable analogies and concrete examples to make abstract concepts tangible.';
  }

  String _refineForAnalysis(String input) {
    return 'Perform a structured analysis based on the following request:\n\n"$input"\n\nPresent key findings, highlight patterns or anomalies, and recommend actionable next steps based on the analysis.';
  }

  String _refineGeneral(String input) {
    return 'Address the following request thoroughly and clearly:\n\n"$input"\n\nProvide a well-structured response that directly addresses what is being asked, with actionable details where appropriate.';
  }

  // --- GENERATED PROMPT COMPOSITION ---
  String get generatedPrompt {
    if (_currentMode == PromptBuilderMode.enhancer) {
      return _enhancedPromptOutput.isNotEmpty 
          ? _enhancedPromptOutput 
          : 'Your enhanced prompt will appear here once you hit "Enhance".';
    }

    // If loaded from history or generated by the API, return that directly if set
    if (_enhancedPromptOutput.isNotEmpty && !_isEnhancing) {
      return _enhancedPromptOutput;
    }

    if (_rawPromptInput.trim().isEmpty) {
      return 'Your compiled Master Prompt will appear here once you describe your website idea and click "Generate Spec & Master Prompt".';
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('========================================================================');
    buffer.writeln('                      MASTER AI WEB DEVELOPER PROMPT');
    buffer.writeln('========================================================================');
    buffer.writeln('');
    buffer.writeln('You are a Senior Full-Stack Engineer, UI/UX Architect, and AI DevOps Assistant.');
    buffer.writeln('Your task is to build a fully functional, pixel-perfect website based on the following natural language idea:');
    buffer.writeln('"$_rawPromptInput"');
    buffer.writeln('');
    buffer.writeln('Below is the verified specification and step-by-step CLI-ready instructions to execute this build.');
    buffer.writeln('');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('1. WEBSITE SPECIFICATION & TECHNICAL BLUEPRINT');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('• Website Category: ${_purpose.isNotEmpty ? _purpose : "General Web Application"}');
    buffer.writeln('• Target Audience: ${_audience.isNotEmpty ? _audience : "General Public"}');
    buffer.writeln('• Core Tech Stack: ${_techStack.isNotEmpty ? _techStack : "HTML5, CSS3, ES6 JavaScript"}');
    buffer.writeln('• Pages to Implement:');
    if (_pages.isNotEmpty) {
      final list = _pages.split(',');
      for (final p in list) {
        buffer.writeln('  * ${p.trim()}: Main page implementation');
      }
    } else {
      buffer.writeln('  * Home Page: Landing and introduction');
    }
    buffer.writeln('');
    buffer.writeln('• Design System & Aesthetic:');
    buffer.writeln('  * Theme Style: ${_design.isNotEmpty ? _design : "Modern layout"}');
    buffer.writeln('  * Color Palette: ${_colors.isNotEmpty ? _colors : "default theme color tokens"}');
    buffer.writeln('  * Typography: ${_typography.isNotEmpty ? _typography : "default text styling"}');
    buffer.writeln('  * Content Tone: ${_contentTone.isNotEmpty ? _contentTone : "Professional"}');
    buffer.writeln('');
    buffer.writeln('• Required Features & Functionality:');
    if (_features.isNotEmpty) {
      final list = _features.split(',');
      for (final f in list) {
        buffer.writeln('  * ${f.trim()}');
      }
    } else {
      buffer.writeln('  * Responsive navigation and interactive layouts');
    }
    buffer.writeln('');
    buffer.writeln('• Accessibility & Technical Constraints:');
    buffer.writeln('  * Accessibility: ${_constraintsThis.isNotEmpty ? _constraintsThis : "WCAG AA compliant contrast ratio"}');
    buffer.writeln('  * Responsive Layout: Mobile-first layout with breakpoints at 768px and 1100px');
    buffer.writeln('  * Code Quality: Write clean, modular, and reusable CSS variables and semantic HTML tags.');
    buffer.writeln('');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('2. SYSTEM SETUP & PROJECT DIRECTORY STRUCTURE');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Context: ${_projectContext.isNotEmpty ? _projectContext : "Empty root directory"}');
    buffer.writeln('Initialize the project structure as follows:');
    buffer.writeln('- index.html (Main Entrypoint)');
    buffer.writeln('- css/');
    buffer.writeln('  - styles.css (Global variables and baseline reset)');
    buffer.writeln('  - components.css (Custom buttons, grid panels, and input fields)');
    buffer.writeln('- js/');
    buffer.writeln('  - app.js (Navigation router and interaction handlers)');
    buffer.writeln('');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('3. STEP-BY-STEP IMPLEMENTATION INSTRUCTIONS');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('Follow these directives to build the website:');
    buffer.writeln('');
    buffer.writeln('Step A: Setup baseline CSS variables in `css/styles.css` matching the design system:');
    buffer.writeln('  * Define color tokens: ${_colors.isNotEmpty ? _colors : "default color system"}');
    buffer.writeln('  * Setup Typography: ${_typography.isNotEmpty ? _typography : "default typography system"}');
    buffer.writeln('  * Create a global border-box reset and standard layout grid utilities.');
    buffer.writeln('');
    buffer.writeln('Step B: Create reusable UI components in `css/components.css`:');
    buffer.writeln('  * Button states: active, hover, loading (solid outlines, 3D offset shadow transitions).');
    buffer.writeln('  * Panel containers: solid borders, card frames with header banners.');
    buffer.writeln('  * Inputs: Styled focus states with error labels.');
    buffer.writeln('');
    buffer.writeln('Step C: Build page structures in `index.html`:');
    buffer.writeln('  * Construct a responsive navigation menu.');
    buffer.writeln('  * Implement the following page sections (toggled via active classes):');
    if (_pages.isNotEmpty) {
      final list = _pages.split(',');
      for (final p in list) {
        buffer.writeln('    - ${p.trim()}: Layout container with appropriate heading hierarchy.');
      }
    } else {
      buffer.writeln('    - Home: Welcome screen layout.');
    }
    buffer.writeln('');
    buffer.writeln('Step D: Write Javascript routing and features in `js/app.js`:');
    buffer.writeln('  * Core router: Manage active section toggling with CSS animations.');
    buffer.writeln('  * Feature integrations:');
    if (_features.isNotEmpty) {
      final list = _features.split(',');
      for (final f in list) {
        buffer.writeln('    - ${f.trim()}: Setup event listeners and state logic.');
      }
    } else {
      buffer.writeln('    - Setup dynamic element interactions and form validation handlers.');
    }
    buffer.writeln('');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('4. STRICT COMPLETENESS CONSTRAINT');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('You must write COMPLETE, run-ready code blocks for each file. Do NOT use placeholders, comments like "// implement later", or dummy text. Write the complete HTML body, CSS styling, and JavaScript logic to guarantee a production-grade result.');

    return buffer.toString().trim();
  }

  // --- HISTORY & FAVORITES MANAGEMENT ---
  final List<SavedPrompt> _history = [];
  List<SavedPrompt> get history => _history;

  Future<void> saveCurrentPromptToHistory() async {
    final text = generatedPrompt;
    if (text.isEmpty || 
        text.startsWith('Your enhanced') || 
        (_purpose.isEmpty && _currentMode != PromptBuilderMode.enhancer)) {
      return;
    }

    // Determine title
    String title = 'PROMPT->THIS Spec';
    if (_currentMode == PromptBuilderMode.template) {
      title = _purpose.isNotEmpty 
          ? (_purpose.length > 25 ? '${_purpose.substring(0, 22)}...' : _purpose) 
          : 'PROMPT->THIS Spec';
    } else if (_currentMode == PromptBuilderMode.enhancer) {
      title = _rawPromptInput.length > 30 
          ? '${_rawPromptInput.substring(0, 27)}...' 
          : _rawPromptInput;
    }

    // Avoid saving exact duplicates back-to-back
    if (_history.isNotEmpty && _history.first.text == text) {
      return;
    }

    final saved = SavedPrompt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      title: title,
      timestamp: DateTime.now(),
      mode: _currentMode.name,
    );

    _history.insert(0, saved);
    notifyListeners();

    // Persist to Supabase if authenticated
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('prompt_history').insert({
          'id': saved.id,
          'user_id': user.id,
          'text': saved.text,
          'title': saved.title,
          'mode': saved.mode,
          'is_favorite': saved.isFavorite,
          'created_at': saved.timestamp.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error saving prompt history to Supabase: $e');
      }
    }
  }

  Future<void> toggleFavorite(String id) async {
    final index = _history.indexWhere((p) => p.id == id);
    if (index != -1) {
      _history[index].isFavorite = !_history[index].isFavorite;
      notifyListeners();

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('prompt_history')
              .update({'is_favorite': _history[index].isFavorite})
              .eq('id', id);
        } catch (e) {
          debugPrint('Error updating favorite: $e');
        }
      }
    }
  }

  Future<void> deletePrompt(String id) async {
    _history.removeWhere((p) => p.id == id);
    notifyListeners();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('prompt_history')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('Error deleting prompt: $e');
      }
    }
  }

  void loadSavedPrompt(SavedPrompt prompt) {
    if (prompt.mode == 'template') {
      _currentMode = PromptBuilderMode.template;
      _enhancedPromptOutput = prompt.text;
      _purpose = ''; // Clear purpose so generatedPrompt returns _enhancedPromptOutput directly
    } else {
      _currentMode = PromptBuilderMode.enhancer;
      _enhancedPromptOutput = prompt.text;
    }
    notifyListeners();
  }

  void downloadTemplateHtml(Map<String, dynamic> template, String projectType) {
    final name = template['name'] ?? 'UI Template';
    final style = template['style'] ?? 'Modern UI';
    final description = template['description'] ?? '';
    final bestFor = template['bestFor'] ?? '';
    
    final layout = template['layout'] as Map<String, dynamic>? ?? {};
    final header = layout['header'] ?? 'Navbar';
    final sidebar = layout['sidebar'] ?? 'None';
    final navigation = layout['navigation'] ?? 'Top Navigation';
    final hero = layout['heroSection'] ?? 'Welcome Section';
    final contents = layout['contentSections'] as List<dynamic>? ?? [];
    final footer = layout['footer'] ?? 'Footer';
    
    final components = template['components'] as List<dynamic>? ?? [];
    
    final palette = template['colorPalette'] as Map<String, dynamic>? ?? {};
    final primary = palette['primary'] ?? '#3B82F6';
    final secondary = palette['secondary'] ?? '#1E293B';
    final accent = palette['accent'] ?? '#F59E0B';
    final background = palette['background'] ?? '#F8FAFC';
    
    final prompt = template['generationPrompt'] ?? '';

    final lowerStyle = style.toString().toLowerCase();
    final isDark = background.toString().startsWith('#0') || background.toString().startsWith('#1') || lowerStyle.contains('dark') || lowerStyle.contains('cyberpunk');
    final textColor = isDark ? '#F8FAFC' : '#0F172A';
    final cardBg = isDark ? '#1E293B' : '#FFFFFF';
    final cardBorder = isDark ? '#334155' : '#E2E8F0';
    
    final StringBuffer html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="en">');
    html.writeln('<head>');
    html.writeln('    <meta charset="UTF-8">');
    html.writeln('    <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    html.writeln('    <title>$name - $style Spec</title>');
    html.writeln('    <!-- Google Fonts -->');
    html.writeln('    <link rel="preconnect" href="https://fonts.googleapis.com">');
    html.writeln('    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>');
    html.writeln('    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@600;800&family=Orbitron:wght@700;900&display=swap" rel="stylesheet">');
    html.writeln('    <!-- Tailwind CSS -->');
    html.writeln('    <script src="https://cdn.tailwindcss.com"></script>');
    html.writeln('    <script>');
    html.writeln('        tailwind.config = {');
    html.writeln('            theme: {');
    html.writeln('                extend: {');
    html.writeln('                    colors: {');
    html.writeln('                        primary: \'$primary\',');
    html.writeln('                        secondary: \'$secondary\',');
    html.writeln('                        accent: \'$accent\',');
    html.writeln('                        background: \'$background\',');
    html.writeln('                        cardBg: \'$cardBg\',');
    html.writeln('                        cardBorder: \'$cardBorder\',');
    html.writeln('                        customText: \'$textColor\'');
    html.writeln('                    },');
    html.writeln('                    fontFamily: {');
    html.writeln('                        sans: [\'Inter\', \'sans-serif\'],');
    html.writeln('                        heading: [\'Outfit\', \'sans-serif\'],');
    html.writeln('                        orbitron: [\'Orbitron\', \'sans-serif\']');
    html.writeln('                    }');
    html.writeln('                }');
    html.writeln('            }');
    html.writeln('        }');
    html.writeln('    </script>');
    html.writeln('    <style>');
    html.writeln('        body {');
    html.writeln('            background-color: $background;');
    html.writeln('            color: $textColor;');
    html.writeln('            font-family: \'Inter\', sans-serif;');
    html.writeln('        }');
    html.writeln('    </style>');
    html.writeln('</head>');
    html.writeln('<body class="min-h-screen flex flex-col">');
    html.writeln('    <header class="border-b border-cardBorder bg-cardBg py-4 px-6 sticky top-0 z-50 shadow-sm">');
    html.writeln('        <div class="max-w-7xl mx-auto flex items-center justify-between">');
    html.writeln('            <div class="flex items-center gap-3">');
    html.writeln('                <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center text-white font-bold font-heading">T</div>');
    html.writeln('                <span class="font-heading font-extrabold text-lg tracking-tight">$name</span>');
    html.writeln('            </div>');
    html.writeln('            <div class="hidden md:flex items-center gap-6 text-sm font-medium">');
    html.writeln('                <span class="hover:text-primary cursor-pointer transition font-mono">Home</span>');
    html.writeln('                <span class="hover:text-primary cursor-pointer transition font-mono">Features</span>');
    html.writeln('                <span class="hover:text-primary cursor-pointer transition font-mono">Pricing</span>');
    html.writeln('                <span class="hover:text-primary cursor-pointer transition font-mono">Docs</span>');
    html.writeln('            </div>');
    html.writeln('            <div class="flex items-center gap-3">');
    html.writeln('                <button class="bg-primary hover:opacity-90 text-white font-semibold text-xs px-4 py-2 rounded-lg transition shadow-sm shadow-primary/20">Get Started</button>');
    html.writeln('            </div>');
    html.writeln('        </div>');
    html.writeln('    </header>');
    html.writeln('    <div class="flex-1 flex flex-col md:flex-row max-w-7xl mx-auto w-full">');
    if (sidebar != 'None' && sidebar != 'none' && sidebar.toString().isNotEmpty) {
      html.writeln('        <aside class="w-full md:w-64 border-r border-cardBorder bg-cardBg/50 p-6 flex flex-col gap-6">');
      html.writeln('            <div>');
      html.writeln('                <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Navigation</h3>');
      html.writeln('                <p class="text-xs text-gray-500 mb-4 font-mono">$navigation</p>');
      html.writeln('                <ul class="flex flex-col gap-2 text-sm">');
      html.writeln('                    <li class="bg-primary/10 text-primary font-medium px-3 py-2 rounded-lg cursor-pointer">Dashboard</li>');
      html.writeln('                    <li class="hover:bg-cardBg px-3 py-2 rounded-lg cursor-pointer transition">Analytics</li>');
      html.writeln('                    <li class="hover:bg-cardBg px-3 py-2 rounded-lg cursor-pointer transition">Settings</li>');
      html.writeln('                </ul>');
      html.writeln('            </div>');
      html.writeln('            <div class="mt-auto border-t border-cardBorder pt-4">');
      html.writeln('                <h4 class="text-xs font-bold font-heading mb-1">Sidebar Spec:</h4>');
      html.writeln('                <p class="text-xs text-gray-500">$sidebar</p>');
      html.writeln('            </div>');
      html.writeln('        </aside>');
    }
    html.writeln('        <main class="flex-1 p-6 md:p-10 flex flex-col gap-10">');
    html.writeln('            <section class="rounded-2xl border border-cardBorder bg-cardBg/80 p-8 md:p-12 relative overflow-hidden shadow-sm">');
    html.writeln('                <div class="max-w-2xl flex flex-col gap-4 relative z-10">');
    html.writeln('                    <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-primary/10 text-primary border border-primary/20">$style Style</span>');
    html.writeln('                    <h1 class="text-3xl md:text-5xl font-heading font-extrabold tracking-tight">$name</h1>');
    html.writeln('                    <p class="text-base text-gray-400">$description</p>');
    html.writeln('                    <div class="mt-4 flex flex-wrap items-center gap-3">');
    html.writeln('                        <button class="bg-primary hover:opacity-90 text-white font-bold text-sm px-6 py-3 rounded-xl transition shadow-lg shadow-primary/25">Deploy Template</button>');
    html.writeln('                        <button class="border border-cardBorder hover:bg-cardBg text-customText font-bold text-sm px-6 py-3 rounded-xl transition">View Docs</button>');
    html.writeln('                    </div>');
    html.writeln('                </div>');
    html.writeln('                <div class="absolute right-0 top-0 bottom-0 w-1/3 opacity-10 bg-gradient-to-l from-primary to-transparent hidden md:block"></div>');
    html.writeln('            </section>');
    html.writeln('            <section class="grid grid-cols-1 md:grid-cols-2 gap-6">');
    html.writeln('                <div class="border border-cardBorder bg-cardBg/40 p-6 rounded-xl">');
    html.writeln('                    <h3 class="font-heading font-bold text-sm mb-3 text-primary uppercase tracking-wider">Product Info</h3>');
    html.writeln('                    <ul class="flex flex-col gap-2.5 text-xs text-gray-400">');
    html.writeln('                        <li><strong class="text-customText">Project Type:</strong> $projectType</li>');
    html.writeln('                        <li><strong class="text-customText">Target Audience:</strong> $audience</li>');
    html.writeln('                        <li><strong class="text-customText">Best For:</strong> $bestFor</li>');
    html.writeln('                    </ul>');
    html.writeln('                </div>');
    html.writeln('                <div class="border border-cardBorder bg-cardBg/40 p-6 rounded-xl">');
    html.writeln('                    <h3 class="font-heading font-bold text-sm mb-3 text-accent uppercase tracking-wider">Components list</h3>');
    html.writeln('                    <div class="flex flex-wrap gap-2">');
    for (final comp in components) {
      html.writeln('                        <span class="px-2.5 py-1 rounded bg-cardBg border border-cardBorder text-xs text-gray-300 font-mono">$comp</span>');
    }
    html.writeln('                    </div>');
    html.writeln('                </div>');
    html.writeln('            </section>');
    html.writeln('            <section class="flex flex-col gap-4">');
    html.writeln('                <h2 class="font-heading font-extrabold text-xl tracking-tight mb-2">Content Layout Sections</h2>');
    html.writeln('                <div class="grid grid-cols-1 md:grid-cols-3 gap-6">');
    for (int idx = 0; idx < contents.length; idx++) {
      final sectionDesc = contents[idx];
      html.writeln('                    <div class="border border-cardBorder bg-cardBg p-6 rounded-xl shadow-sm flex flex-col gap-3">');
      html.writeln('                        <div class="w-8 h-8 rounded-lg bg-accent/15 text-accent flex items-center justify-center text-xs font-bold font-mono">${idx + 1}</div>');
      html.writeln('                        <h4 class="font-heading font-bold text-sm text-customText">Section ${idx + 1}</h4>');
      html.writeln('                        <p class="text-xs text-gray-400 leading-relaxed">$sectionDesc</p>');
      html.writeln('                    </div>');
    }
    html.writeln('                </div>');
    html.writeln('            </section>');
    html.writeln('            <section class="border border-dashed border-primary/40 bg-primary/5 p-6 rounded-xl flex flex-col gap-3">');
    html.writeln('                <div class="flex items-center gap-2">');
    html.writeln('                    <span class="text-sm">🪄</span>');
    html.writeln('                    <h3 class="font-heading font-bold text-sm text-primary">AI Prompt For UI Generation</h3>');
    html.writeln('                </div>');
    html.writeln('                <p class="text-xs text-gray-400 leading-relaxed italic">"$prompt"</p>');
    html.writeln('            </section>');
    html.writeln('        </main>');
    html.writeln('    </div>');
    html.writeln('    <footer class="border-t border-cardBorder bg-cardBg py-8 px-6 mt-auto text-xs text-gray-500">');
    html.writeln('        <div class="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">');
    html.writeln('            <p>Footer Spec: $footer</p>');
    html.writeln('            <p>&copy; ${DateTime.now().year} PromptMe Inc. All rights reserved.</p>');
    html.writeln('        </div>');
    html.writeln('    </footer>');
    html.writeln('</body>');
    html.writeln('</html>');

    final filename = name.toString().toLowerCase().replaceAll(RegExp(r'\s+'), '_') + '_template.html';
    FileExporter.downloadText(
      content: html.toString(),
      filename: filename,
      mimeType: 'text/html',
    );
  }
}
