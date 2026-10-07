import 'package:dio/dio.dart';
import '../models/instagram_chat_models.dart';

class InstagramChatRepository {
  final Dio _dio;

  InstagramChatRepository(this._dio);

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

  /// Fetch connected Instagram accounts for multi-account selection
  Future<List<InstagramAccountModel>> getAccounts() async {
    try {
      final response = await _dio.get('/api/instagram/accounts');
      if (response.statusCode == 200) {
        final List<dynamic> accounts = response.data['accounts'] ?? [];
        return accounts.map((e) => InstagramAccountModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch Instagram accounts'));
    }
  }

  /// Fetch conversations list with optional search, accountId, and status filters
  Future<List<InstagramConversationModel>> getConversations({
    String? search,
    String? accountId,
    String? status,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'skip': skip,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['accountId'] = accountId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _dio.get('/api/instagram/conversations', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['conversations'] ?? [];
        return list.map((e) => InstagramConversationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch conversations'));
    }
  }

  /// Get single conversation details
  Future<InstagramConversationModel> getConversation(String id) async {
    try {
      final response = await _dio.get('/api/instagram/conversations/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return InstagramConversationModel.fromJson(response.data['conversation'] as Map<String, dynamic>);
      }
      throw Exception('Conversation not found');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch conversation details'));
    }
  }

  /// Get message history for conversation
  Future<List<InstagramMessageModel>> getMessages(String conversationId, {int limit = 100}) async {
    try {
      final response = await _dio.get(
        '/api/instagram/conversations/$conversationId/messages',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['messages'] ?? [];
        return list.map((e) => InstagramMessageModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to load messages'));
    }
  }

  /// Send a reply message directly to customer's Instagram DM via Meta Graph API
  Future<InstagramMessageModel> sendMessage(
    String conversationId,
    String text, {
    List<String>? quickReplies,
  }) async {
    try {
      final payload = <String, dynamic>{
        'text': text,
      };
      if (quickReplies != null && quickReplies.isNotEmpty) {
        payload['quickReplies'] = quickReplies;
      }

      final response = await _dio.post(
        '/api/instagram/conversations/$conversationId/messages',
        data: payload,
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        return InstagramMessageModel.fromJson(response.data['message'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error'] ?? 'Failed to send message');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to send Instagram message'));
    }
  }

  /// Toggle Human-Agent Takeover for a conversation
  Future<InstagramConversationModel> toggleTakeover(String conversationId, bool isHumanTakeover) async {
    try {
      final response = await _dio.patch(
        '/api/instagram/conversations/$conversationId/takeover',
        data: {'isHumanTakeover': isHumanTakeover},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return InstagramConversationModel.fromJson(response.data['conversation'] as Map<String, dynamic>);
      }
      throw Exception('Failed to update human takeover status');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to update takeover status'));
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead(String conversationId) async {
    try {
      await _dio.patch('/api/instagram/conversations/$conversationId/read');
    } catch (_) {
      // Ignored for UI responsiveness
    }
  }
}
