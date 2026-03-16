// lib/providers/call_logs_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/call_log.dart';

// Realtime stream — auto-updates when Supabase Realtime fires
final callLogsProvider = StreamProvider<List<CallLog>>((ref) {
  return Supabase.instance.client
      .from('call_logs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => rows.map(CallLog.fromJson).toList());
});

final callLogByIdProvider = FutureProvider.family<CallLog?, String>((ref, id) async {
  final resp = await Supabase.instance.client
      .from('call_logs').select().eq('id', id).single();
  return CallLog.fromJson(resp);
});

// AI Mode provider
final aiModeProvider = StateNotifierProvider<AIModeNotifier, bool>((ref) {
  return AIModeNotifier();
});

class AIModeNotifier extends StateNotifier<bool> {
  AIModeNotifier() : super(false) {
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    try {
      final resp = await Supabase.instance.client
          .from('settings')
          .select('value')
          .eq('key', 'ai_mode')
          .single();
      state = resp['value'] == 'true';
    } catch (e) {
      state = false; // Default to false if not found
    }
  }

  Future<void> toggleMode() async {
    final newMode = !state;
    try {
      await Supabase.instance.client
          .from('settings')
          .upsert({'key': 'ai_mode', 'value': newMode.toString()});
      state = newMode;
    } catch (e) {
      // Handle error - maybe show snackbar in UI
      print('Error updating AI mode: $e');
    }
  }
}
