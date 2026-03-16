// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../core/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _SettingItem(
                    label: 'Exotel Number',
                    value: AppConstants.exotelNumber,
                  ),
                  _SettingItem(
                    label: 'Backend URL',
                    value: AppConstants.backendUrl,
                  ),
                  _SettingItem(
                    label: 'Supabase Project',
                    value: AppConstants.supabaseUrl.replace('https://', '').replace('.supabase.co', ''),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setup Instructions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To use this app, you need to:\n\n'
                    '1. Set up accounts: Exotel, Anthropic (Claude), Deepgram, ElevenLabs, Supabase, Firebase\n'
                    '2. Deploy the backend to Railway.app\n'
                    '3. Configure Exotel webhook to point to your backend\n'
                    '4. Enable call forwarding using the AI Mode toggle\n\n'
                    'See the README.md for detailed instructions.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Version Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const _SettingItem(label: 'Version', value: '1.0.0'),
                  const _SettingItem(label: 'Platform', value: 'Android (Flutter)'),
                  const _SettingItem(label: 'Telephony', value: 'Exotel (India)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final String label;
  final String value;

  const _SettingItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
