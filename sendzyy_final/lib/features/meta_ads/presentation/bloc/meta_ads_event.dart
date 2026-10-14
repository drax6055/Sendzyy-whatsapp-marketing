import 'package:equatable/equatable.dart';

abstract class MetaAdsEvent extends Equatable {
  const MetaAdsEvent();

  @override
  List<Object?> get props => [];
}

class LoadMetaAccountStatusEvent extends MetaAdsEvent {
  const LoadMetaAccountStatusEvent();
}

class ConnectMetaAccountEvent extends MetaAdsEvent {
  final String? userAccessToken;
  final String? code;
  final bool useTenantOnboarding;
  final String? adAccountId;
  final String? adAccountName;
  final String? pageId;
  final String? pageName;
  final String? instagramActorId;
  final String? businessId;

  const ConnectMetaAccountEvent({
    this.userAccessToken,
    this.code,
    this.useTenantOnboarding = false,
    this.adAccountId,
    this.adAccountName,
    this.pageId,
    this.pageName,
    this.instagramActorId,
    this.businessId,
  });

  @override
  List<Object?> get props => [userAccessToken, code, useTenantOnboarding, adAccountId, pageId];
}

class SelectMetaAssetsEvent extends MetaAdsEvent {
  final String adAccountId;
  final String? adAccountName;
  final String pageId;
  final String? pageName;

  const SelectMetaAssetsEvent({
    required this.adAccountId,
    this.adAccountName,
    required this.pageId,
    this.pageName,
  });

  @override
  List<Object?> get props => [adAccountId, pageId];
}

class DisconnectMetaAccountEvent extends MetaAdsEvent {
  const DisconnectMetaAccountEvent();
}

class LoadMetaAdAccountsAndPagesEvent extends MetaAdsEvent {
  const LoadMetaAdAccountsAndPagesEvent();
}

class LoadMetaCampaignsEvent extends MetaAdsEvent {
  final String? status;
  final String? search;

  const LoadMetaCampaignsEvent({this.status, this.search});

  @override
  List<Object?> get props => [status, search];
}

class CreateMetaCampaignEvent extends MetaAdsEvent {
  final Map<String, dynamic> campaignData;

  const CreateMetaCampaignEvent(this.campaignData);

  @override
  List<Object?> get props => [campaignData];
}

class UpdateMetaCampaignStatusEvent extends MetaAdsEvent {
  final String campaignId;
  final String status;

  const UpdateMetaCampaignStatusEvent(this.campaignId, this.status);

  @override
  List<Object?> get props => [campaignId, status];
}

class DeleteMetaCampaignEvent extends MetaAdsEvent {
  final String campaignId;

  const DeleteMetaCampaignEvent(this.campaignId);

  @override
  List<Object?> get props => [campaignId];
}

class SyncCampaignStatsEvent extends MetaAdsEvent {
  final String campaignId;

  const SyncCampaignStatsEvent(this.campaignId);

  @override
  List<Object?> get props => [campaignId];
}

class LoadMetaLeadsEvent extends MetaAdsEvent {
  final String? campaignId;

  const LoadMetaLeadsEvent({this.campaignId});

  @override
  List<Object?> get props => [campaignId];
}
