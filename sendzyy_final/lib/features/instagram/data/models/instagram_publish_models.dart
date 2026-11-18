import 'dart:typed_data';

class InstagramUserTag {
  final String username;
  final double x;
  final double y;

  InstagramUserTag({
    required this.username,
    this.x = 0.5,
    this.y = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'username': username.trim().replaceAll('@', ''),
        'x': x,
        'y': y,
      };

  factory InstagramUserTag.fromJson(Map<String, dynamic> json) =>
      InstagramUserTag(
        username: json['username']?.toString() ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
      );
}

class InstagramPostModel {
  final String id;
  final String tenantId;
  final String igUserId;
  final String mediaType; // 'IMAGE' | 'CAROUSEL' | 'REEL'
  final String aspectRatio; // '4:5' | '1:1' | '1.91:1' | '9:16'
  final List<String> mediaUrls;
  final String caption;
  final List<String> hashtags;
  final List<InstagramUserTag> userTags;
  final String location;
  final String locationId;
  final String status; // 'scheduled' | 'publishing' | 'published' | 'failed'
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String creationId;
  final String igMediaId;
  final String errorMessage;
  final int retryCount;
  final DateTime createdAt;

  InstagramPostModel({
    required this.id,
    required this.tenantId,
    required this.igUserId,
    required this.mediaType,
    required this.aspectRatio,
    required this.mediaUrls,
    required this.caption,
    required this.hashtags,
    required this.userTags,
    required this.location,
    required this.locationId,
    required this.status,
    this.scheduledAt,
    this.publishedAt,
    required this.creationId,
    required this.igMediaId,
    required this.errorMessage,
    required this.retryCount,
    required this.createdAt,
  });

  factory InstagramPostModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['mediaUrls'] as List? ?? [];
    final rawTags = json['hashtags'] as List? ?? [];
    final rawUserTags = json['userTags'] as List? ?? [];

    return InstagramPostModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      igUserId: json['igUserId']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'IMAGE',
      aspectRatio: json['aspectRatio']?.toString() ?? '1:1',
      mediaUrls: rawMedia.map((e) => e.toString()).toList(),
      caption: json['caption']?.toString() ?? '',
      hashtags: rawTags.map((e) => e.toString()).toList(),
      userTags: rawUserTags.map((e) {
        if (e is Map<String, dynamic>) {
          return InstagramUserTag.fromJson(e);
        } else if (e is Map) {
          return InstagramUserTag.fromJson(Map<String, dynamic>.from(e));
        }
        return InstagramUserTag(username: e.toString());
      }).toList(),
      location: json['location']?.toString() ?? '',
      locationId: json['locationId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'scheduled',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())?.toLocal()
          : null,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())?.toLocal()
          : null,
      creationId: json['creationId']?.toString() ?? '',
      igMediaId: json['igMediaId']?.toString() ?? '',
      errorMessage: json['errorMessage']?.toString() ?? '',
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaType': mediaType,
        'aspectRatio': aspectRatio,
        'mediaUrls': mediaUrls,
        'caption': caption,
        'hashtags': hashtags,
        'userTags': userTags.map((e) => e.toJson()).toList(),
        'location': location,
        'locationId': locationId,
        'status': status,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
      };
}

class PickedMediaFile {
  final String name;
  final Uint8List bytes;
  final int size;
  final String mimeType;
  final bool isVideo;

  PickedMediaFile({
    required this.name,
    required this.bytes,
    required this.size,
    required this.mimeType,
    required this.isVideo,
  });
}

