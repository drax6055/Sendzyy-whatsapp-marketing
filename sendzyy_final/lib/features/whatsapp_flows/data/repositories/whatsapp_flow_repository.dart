import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';

class WhatsAppFlowRepository {
  final Dio _dio;

  WhatsAppFlowRepository(this._dio);

  Future<List<WhatsAppFlowModel>> getFlows({bool sync = false}) async {
    try {
      final response = await _dio.get(
        '/api/flows',
        queryParameters: {'sync': sync ? 'true' : 'false'},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['flows'] ?? [];
        return list.map((json) => WhatsAppFlowModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] getFlows error: $e');
      rethrow;
    }
  }

  Future<WhatsAppFlowModel> createFlow({
    required String name,
    List<String> categories = const ['LEAD_GENERATION'],
    required List<FlowFormField> fields,
    String ctaText = 'Open Form',
    String headerText = '',
    String bodyText = '',
    String footerText = 'Powered by Sendzyy',
    Map<String, dynamic>? customFlowJson,
  }) async {
    try {
      final response = await _dio.post(
        '/api/flows',
        data: {
          'name': name,
          'categories': categories,
          'fieldsConfig': fields.map((f) => f.toJson()).toList(),
          if (customFlowJson != null && customFlowJson.isNotEmpty)
            'flowJson': customFlowJson,
          'ctaText': ctaText,
          'headerText': headerText,
          'bodyText': bodyText,
          'footerText': footerText,
          'autoPublish': true,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return WhatsAppFlowModel.fromJson(response.data['flow']);
      }
      throw Exception(response.data['error'] ?? 'Failed to create flow');
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] createFlow error: $e');
      if (e is DioException) {
        final err = e.response?.data?['error'] ?? e.message;
        throw Exception(err);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendFlow({
    required String to,
    required String flowId,
    String? headerText,
    String? bodyText,
    String? footerText,
    String? ctaText,
  }) async {
    try {
      final response = await _dio.post(
        '/api/flows/send',
        data: {
          'to': to,
          'flowId': flowId,
          if (headerText != null && headerText.isNotEmpty) 'headerText': headerText,
          if (bodyText != null && bodyText.isNotEmpty) 'bodyText': bodyText,
          if (footerText != null && footerText.isNotEmpty) 'footerText': footerText,
          if (ctaText != null && ctaText.isNotEmpty) 'ctaText': ctaText,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data;
      }
      throw Exception(response.data['error'] ?? 'Failed to send flow');
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] sendFlow error: $e');
      if (e is DioException) {
        final err = e.response?.data?['error'] ?? e.message;
        throw Exception(err);
      }
      rethrow;
    }
  }

  Future<List<FlowSubmissionModel>> getFlowResponses({String flowId = 'all'}) async {
    try {
      final response = await _dio.get('/api/flows/$flowId/responses');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> list = response.data['responses'] ?? [];
        return list.map((json) => FlowSubmissionModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] getFlowResponses error: $e');
      return [];
    }
  }

  Future<bool> publishFlow(String flowId) async {
    try {
      final response = await _dio.post('/api/flows/$flowId/publish');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] publishFlow error: $e');
      if (e is DioException) {
        final err = e.response?.data?['error'] ?? e.message;
        throw Exception(err);
      }
      rethrow;
    }
  }

  Future<bool> deleteFlow(String flowId) async {
    try {
      final response = await _dio.delete('/api/flows/$flowId');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint('[WhatsAppFlowRepository] deleteFlow error: $e');
      if (e is DioException) {
        final err = e.response?.data?['error'] ?? e.message;
        throw Exception(err);
      }
      rethrow;
    }
  }
}
