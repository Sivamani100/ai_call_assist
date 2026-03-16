// lib/screens/ai_reply_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../providers/call_logs_provider.dart';
import '../models/call_log.dart';

class AIReplyScreen extends ConsumerStatefulWidget {
  final String? callLogId;

  const AIReplyScreen({super.key, this.callLogId});

  @override
  ConsumerState<AIReplyScreen> createState() => _AIReplyScreenState();
}

class _AIReplyScreenState extends ConsumerState<AIReplyScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  CallLog? _callLog;

  @override
  void initState() {
    super.initState();
    if (widget.callLogId != null) {
      _loadCallLog();
    }
  }

  Future<void> _loadCallLog() async {
    final callLogAsync = await ref.read(
      callLogByIdProvider(widget.callLogId!).future,
    );
    setState(() => _callLog = callLogAsync);
  }

  Future<void> _sendAIReply() async {
    if (_messageController.text.trim().isEmpty || _callLog == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to_number': _callLog!.callerNumber,
          'your_message': _messageController.text.trim(),
          'caller_name': _callLog!.callerName ?? 'there',
          'call_log_id': _callLog!.id,
        }),
      );

      if (response.statusCode == 200) {
        // Mark call as replied in database
        await Supabase.instance.client
            .from('call_logs')
            .update({'status': 'replied'})
            .eq('id', _callLog!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI reply sent successfully')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reply: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reply via AI')),
      body: _callLog == null && widget.callLogId != null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_callLog != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replying to: ${_callLog!.displayName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Number: ${_callLog!.callerNumber}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'What would you like the AI to say when calling back?',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'e.g., "I\'ll be available after 3 PM today"',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The AI will call the person back and deliver your message in a natural voice.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendAIReply,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Send AI Reply'),
                  ),
                ],
              ),
            ),
    );
  }
}
