import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class CatalogEvent {}

class LoadCommerceSettings extends CatalogEvent {}

class SyncCatalogsWithMeta extends CatalogEvent {}

class SelectActiveCatalog extends CatalogEvent {
  final String catalogId;
  SelectActiveCatalog(this.catalogId);
}

class UpdateCommerceSettings extends CatalogEvent {
  final bool? cartEnabled;
  final bool? catalogVisible;
  UpdateCommerceSettings({this.cartEnabled, this.catalogVisible});
}

class LoadProducts extends CatalogEvent {
  final String? catalogId;
  final String? searchQuery;
  LoadProducts({this.catalogId, this.searchQuery});
}

class LoadOrders extends CatalogEvent {
  final String? status;
  final String? contactId;
  LoadOrders({this.status, this.contactId});
}

class SendCatalogMessageEvent extends CatalogEvent {
  final CatalogMessageRequest request;
  SendCatalogMessageEvent(this.request);
}

class SendSingleProductEvent extends CatalogEvent {
  final SingleProductRequest request;
  SendSingleProductEvent(this.request);
}

class SendMultiProductEvent extends CatalogEvent {
  final MultiProductRequest request;
  SendMultiProductEvent(this.request);
}

class SendProductCarouselEvent extends CatalogEvent {
  final ProductCarouselRequest request;
  SendProductCarouselEvent(this.request);
}

class AddProductEvent extends CatalogEvent {
  final CatalogProduct product;
  final String? catalogId;
  AddProductEvent(this.product, {this.catalogId});
}

class SendOrderPaymentLinkEvent extends CatalogEvent {
  final String orderId;
  SendOrderPaymentLinkEvent(this.orderId);
}

class MarkOrderPaidEvent extends CatalogEvent {
  final String orderId;
  final String? paymentId;
  MarkOrderPaidEvent(this.orderId, {this.paymentId});
}

class ClearCatalogStatus extends CatalogEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class CatalogState {}

class CatalogInitial extends CatalogState {}

class CatalogSettingsLoading extends CatalogState {}

class CatalogSettingsLoaded extends CatalogState {
  final CatalogCommerceSettings settings;
  final List<CatalogProduct> products;
  final List<CatalogInfo> catalogs;
  final String? activeCatalogId;
  final List<WhatsAppOrder> orders;
  final bool isLoadingProducts;
  final bool isSyncingCatalogs;
  final bool isLoadingOrders;
  final bool isSending;
  final String? successMessage;
  final String? errorMessage;

  CatalogSettingsLoaded({
    required this.settings,
    this.products = const [],
    this.catalogs = const [],
    this.activeCatalogId,
    this.orders = const [],
    this.isLoadingProducts = false,
    this.isSyncingCatalogs = false,
    this.isLoadingOrders = false,
    this.isSending = false,
    this.successMessage,
    this.errorMessage,
  });

  CatalogInfo? get activeCatalog {
    if (activeCatalogId == null || catalogs.isEmpty) return null;
    try {
      return catalogs.firstWhere((c) => c.catalogId == activeCatalogId);
    } catch (_) {
      return catalogs.isNotEmpty ? catalogs.first : null;
    }
  }

