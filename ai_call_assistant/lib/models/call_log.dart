// lib/models/call_log.dart
import 'package:json_annotation/json_annotation.dart';

part 'call_log.g.dart';

@JsonSerializable()
class CallLog {
  final String id;
  final String? exotelCallSid;
  final String callerNumber;
  final String? callerName;
  final String? callerRelationship;
  final bool? isKnownContact;
  final DateTime? callStartTime;
  final int? callDurationSec;
  final String? callType;
  final String? aiSummary;
  final List<Map<String, dynamic>>? fullTranscript;
  final List<String>? keyDetails;
  final String? urgencyLevel;
  final String? actionNeeded;
  final String? recommendedResponse;
  final String? deadline;
  final bool? shouldCallBack;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CallLog({
    required this.id,
    this.exotelCallSid,
    required this.callerNumber,
    this.callerName,
    this.callerRelationship,
    this.isKnownContact,
    this.callStartTime,
    this.callDurationSec,
    this.callType,
    this.aiSummary,
    this.fullTranscript,
    this.keyDetails,
    this.urgencyLevel,
    this.actionNeeded,
    this.recommendedResponse,
    this.deadline,
    this.shouldCallBack,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) => _$CallLogFromJson(json);
  Map<String, dynamic> toJson() => _$CallLogToJson(this);

  String get displayName => callerName ?? callerNumber;

  String get urgencyEmoji {
    switch (urgencyLevel?.toLowerCase()) {
      case 'urgent': return '🚨';
      case 'high': return '⚠️';
      case 'medium': return '📞';
      default: return '📱';
    }
  }

  bool get isUrgent => urgencyLevel == 'urgent' || urgencyLevel == 'high';
}
