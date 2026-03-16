// lib/services/call_forwarding_service.dart
import 'package:flutter/services.dart';

class CallForwardingService {
  static final MethodChannel _channel = MethodChannel(
    'com.siva.ai_call_assistant/call_forwarding',
  );

  /// Enable call forwarding to Exotel number (AI Mode ON)
  /// exotelNumber: E.164 format, e.g. +918047123456
  static Future<bool> enable(String exotelNumber) async {
    try {
      await _channel.invokeMethod<String>('enableForwarding', {
        'exotelNumber': exotelNumber,
      });
      return true;
    } on PlatformException catch (e) {
      print('[CallForwarding] Enable error: ${e.message}');
      return false;
    }
  }

  /// Disable call forwarding (AI Mode OFF)
  static Future<bool> disable() async {
    try {
      await _channel.invokeMethod<String>('disableForwarding');
      return true;
    } on PlatformException catch (e) {
      print('[CallForwarding] Disable error: ${e.message}');
      return false;
    }
  }

  /// Check carrier forwarding status
  static Future<String> checkStatus() async {
    try {
      return await _channel.invokeMethod<String>('checkForwardingStatus') ??
          'Unknown';
    } on PlatformException catch (e) {
      return 'Error: ${e.message}';
    }
  }
}
