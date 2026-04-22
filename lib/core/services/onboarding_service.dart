import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding state persistence
class OnboardingService {
  static const String _onboardingShownKey = 'onboarding_shown';
  static SharedPreferences? _prefs;

  /// Initialize the service
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if user has already seen the onboarding
  static Future<bool> hasShownOnboarding() async {
    await initialize();
    return _prefs?.getBool(_onboardingShownKey) ?? false;
  }

  /// Mark onboarding as shown
  static Future<void> markOnboardingAsShown() async {
    await initialize();
    await _prefs?.setBool(_onboardingShownKey, true);
  }

  /// Reset onboarding (for testing purposes)
  static Future<void> resetOnboarding() async {
    await initialize();
    await _prefs?.remove(_onboardingShownKey);
  }
}
