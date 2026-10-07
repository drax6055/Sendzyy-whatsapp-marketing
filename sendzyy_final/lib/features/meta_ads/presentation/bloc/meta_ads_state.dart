import 'package:equatable/equatable.dart';
import '../../data/models/meta_account_model.dart';
import '../../data/models/meta_campaign_model.dart';
import '../../data/models/meta_lead_model.dart';

class MetaAdsState extends Equatable {
  final bool isLoading;
  final bool isPublishing;
  final bool isSyncing;
  final MetaAccountStatus? accountStatus;
  final List<MetaAdAccountItem> adAccounts;
  final List<MetaPageItem> pages;
  final List<MetaCampaignModel> campaigns;
  final List<MetaLeadModel> leads;
  final String? errorMessage;
  final String? successMessage;

  const MetaAdsState({
    this.isLoading = false,
    this.isPublishing = false,
    this.isSyncing = false,
    this.accountStatus,
    this.adAccounts = const [],
    this.pages = const [],
    this.campaigns = const [],
    this.leads = const [],
    this.errorMessage,
    this.successMessage,
  });

  MetaAdsState copyWith({
    bool? isLoading,
    bool? isPublishing,
    bool? isSyncing,
    MetaAccountStatus? accountStatus,
    List<MetaAdAccountItem>? adAccounts,
    List<MetaPageItem>? pages,
    List<MetaCampaignModel>? campaigns,
    List<MetaLeadModel>? leads,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return MetaAdsState(
      isLoading: isLoading ?? this.isLoading,
      isPublishing: isPublishing ?? this.isPublishing,
      isSyncing: isSyncing ?? this.isSyncing,
      accountStatus: accountStatus ?? this.accountStatus,
      adAccounts: adAccounts ?? this.adAccounts,
      pages: pages ?? this.pages,
      campaigns: campaigns ?? this.campaigns,
      leads: leads ?? this.leads,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  // Helper KPI getters across all campaigns
  double get totalSpend => campaigns.fold(0.0, (sum, c) => sum + c.insights.spend);
  int get totalReach => campaigns.fold(0, (sum, c) => sum + c.insights.reach);
  int get totalImpressions => campaigns.fold(0, (sum, c) => sum + c.insights.impressions);
  int get totalLeads => campaigns.fold(0, (sum, c) => sum + c.insights.leadsCount);
  double get averageCpl => totalLeads > 0 ? (totalSpend / totalLeads) : 0.0;

  @override
  List<Object?> get props => [
        isLoading,
        isPublishing,
        isSyncing,
        accountStatus,
        adAccounts,
        pages,
        campaigns,
        leads,
        errorMessage,
        successMessage,
      ];
}
