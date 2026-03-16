// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/call_logs_provider.dart';
import '../services/call_forwarding_service.dart';
import '../core/constants.dart';
import '../models/call_log.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = false;

  Future<void> _toggleAIMode() async {
    setState(() => _isLoading = true);
    final aiModeNotifier = ref.read(aiModeProvider.notifier);
    final isCurrentlyOn = ref.read(aiModeProvider);

    if (isCurrentlyOn) {
      // Turning OFF AI mode
      final success = await CallForwardingService.disable();
      if (success) {
        await aiModeNotifier.toggleMode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Mode disabled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to disable call forwarding')),
        );
      }
    } else {
      // Turning ON AI mode
      final success = await CallForwardingService.enable(AppConstants.exotelNumber);
      if (success) {
        await aiModeNotifier.toggleMode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Mode enabled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to enable call forwarding')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.phone.request();
    await Permission.contacts.request();
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    final aiModeAsync = ref.watch(aiModeProvider);
    final callLogsAsync = ref.watch(callLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Call Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Mode Toggle Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        aiModeAsync ? Icons.smart_toy : Icons.phone_disabled,
                        size: 32,
                        color: aiModeAsync ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aiModeAsync ? 'AI Mode: ON' : 'AI Mode: OFF',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              aiModeAsync
                                  ? 'Calls are forwarded to AI assistant'
                                  : 'Calls ring normally on your phone',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: aiModeAsync,
                        onChanged: _isLoading ? null : (_) => _toggleAIMode(),
                      ),
                    ],
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),

          // Call Logs List
          Expanded(
            child: callLogsAsync.when(
              data: (callLogs) => callLogs.isEmpty
                  ? const Center(
                      child: Text('No calls yet. Enable AI mode to start receiving calls!'),
                    )
                  : ListView.builder(
                      itemCount: callLogs.length,
                      itemBuilder: (context, index) {
                        final callLog = callLogs[index];
                        return CallLogTile(callLog: callLog);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading calls: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CallLogTile extends StatelessWidget {
  final CallLog callLog;

  const CallLogTile({super.key, required this.callLog});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(callLog.urgencyEmoji),
      ),
      title: Text(callLog.displayName),
      subtitle: Text(
        callLog.aiSummary ?? 'No summary available',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        callLog.callStartTime != null
            ? '${callLog.callStartTime!.hour}:${callLog.callStartTime!.minute.toString().padLeft(2, '0')}'
            : '',
      ),
      onTap: () => context.go('/call/${callLog.id}'),
    );
  }
}
