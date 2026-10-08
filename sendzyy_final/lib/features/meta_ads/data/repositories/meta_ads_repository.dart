import 'package:dio/dio.dart';
import '../models/meta_account_model.dart';
import '../models/meta_campaign_model.dart';
import '../models/meta_lead_model.dart';

class MetaAdsRepository {
  final Dio _dio;

  MetaAdsRepository(this._dio);

  String? _extractError(DioException e) {
    if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      return map['error']?.toString() ?? map['message']?.toString();
    }
    return e.message;
  }

  // ── Account Connection ──────────────────────────────────────────────────────

  Future<MetaAccountStatus> getAccountStatus() async {
    try {
      final response = await _dio.get('/api/meta/auth/status');
      if (response.statusCode == 200 && response.data is Map) {
        return MetaAccountStatus.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
      return MetaAccountStatus(connected: false, status: 'disconnected');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to check account status');
    }
  }

  Future<void> connectAccount({
    required String userAccessToken,
    String? adAccountId,
    String? adAccountName,
    String? pageId,
    String? pageName,
    String? instagramActorId,
    String? businessId,
  }) async {
    try {
      await _dio.post('/api/meta/auth/connect', data: {
        'userAccessToken': userAccessToken,
        if (adAccountId != null) 'adAccountId': adAccountId,
        if (adAccountName != null) 'adAccountName': adAccountName,
        if (pageId != null) 'pageId': pageId,
        if (pageName != null) 'pageName': pageName,
        if (instagramActorId != null) 'instagramActorId': instagramActorId,
        if (businessId != null) 'businessId': businessId,
      });
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to connect Meta account');
    }
  }

  Future<void> disconnectAccount() async {
    try {
      await _dio.post('/api/meta/auth/disconnect');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to disconnect account');
    }
  }

  Future<List<MetaAdAccountItem>> getAdAccounts() async {
    try {
      final response = await _dio.get('/api/meta/ad-accounts');
      if (response.statusCode == 200 && response.data is Map) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => MetaAdAccountItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        return list;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load ad accounts');
    }
  }

  Future<List<MetaPageItem>> getPages() async {
    try {
      final response = await _dio.get('/api/meta/pages');
      if (response.statusCode == 200 && response.data is Map) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => MetaPageItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        return list;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load pages');
    }
  }

  // ── Campaigns ───────────────────────────────────────────────────────────────

  Future<List<MetaCampaignModel>> getCampaigns({String? status, String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get('/api/meta/campaigns', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data is Map) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => MetaCampaignModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        return list;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load campaigns');
    }
  }

  Future<MetaCampaignModel> getCampaignById(String id) async {
    try {
      final response = await _dio.get('/api/meta/campaigns/$id');
      if (response.statusCode == 200 && response.data is Map) {
        return MetaCampaignModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      }
      throw Exception('Campaign not found');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to fetch campaign details');
    }
  }

  Future<MetaCampaignModel> createCampaign(Map<String, dynamic> campaignData) async {
    try {
      final response = await _dio.post('/api/meta/campaigns', data: campaignData);
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data is Map) {
        return MetaCampaignModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      }
      throw Exception('Failed to create campaign');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to publish campaign to Meta');
    }
  }

  Future<MetaCampaignModel> updateCampaignStatus(String id, String status) async {
    try {
      final response = await _dio.patch('/api/meta/campaigns/$id/status', data: {'status': status});
      if (response.statusCode == 200 && response.data is Map) {
        return MetaCampaignModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      }
      throw Exception('Failed to update status');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to update campaign status');
    }
  }

  Future<void> deleteCampaign(String id) async {
    try {
      await _dio.delete('/api/meta/campaigns/$id');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to delete campaign');
    }
  }

  Future<CampaignInsights> syncCampaignStats(String id) async {
    try {
      final response = await _dio.get('/api/meta/campaigns/$id/stats');
      if (response.statusCode == 200 && response.data is Map) {
        return CampaignInsights.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      }
      return CampaignInsights.empty();
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to sync insights');
    }
  }

  Future<({String hash, String url})> uploadCreativeImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/api/meta/creative/upload', data: formData);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'] as Map;
        return (
          hash: data['hash']?.toString() ?? '',
          url: data['url']?.toString() ?? '',
        );
      }
      throw Exception('Upload failed');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to upload creative image');
    }
  }

  // ── Leads ───────────────────────────────────────────────────────────────────

  Future<List<MetaLeadModel>> getMetaLeads({String? campaignId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (campaignId != null && campaignId.isNotEmpty) {
        queryParams['campaignId'] = campaignId;
      }
      final response = await _dio.get('/api/meta/leads', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data is Map) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => MetaLeadModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        return list;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load leads');
    }
  }
}
