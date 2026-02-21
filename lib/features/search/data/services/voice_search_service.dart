// lib/features/search/data/services/voice_search_service.dart

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceSearchStatus {
  idle,
  initializing,
  listening,
  processing,
  done,
  error,
  notAvailable,
  permissionDenied,
}

class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  
  bool _isInitialized = false;
  VoiceSearchStatus _status = VoiceSearchStatus.idle;
  String _lastError = '';
  String _currentLocaleId = 'en_US';

  // Callbacks
  Function(String text, bool isFinal)? onResult;
  Function(VoiceSearchStatus status)? onStatusChanged;
  Function(String error)? onError;

  VoiceSearchStatus get status => _status;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;
  String get lastError => _lastError;

  // Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _updateStatus(VoiceSearchStatus.initializing);

    try {
      // Check microphone permission
      final permissionStatus = await Permission.microphone.request();
      
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        _updateStatus(VoiceSearchStatus.permissionDenied);
        _lastError = 'Microphone permission denied';
        onError?.call(_lastError);
        return false;
      }

      // Initialize speech to text
      _isInitialized = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );

      if (!_isInitialized) {
        _updateStatus(VoiceSearchStatus.notAvailable);
        _lastError = 'Speech recognition not available on this device';
        onError?.call(_lastError);
        return false;
      }

      // Get available locales and set preferred
      final locales = await _speech.locales();
      
      // Prefer English, but fallback to device default
      final englishLocale = locales.firstWhere(
        (l) => l.localeId.startsWith('en'),
        orElse: () => locales.first,
      );
      _currentLocaleId = englishLocale.localeId;

      _updateStatus(VoiceSearchStatus.idle);
      return true;
    } catch (e) {
      _updateStatus(VoiceSearchStatus.error);
      _lastError = 'Failed to initialize: $e';
      onError?.call(_lastError);
      return false;
    }
  }

  // Start listening for voice input
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_speech.isListening) {
      await stopListening();
    }

    _updateStatus(VoiceSearchStatus.listening);

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        localeId: _currentLocaleId,
        cancelOnError: true,
        partialResults: true, // Get results as user speaks
        listenMode: ListenMode.search, // Optimized for search queries
      );
    } catch (e) {
      _updateStatus(VoiceSearchStatus.error);
      _lastError = 'Failed to start listening: $e';
      onError?.call(_lastError);
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _updateStatus(VoiceSearchStatus.done);
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _updateStatus(VoiceSearchStatus.idle);
  }

  // Handle speech result
  void _handleResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    final isFinal = result.finalResult;

    if (isFinal) {
      _updateStatus(VoiceSearchStatus.processing);
    }

    onResult?.call(text, isFinal);

    if (isFinal) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _updateStatus(VoiceSearchStatus.done);
      });
    }
  }

  // Handle status changes
  void _handleStatus(String status) {
    debugPrint('Speech status: $status');
    
    switch (status) {
      case 'listening':
        _updateStatus(VoiceSearchStatus.listening);
        break;
      case 'notListening':
        if (_status == VoiceSearchStatus.listening) {
          _updateStatus(VoiceSearchStatus.processing);
        }
        break;
      case 'done':
        _updateStatus(VoiceSearchStatus.done);
        break;
    }
  }

  // Handle errors
  void _handleError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg}');
    
    _lastError = _getErrorMessage(error.errorMsg);
    _updateStatus(VoiceSearchStatus.error);
    onError?.call(_lastError);
  }

  // Get user-friendly error message
  String _getErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_no_match':
        return 'No speech detected. Please try again.';
      case 'error_speech_timeout':
        return 'No speech detected. Tap to try again.';
      case 'error_audio':
        return 'Audio recording error. Please try again.';
      case 'error_network':
        return 'Network error. Check your connection.';
      case 'error_permission':
        return 'Microphone permission required.';
      case 'error_busy':
        return 'Speech recognition busy. Please wait.';
      default:
        return 'Voice search error. Please try again.';
    }
  }

  // Update status and notify
  void _updateStatus(VoiceSearchStatus newStatus) {
    _status = newStatus;
    onStatusChanged?.call(newStatus);
  }

  // Get available languages
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    return _speech.locales();
  }

  // Set language
  void setLocale(String localeId) {
    _currentLocaleId = localeId;
  }

  // Dispose
  void dispose() {
    if (_speech.isListening) {
      _speech.cancel();
    }
  }
}

// Singleton instance
final voiceSearchService = VoiceSearchService();