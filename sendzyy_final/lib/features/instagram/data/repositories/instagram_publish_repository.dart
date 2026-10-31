import 'package:dio/dio.dart';
import '../models/instagram_publish_models.dart';

class InstagramPublishRepository {
  final Dio _dio;

  InstagramPublishRepository(this._dio);

  String _parseError(dynamic e, String defaultMessage) {
    if (e is DioException) {
      final resData = e.response?.data;
      if (resData is Map && resData['error'] != null) {
        return resData['error'].toString();
      }
      return e.message ?? defaultMessage;
    }
    return e.toString();
  }

  /// Get connected Instagram account profile status
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/api/instagram/profile');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {};
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch Instagram profile'));
    }
  }

  /// Upload media files to backend/S3
  Future<List<String>> uploadMediaFiles(List<PickedMediaFile> files) async {
    try {
      final formData = FormData();

      for (final file in files) {
        formData.files.add(
          MapEntry(
            'media',
            MultipartFile.fromBytes(
              file.bytes,
              filename: file.name,
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/api/instagram/publish/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> rawFiles = response.data['files'] ?? [];
        return rawFiles.map((f) => f['url']?.toString() ?? '').where((u) => u.isNotEmpty).toList();
      } else {
        throw Exception(response.data['error'] ?? 'Upload failed');
      }
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to upload media files'));
    }
  }

  /// Create and Publish or Schedule an Instagram post
  Future<InstagramPostModel> createPost({
    required String mediaType,
    required String aspectRatio,
    required List<String> mediaUrls,
    String caption = '',
    List<String> hashtags = const [],
    List<InstagramUserTag> userTags = const [],
    String location = '',
    bool isScheduled = false,
    DateTime? scheduledAt,
  }) async {
    try {
      final payload = {
        'mediaType': mediaType,
        'aspectRatio': aspectRatio,
        'mediaUrls': mediaUrls,
        'caption': caption,
        'hashtags': hashtags,
        'userTags': userTags.map((t) => t.toJson()).toList(),
        'location': location,
        'isScheduled': isScheduled,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
      };

      final response = await _dio.post('/api/instagram/publish', data: payload);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return InstagramPostModel.fromJson(response.data['post'] as Map<String, dynamic>);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to create post');
      }
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to publish/schedule content'));
    }
  }

  /// Fetch posts for calendar month/year
  Future<List<InstagramPostModel>> getPosts({required int year, required int month}) async {
    try {
      final response = await _dio.get(
        '/api/instagram/publish/posts',
        queryParameters: {'year': year, 'month': month},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['posts'] ?? [];
        return list.map((e) => InstagramPostModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch Instagram posts'));
    }
  }

  /// Delete or Cancel a scheduled post
  Future<bool> deletePost(String postId) async {
    try {
      final response = await _dio.delete('/api/instagram/publish/posts/$postId');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to cancel post'));
    }
  }

  /// Retry publishing a failed post
  Future<InstagramPostModel> retryPost(String postId) async {
    try {
      final response = await _dio.post('/api/instagram/publish/posts/$postId/retry');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return InstagramPostModel.fromJson(response.data['post'] as Map<String, dynamic>);
      } else {
        throw Exception(response.data['error'] ?? 'Retry failed');
      }
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to retry post'));
    }
  }
}

