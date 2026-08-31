part of 'package:s11/sessions/friend/friend.dart';

enum _FriendRequestDirection { incoming, outgoing }

enum _FriendRequestStatus { pending, accepted, declined, cancelled }

class _FriendRequest {
  _FriendRequest({
    required this.id,
    required this.username,
    required this.direction,
    this.message,
    this.status = _FriendRequestStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String username;
  final _FriendRequestDirection direction;
  final DateTime createdAt;
  final String? message;
  _FriendRequestStatus status;

  bool get isIncoming => direction == _FriendRequestDirection.incoming;
  bool get isPending => status == _FriendRequestStatus.pending;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'direction': direction.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (message != null) 'message': message,
    };
  }

  factory _FriendRequest.fromJson(Map<String, dynamic> json) {
    final directionRaw = json['direction']?.toString() ?? 'incoming';
    final statusRaw = json['status']?.toString() ?? 'pending';
    final id = json['id']?.toString() ?? '';
    _FriendRequestDirection direction;
    switch (directionRaw) {
      case 'outgoing':
        direction = _FriendRequestDirection.outgoing;
        break;
      default:
        direction = _FriendRequestDirection.incoming;
        break;
    }
    _FriendRequestStatus status;
    switch (statusRaw) {
      case 'accepted':
        status = _FriendRequestStatus.accepted;
        break;
      case 'declined':
        status = _FriendRequestStatus.declined;
        break;
      case 'cancelled':
      case 'canceled':
        status = _FriendRequestStatus.cancelled;
        break;
      default:
        status = _FriendRequestStatus.pending;
        break;
    }
    return _FriendRequest(
      id: id,
      username: json['username']?.toString() ?? '',
      direction: direction,
      status: status,
      message: json['message']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory _FriendRequest.fromApi(FriendRequest req) {
    _FriendRequestDirection direction;
    switch (req.direction.toLowerCase()) {
      case 'outgoing':
        direction = _FriendRequestDirection.outgoing;
        break;
      default:
        direction = _FriendRequestDirection.incoming;
        break;
    }
    _FriendRequestStatus status;
    switch (req.status.toLowerCase()) {
      case 'accepted':
        status = _FriendRequestStatus.accepted;
        break;
      case 'declined':
        status = _FriendRequestStatus.declined;
        break;
      case 'cancelled':
        status = _FriendRequestStatus.cancelled;
        break;
      default:
        status = _FriendRequestStatus.pending;
        break;
    }
    return _FriendRequest(
      id: req.id,
      username: req.username,
      direction: direction,
      status: status,
      message: req.message,
      createdAt: req.createdAt,
    );
  }
}

class _FriendRank {
  const _FriendRank({
    required this.rank,
    required this.name,
    required this.ovr,
    this.delta = 0,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final double ovr;
  final int delta;
  final bool isMe;
}

class _FriendInfo {
  const _FriendInfo({
    required this.name,
    required this.status,
    required this.ovr,
    this.userId,
    this.displayName,
    this.profileImage,
  });

  /// The username remains the peer key for the existing message/removal APIs.
  final String name;
  final String status;
  final double ovr;
  final String? userId;
  final String? displayName;
  final String? profileImage;
}

class _MessageInfo {
  const _MessageInfo({
    required this.name,
    required this.lastMessage,
    required this.timeAgo,
  });

  final String name;
  final String lastMessage;
  final String timeAgo;
}

class _GroupInfo {
  const _GroupInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.members,
    required this.isPublic,
    this.logoIndex,
    this.lockEnabled = false,
    this.ownerRole = 'student',
    this.inviteCode,
  });

  final String id;
  final String name;
  final String description;
  final int maxMembers;
  final int members;
  final bool isPublic;
  final int? logoIndex;
  final bool lockEnabled;
  final String ownerRole;
  final String? inviteCode;
}
