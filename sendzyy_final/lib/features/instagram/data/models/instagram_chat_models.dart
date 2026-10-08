import 'package:equatable/equatable.dart';

class InstagramAccountModel extends Equatable {
  final String instagramAccountId;
  final String igUserId;
  final String username;
  final String name;
  final bool connected;

  const InstagramAccountModel({
    required this.instagramAccountId,
    required this.igUserId,
    required this.username,
    required this.name,
    required this.connected,
  });

  factory InstagramAccountModel.fromJson(Map<String, dynamic> json) {
    return InstagramAccountModel(
      instagramAccountId: json['instagramAccountId']?.toString() ?? '',
      igUserId: json['igUserId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      connected: json['connected'] == true,
    );
  }

  @override
  List<Object?> get props => [instagramAccountId, igUserId, username, name, connected];
}

class InstagramConversationModel extends Equatable {
  final String id;
  final String tenantId;
  final String instagramAccountId;
  final String igsid;
  final String name;
  final String username;
  final String profilePic;
  final String lastMessage;
  final DateTime lastMessageAt;
  final DateTime lastCustomerMessageAt;
  final int unreadCount;
  final bool isHumanTakeover;
  final DateTime? humanTakeoverAt;
  final String status;
  final bool isWindowOpen;
  final DateTime? windowExpiresAt;
  final int remainingHours;

  const InstagramConversationModel({
    required this.id,
    required this.tenantId,
    required this.instagramAccountId,
    required this.igsid,
    required this.name,
    required this.username,
    required this.profilePic,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastCustomerMessageAt,
    required this.unreadCount,
    required this.isHumanTakeover,
    this.humanTakeoverAt,
    required this.status,
    required this.isWindowOpen,
    this.windowExpiresAt,
    required this.remainingHours,
  });

  factory InstagramConversationModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return InstagramConversationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      instagramAccountId: json['instagramAccountId']?.toString() ?? '',
      igsid: json['igsid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePic: json['profilePic']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageAt: parseDate(json['lastMessageAt']),
      lastCustomerMessageAt: parseDate(json['lastCustomerMessageAt']),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isHumanTakeover: json['isHumanTakeover'] == true,
      humanTakeoverAt: json['humanTakeoverAt'] != null ? parseDate(json['humanTakeoverAt']) : null,
      status: json['status']?.toString() ?? 'active',
      isWindowOpen: json['isWindowOpen'] == true,
      windowExpiresAt: json['windowExpiresAt'] != null ? parseDate(json['windowExpiresAt']) : null,
      remainingHours: (json['remainingHours'] as num?)?.toInt() ?? 0,
    );
  }

  InstagramConversationModel copyWith({
    String? id,
    String? tenantId,
    String? instagramAccountId,
    String? igsid,
    String? name,
    String? username,
    String? profilePic,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? lastCustomerMessageAt,
    int? unreadCount,
    bool? isHumanTakeover,
    DateTime? humanTakeoverAt,
    String? status,
    bool? isWindowOpen,
    DateTime? windowExpiresAt,
    int? remainingHours,
  }) {
    return InstagramConversationModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      instagramAccountId: instagramAccountId ?? this.instagramAccountId,
      igsid: igsid ?? this.igsid,
      name: name ?? this.name,
      username: username ?? this.username,
      profilePic: profilePic ?? this.profilePic,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastCustomerMessageAt: lastCustomerMessageAt ?? this.lastCustomerMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isHumanTakeover: isHumanTakeover ?? this.isHumanTakeover,
      humanTakeoverAt: humanTakeoverAt ?? this.humanTakeoverAt,
      status: status ?? this.status,
      isWindowOpen: isWindowOpen ?? this.isWindowOpen,
      windowExpiresAt: windowExpiresAt ?? this.windowExpiresAt,
      remainingHours: remainingHours ?? this.remainingHours,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        instagramAccountId,
        igsid,
        name,
        username,
        profilePic,
        lastMessage,
        lastMessageAt,
        unreadCount,
        isHumanTakeover,
        status,
        isWindowOpen,
        remainingHours,
      ];
}

class InstagramQuickReplyItem extends Equatable {
  final String title;
  final String payload;

  const InstagramQuickReplyItem({
    required this.title,
    required this.payload,
  });

  factory InstagramQuickReplyItem.fromJson(Map<String, dynamic> json) {
    return InstagramQuickReplyItem(
      title: json['title']?.toString() ?? '',
      payload: json['payload']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'payload': payload,
      };

  @override
  List<Object?> get props => [title, payload];
}

class InstagramMessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String igsid;
  final bool isMe;
  final String senderType; // 'customer' | 'agent' | 'automation'
  final String text;
  final String messageType; // 'text' | 'image' | 'video' | 'audio' | 'quick_reply' | 'media'
  final String mediaUrl;
  final List<InstagramQuickReplyItem> quickReplies;
  final String mid;
  final String status; // 'sent' | 'delivered' | 'read' | 'failed'
  final DateTime timestamp;

  const InstagramMessageModel({
    required this.id,
    required this.conversationId,
    required this.igsid,
    required this.isMe,
    required this.senderType,
    required this.text,
    required this.messageType,
    required this.mediaUrl,
    required this.quickReplies,
    required this.mid,
    required this.status,
    required this.timestamp,
  });

  factory InstagramMessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    final rawQuickReplies = json['quickReplies'];
    List<InstagramQuickReplyItem> qrs = [];
    if (rawQuickReplies is List) {
      qrs = rawQuickReplies
          .map((e) => e is Map<String, dynamic>
              ? InstagramQuickReplyItem.fromJson(e)
              : InstagramQuickReplyItem(title: e.toString(), payload: e.toString()))
          .toList();
    }

    return InstagramMessageModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      igsid: json['igsid']?.toString() ?? '',
      isMe: json['isMe'] == true,
      senderType: json['senderType']?.toString() ?? 'customer',
      text: json['text']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      quickReplies: qrs,
      mid: json['mid']?.toString() ?? '',
      status: json['status']?.toString() ?? 'sent',
      timestamp: parseDate(json['timestamp']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        igsid,
        isMe,
        senderType,
        text,
        messageType,
        mediaUrl,
        quickReplies,
        mid,
        status,
        timestamp,
      ];
}