  CatalogSettingsLoaded copyWith({
    CatalogCommerceSettings? settings,
    List<CatalogProduct>? products,
    List<CatalogInfo>? catalogs,
    String? activeCatalogId,
    List<WhatsAppOrder>? orders,
    bool? isLoadingProducts,
    bool? isSyncingCatalogs,
    bool? isLoadingOrders,
    bool? isSending,
    String? successMessage,
    bool clearSuccess = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogSettingsLoaded(
      settings: settings ?? this.settings,
      products: products ?? this.products,
      catalogs: catalogs ?? this.catalogs,
      activeCatalogId: activeCatalogId ?? this.activeCatalogId,
      orders: orders ?? this.orders,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isSyncingCatalogs: isSyncingCatalogs ?? this.isSyncingCatalogs,
      isLoadingOrders: isLoadingOrders ?? this.isLoadingOrders,
      isSending: isSending ?? this.isSending,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CatalogError extends CatalogState {
  final String message;
  CatalogError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final CatalogRepository _repository;

  CatalogBloc(this._repository) : super(CatalogInitial()) {
    on<LoadCommerceSettings>(_onLoadCommerceSettings);
    on<SyncCatalogsWithMeta>(_onSyncCatalogsWithMeta);
    on<SelectActiveCatalog>(_onSelectActiveCatalog);
    on<UpdateCommerceSettings>(_onUpdateCommerceSettings);
    on<LoadProducts>(_onLoadProducts);
    on<LoadOrders>(_onLoadOrders);
    on<SendCatalogMessageEvent>(_onSendCatalogMessage);
    on<SendSingleProductEvent>(_onSendSingleProduct);
    on<SendMultiProductEvent>(_onSendMultiProduct);
    on<SendProductCarouselEvent>(_onSendProductCarousel);
    on<AddProductEvent>(_onAddProduct);
    on<SendOrderPaymentLinkEvent>(_onSendOrderPaymentLink);
    on<MarkOrderPaidEvent>(_onMarkOrderPaid);
    on<ClearCatalogStatus>(_onClearStatus);
  }

  Future<void> _onLoadCommerceSettings(
    LoadCommerceSettings event,
    Emitter<CatalogState> emit,
  ) async {
    emit(CatalogSettingsLoading());
    try {
      final settings = await _repository.getCommerceSettings();
      String? activeId;
      List<CatalogInfo> catalogsList = [];

      try {
        final catResult = await _repository.getCatalogs();
        activeId = catResult.activeCatalogId;
        catalogsList = catResult.catalogs;
      } catch (_) {}

      emit(CatalogSettingsLoaded(
        settings: settings,
        catalogs: catalogsList,
        activeCatalogId: activeId,
      ));

      // Trigger initial product and order loads
      add(LoadProducts(catalogId: activeId));
      add(LoadOrders());
    } catch (e) {
      emit(CatalogError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSyncCatalogsWithMeta(
    SyncCatalogsWithMeta event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded ? state as CatalogSettingsLoaded : null;
    if (current != null) {
      emit(current.copyWith(isSyncingCatalogs: true, clearError: true));
    }
    try {
      final result = await _repository.syncCatalogs();
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          catalogs: result.catalogs,
          activeCatalogId: result.activeCatalogId,
          isSyncingCatalogs: false,
          successMessage: 'Successfully synced ${result.catalogs.length} catalog(s) with Meta!',
        ));
      }
      add(LoadProducts(catalogId: result.activeCatalogId));
    } catch (e) {
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          isSyncingCatalogs: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onSelectActiveCatalog(
    SelectActiveCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded ? state as CatalogSettingsLoaded : null;
    try {
      await _repository.selectCatalog(event.catalogId);
      if (current != null) {
        final updatedCatalogs = current.catalogs.map((c) {
          return CatalogInfo(
            catalogId: c.catalogId,
            name: c.name,
            vertical: c.vertical,
            isDefault: c.catalogId == event.catalogId,
            productCount: c.productCount,
          );
        }).toList();

        emit(current.copyWith(
          catalogs: updatedCatalogs,
          activeCatalogId: event.catalogId,
          successMessage: 'Active catalog switched to ${event.catalogId}',
        ));
      }
      add(LoadProducts(catalogId: event.catalogId));
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onUpdateCommerceSettings(
    UpdateCommerceSettings event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    try {
      await _repository.updateCommerceSettings(
        cartEnabled: event.cartEnabled,
        catalogVisible: event.catalogVisible,
      );
      final newSettings = CatalogCommerceSettings(
        isCartEnabled: event.cartEnabled ??
            (current?.settings.isCartEnabled ?? true),
        isCatalogVisible: event.catalogVisible ??
            (current?.settings.isCatalogVisible ?? false),
        id: current?.settings.id ?? '',
      );
      if (current != null) {
        emit(current.copyWith(
          settings: newSettings,
          successMessage: 'Commerce settings updated',
        ));
      }
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      } else {
        emit(CatalogError(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    if (current != null) {
      emit(current.copyWith(isLoadingProducts: true, clearError: true));
    }
    try {
      final targetCatId = event.catalogId ?? current?.activeCatalogId;
      final products = await _repository.fetchProducts(
        catalogId: targetCatId,
        searchQuery: event.searchQuery,
      );
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          products: products,
          isLoadingProducts: false,
        ));
      }
    } catch (e) {
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          isLoadingProducts: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onLoadOrders(
    LoadOrders event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded ? state as CatalogSettingsLoaded : null;
    if (current != null) {
      emit(current.copyWith(isLoadingOrders: true));
    }
    try {
      final orders = await _repository.getOrders(status: event.status, contactId: event.contactId);
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          orders: orders,
          isLoadingOrders: false,
        ));
      }
    } catch (_) {
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(isLoadingOrders: false));
      }
    }
  }

  Future<void> _onSendOrderPaymentLink(
    SendOrderPaymentLinkEvent event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded ? state as CatalogSettingsLoaded : null;
    if (current != null) {
      emit(current.copyWith(isSending: true, clearError: true));
    }
    try {
      final res = await _repository.sendPaymentLink(event.orderId);
      final paymentUrl = res['paymentLinkUrl']?.toString();
      if (current != null) {
        emit(current.copyWith(
          isSending: false,
          successMessage: paymentUrl != null
              ? 'Payment link generated & sent via WhatsApp!'
              : 'Payment link sent successfully!',
        ));
      }
      add(LoadOrders());
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          isSending: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onMarkOrderPaid(
    MarkOrderPaidEvent event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded ? state as CatalogSettingsLoaded : null;
    try {
      await _repository.markOrderPaid(event.orderId, paymentId: event.paymentId);
      if (current != null) {
        emit(current.copyWith(
          successMessage: 'Order marked as paid!',
        ));
      }
      add(LoadOrders());
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onAddProduct(
    AddProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    try {
      final targetCatId = event.catalogId ?? current?.activeCatalogId;
      final added = await _repository.addProduct(event.product, catalogId: targetCatId);
      if (current != null) {
        final updatedList = [added, ...current.products];
        emit(current.copyWith(
          products: updatedList,
          successMessage: 'Product "${added.name}" added to catalog!',
        ));
      }
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onSendCatalogMessage(
    SendCatalogMessageEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _handleSend(() => _repository.sendCatalogMessage(event.request),
        'Catalog message sent successfully', emit);
  }

  Future<void> _onSendSingleProduct(
    SendSingleProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _handleSend(() => _repository.sendSingleProduct(event.request),
        'Single product message sent successfully', emit);
  }

  Future<void> _onSendMultiProduct(
    SendMultiProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _handleSend(() => _repository.sendMultiProduct(event.request),
        'Multi-product message sent successfully', emit);
  }

  Future<void> _onSendProductCarousel(
    SendProductCarouselEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _handleSend(() => _repository.sendProductCarousel(event.request),
        'Product carousel sent successfully', emit);
  }

  Future<void> _handleSend(
    Future<String> Function() action,
    String successMsg,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    if (current != null) emit(current.copyWith(isSending: true, clearError: true));

    try {
      final messageId = await action();
      if (current != null) {
        emit(current.copyWith(
          isSending: false,
          successMessage: '$successMsg (ID: $messageId)',
        ));
      }
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          isSending: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  void _onClearStatus(ClearCatalogStatus event, Emitter<CatalogState> emit) {
    if (state is CatalogSettingsLoaded) {
      emit((state as CatalogSettingsLoaded).copyWith(
        clearSuccess: true,
        clearError: true,
      ));
    }
  }
}
