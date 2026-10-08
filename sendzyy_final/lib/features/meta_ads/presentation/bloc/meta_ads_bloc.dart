import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/meta_account_model.dart';
import '../../data/models/meta_campaign_model.dart';
import '../../data/repositories/meta_ads_repository.dart';
import 'meta_ads_event.dart';
import 'meta_ads_state.dart';

class MetaAdsBloc extends Bloc<MetaAdsEvent, MetaAdsState> {
  final MetaAdsRepository _repository;

  MetaAdsBloc(this._repository) : super(const MetaAdsState()) {
    on<LoadMetaAccountStatusEvent>(_onLoadAccountStatus);
    on<ConnectMetaAccountEvent>(_onConnectAccount);
    on<SelectMetaAssetsEvent>(_onSelectAssets);
    on<DisconnectMetaAccountEvent>(_onDisconnectAccount);
    on<LoadMetaAdAccountsAndPagesEvent>(_onLoadAdAccountsAndPages);
    on<LoadMetaCampaignsEvent>(_onLoadCampaigns);
    on<CreateMetaCampaignEvent>(_onCreateCampaign);
    on<UpdateMetaCampaignStatusEvent>(_onUpdateCampaignStatus);
    on<DeleteMetaCampaignEvent>(_onDeleteCampaign);
    on<SyncCampaignStatsEvent>(_onSyncCampaignStats);
    on<LoadMetaLeadsEvent>(_onLoadLeads);
  }

  Future<void> _onLoadAccountStatus(
    LoadMetaAccountStatusEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final status = await _repository.getAccountStatus();
      emit(state.copyWith(isLoading: false, accountStatus: status));

      if (status.connected) {
        add(const LoadMetaAdAccountsAndPagesEvent());
        add(const LoadMetaCampaignsEvent());
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onConnectAccount(
    ConnectMetaAccountEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final res = await _repository.connectAccount(
        userAccessToken: event.userAccessToken,
        code: event.code,
        useTenantOnboarding: event.useTenantOnboarding,
        adAccountId: event.adAccountId,
        adAccountName: event.adAccountName,
        pageId: event.pageId,
        pageName: event.pageName,
        instagramActorId: event.instagramActorId,
        businessId: event.businessId,
      );

      List<MetaAdAccountItem> adAccounts = List.from(state.adAccounts);
      List<MetaPageItem> pages = List.from(state.pages);
      if (res['adAccounts'] is List) {
        adAccounts = (res['adAccounts'] as List)
            .map((e) => MetaAdAccountItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (res['pages'] is List) {
        pages = (res['pages'] as List)
            .map((e) => MetaPageItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      emit(state.copyWith(
        isLoading: false,
        adAccounts: adAccounts,
        pages: pages,
        successMessage: 'Facebook Business account connected successfully!',
      ));
      add(const LoadMetaAccountStatusEvent());
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onSelectAssets(
    SelectMetaAssetsEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.selectAssets(
        adAccountId: event.adAccountId,
        adAccountName: event.adAccountName,
        pageId: event.pageId,
        pageName: event.pageName,
      );
      emit(state.copyWith(
        isLoading: false,
        successMessage: 'Active Ad Account & Page updated successfully!',
      ));
      add(const LoadMetaAccountStatusEvent());
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDisconnectAccount(
    DisconnectMetaAccountEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.disconnectAccount();
      emit(state.copyWith(
        isLoading: false,
        successMessage: 'Account disconnected',
      ));
      add(const LoadMetaAccountStatusEvent());
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadAdAccountsAndPages(
    LoadMetaAdAccountsAndPagesEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    try {
      final accountsFuture = _repository.getAdAccounts();
      final pagesFuture = _repository.getPages();

      final results = await Future.wait([accountsFuture, pagesFuture]);
      emit(state.copyWith(
        adAccounts: results[0] as dynamic,
        pages: results[1] as dynamic,
      ));
    } catch (e) {
      // Non-fatal, accounts can be refreshed
    }
  }

  Future<void> _onLoadCampaigns(
    LoadMetaCampaignsEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final campaigns = await _repository.getCampaigns(
        status: event.status,
        search: event.search,
      );
      emit(state.copyWith(isLoading: false, campaigns: campaigns));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateCampaign(
    CreateMetaCampaignEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isPublishing: true, clearError: true));
    try {
      final created = await _repository.createCampaign(event.campaignData);
      final updatedList = [created, ...state.campaigns];
      emit(state.copyWith(
        isPublishing: false,
        campaigns: updatedList,
        successMessage: 'Campaign "${created.name}" published successfully to Meta!',
      ));
    } catch (e) {
      emit(state.copyWith(isPublishing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateCampaignStatus(
    UpdateMetaCampaignStatusEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    try {
      final updated = await _repository.updateCampaignStatus(event.campaignId, event.status);
      final updatedList = state.campaigns.map((c) => c.id == updated.id ? updated : c).toList();
      emit(state.copyWith(
        campaigns: updatedList,
        successMessage: 'Campaign ${event.status == 'ACTIVE' ? 'resumed' : 'paused'}',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteCampaign(
    DeleteMetaCampaignEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    try {
      await _repository.deleteCampaign(event.campaignId);
      final updatedList = state.campaigns.where((c) => c.id != event.campaignId).toList();
      emit(state.copyWith(
        campaigns: updatedList,
        successMessage: 'Campaign deleted',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSyncCampaignStats(
    SyncCampaignStatsEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true));
    try {
      final newInsights = await _repository.syncCampaignStats(event.campaignId);
      final updatedList = state.campaigns.map((c) {
        if (c.id == event.campaignId) {
          return MetaCampaignModel(
            id: c.id,
            tenantId: c.tenantId,
            metaCampaignId: c.metaCampaignId,
            metaAdSetId: c.metaAdSetId,
            metaCreativeId: c.metaCreativeId,
            metaAdId: c.metaAdId,
            metaLeadFormId: c.metaLeadFormId,
            name: c.name,
            objective: c.objective,
            specialAdCategories: c.specialAdCategories,
            specialAdCategoryCountries: c.specialAdCategoryCountries,
            advantageCampaignBudget: c.advantageCampaignBudget,
            campaignBudget: c.campaignBudget,
            campaignBidStrategy: c.campaignBidStrategy,
            isAbTest: c.isAbTest,
            adSetName: c.adSetName,
            optimizationGoal: c.optimizationGoal,
            destinationType: c.destinationType,
            billingEvent: c.billingEvent,
            adSetBudget: c.adSetBudget,
            bidStrategy: c.bidStrategy,
            bidAmount: c.bidAmount,
            schedule: c.schedule,
            targeting: c.targeting,
            placements: c.placements,
            adName: c.adName,
            pageId: c.pageId,
            instagramAccountId: c.instagramAccountId,
            format: c.format,
            creative: c.creative,
            leadForm: c.leadForm,
            status: c.status,
            insights: newInsights,
            createdAt: c.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return c;
      }).toList();
      emit(state.copyWith(isSyncing: false, campaigns: updatedList));
    } catch (e) {
      emit(state.copyWith(isSyncing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadLeads(
    LoadMetaLeadsEvent event,
    Emitter<MetaAdsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final leads = await _repository.getMetaLeads(campaignId: event.campaignId);
      emit(state.copyWith(isLoading: false, leads: leads));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
