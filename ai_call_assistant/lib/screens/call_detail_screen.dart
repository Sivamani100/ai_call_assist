// lib/screens/call_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/call_logs_provider.dart';
import '../models/call_log.dart';

class CallDetailScreen extends ConsumerWidget {
  final String callLogId;

  const CallDetailScreen({super.key, required this.callLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callLogAsync = ref.watch(callLogByIdProvider(callLogId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: () => context.go('/ai-reply'),
            tooltip: 'Reply via AI',
          ),
        ],
      ),
      body: callLogAsync.when(
        data: (callLog) => callLog != null
            ? _CallDetailContent(callLog: callLog)
            : const Center(child: Text('Call not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading call: $error'),
        ),
      ),
    );
  }
}

class _CallDetailContent extends StatelessWidget {
  final CallLog callLog;

  const _CallDetailContent({required this.callLog});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy at hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        callLog.urgencyEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              callLog.displayName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              callLog.callStartTime != null
                                  ? dateFormat.format(callLog.callStartTime!)
                                  : 'Unknown time',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (callLog.aiSummary != null) ...[
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(callLog.aiSummary!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Call Details
          if (callLog.callType != null || callLog.callerRelationship != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (callLog.callType != null)
                      _DetailRow(label: 'Type', value: callLog.callType!),
                    if (callLog.callerRelationship != null)
                      _DetailRow(label: 'Relationship', value: callLog.callerRelationship!),
                    if (callLog.callDurationSec != null)
                      _DetailRow(label: 'Duration', value: '${callLog.callDurationSec}s'),
                    if (callLog.urgencyLevel != null)
                      _DetailRow(label: 'Urgency', value: callLog.urgencyLevel!),
                    if (callLog.deadline != null && callLog.deadline!.isNotEmpty)
                      _DetailRow(label: 'Deadline', value: callLog.deadline!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Items
          if (callLog.actionNeeded != null && callLog.actionNeeded!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Needed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(callLog.actionNeeded!),
                    if (callLog.shouldCallBack == true) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/ai-reply'),
                        icon: const Icon(Icons.call),
                        label: const Text('Call Back via AI'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Transcript
          if (callLog.fullTranscript != null && callLog.fullTranscript!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transcript',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ...callLog.fullTranscript!.map((turn) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            turn['speaker'] == 'caller' ? 'Caller:' : 'AI:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: turn['speaker'] == 'caller'
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(turn['text'])),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
