import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';

class CatalogRepository {
  final Dio _dio;

  CatalogRepository(this._dio);

  // ── Multi-Catalog Management ────────────────────────────────────────────────

  /// Fetches all discovered / connected Meta catalogs for the active tenant
  Future<({String? activeCatalogId, List<CatalogInfo> catalogs})> getCatalogs() async {
    try {
      final response = await _dio.get('/api/catalog/catalogs');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final list = (data['catalogs'] as List<dynamic>?)
                ?.map((c) => CatalogInfo.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList() ??
            [];
        return (activeCatalogId: data['catalogId']?.toString(), catalogs: list);
      }
      return (activeCatalogId: null, catalogs: <CatalogInfo>[]);
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load catalogs');
    }
  }

  /// Triggers on-demand discovery & sync of catalogs from Meta Business Manager
  Future<({String? activeCatalogId, List<CatalogInfo> catalogs})> syncCatalogs() async {
    try {
      final response = await _dio.post('/api/catalog/sync');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final list = (data['catalogs'] as List<dynamic>?)
                ?.map((c) => CatalogInfo.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList() ??
            [];
        return (activeCatalogId: data['catalogId']?.toString(), catalogs: list);
      }
      return (activeCatalogId: null, catalogs: <CatalogInfo>[]);
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to sync catalogs with Meta');
    }
  }

  /// Selects the default/active catalog for sending products and browsing
  Future<void> selectCatalog(String catalogId) async {
    try {
      await _dio.post('/api/catalog/catalogs/select', data: {'catalogId': catalogId});
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to switch catalog');
    }
  }

  // ── Commerce Settings ───────────────────────────────────────────────────────

  /// Fetches the commerce settings (cart & catalog visibility) for the
  /// business phone number configured on this tenant.
  Future<CatalogCommerceSettings> getCommerceSettings() async {
    try {
      final response = await _dio.get('/api/catalog/commerce-settings');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List && data.isNotEmpty) {
          return CatalogCommerceSettings.fromJson(
              Map<String, dynamic>.from(data.first as Map));
        } else if (data is Map) {
          return CatalogCommerceSettings.fromJson(
              Map<String, dynamic>.from(data));
        }
      }
      return CatalogCommerceSettings.defaultSettings();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.type == DioExceptionType.connectionTimeout) {
        return CatalogCommerceSettings.defaultSettings();
      }
      throw Exception(_extractError(e) ?? 'Failed to load commerce settings');
    }
  }

  /// Enables or disables cart / catalog visibility for the phone number.
  Future<void> updateCommerceSettings({
    bool? cartEnabled,
    bool? catalogVisible,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (cartEnabled != null) params['is_cart_enabled'] = cartEnabled;
      if (catalogVisible != null) params['is_catalog_visible'] = catalogVisible;

      await _dio.post('/api/catalog/commerce-settings', data: params);
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to update commerce settings');
    }
  }

  static final List<CatalogProduct> _customAddedProducts = [];

  // ── Products ─────────────────────────────────────────────────────────────────

  /// Fetches products from the Meta catalog connected to this WABA.
  /// If no catalog is connected or backend is empty, returns sample test products + custom added items.
  Future<List<CatalogProduct>> fetchProducts({
    String? catalogId,
    String? searchQuery,
    int limit = 50,
    String? after,
  }) async {
    List<CatalogProduct> products = [];
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (catalogId != null && catalogId.isNotEmpty) 'catalogId': catalogId,
        if (searchQuery != null && searchQuery.isNotEmpty) 'q': searchQuery,
        if (after != null) 'after': after,
      };
      final response = await _dio.get(
        '/api/catalog/products',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> items = [];

        if (data is List) {
          items = data;
        } else if (data is Map) {
          items = (data['data'] ?? data['products'] ?? []) as List<dynamic>;
        }

        products = items
            .map((json) =>
                CatalogProduct.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback to test catalog products when backend API is not yet wired
    }

    products = [..._customAddedProducts, ...products];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.retailerId.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }

    return products;
  }

  /// Adds a new product to the catalog.
  Future<CatalogProduct> addProduct(CatalogProduct product, {String? catalogId}) async {
    try {
      final response = await _dio.post(
        '/api/catalog/products',
        data: {
          if (catalogId != null && catalogId.isNotEmpty) 'catalogId': catalogId,
          'retailer_id': product.retailerId,
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'currency': product.currency,
          'image_url': product.imageUrl,
          'availability': product.isAvailable ? 'in stock' : 'out of stock',
          'brand': product.brand,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          final created = CatalogProduct.fromJson(
              Map<String, dynamic>.from(response.data as Map));
          _customAddedProducts.insert(0, created);
          return created;
        }
      }
    } on DioException catch (e) {
      final err = _extractError(e);
      if (err != null && err.isNotEmpty) throw Exception(err);
    } catch (_) {
      // Optimistic update fallback
    }
    _customAddedProducts.insert(0, product);
    return product;
  }

  // ── Customer Catalog Orders ─────────────────────────────────────────────────

  /// Fetches orders placed by WhatsApp customers from the catalog
  Future<List<WhatsAppOrder>> getOrders({String? status, String? contactId}) async {
    try {
      final response = await _dio.get('/api/catalog/orders', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (contactId != null && contactId.isNotEmpty) 'contactId': contactId,
      });
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final items = (data['orders'] as List<dynamic>?)
                ?.map((o) => WhatsAppOrder.fromJson(Map<String, dynamic>.from(o as Map)))
                .toList() ??
            [];
        return items;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Updates status of a WhatsApp Catalog Order
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _dio.patch('/api/catalog/orders/$orderId/status', data: {'status': status});
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to update order status');
    }
  }

  /// Generates and sends a dynamic Razorpay payment link for an order via WhatsApp.
  Future<Map<String, dynamic>> sendPaymentLink(String orderId) async {
    try {
      final response = await _dio.post('/api/catalog/orders/$orderId/send-payment-link');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': true};
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send payment link');
    }
  }

  /// Manually marks an order as paid (for cash or offline collection).
  Future<void> markOrderPaid(String orderId, {String? paymentId}) async {
    try {
      await _dio.post('/api/catalog/orders/$orderId/mark-paid', data: {
        if (paymentId != null) 'paymentId': paymentId,
      });
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to mark order as paid');
    }
  }


  // ── Send Messages ─────────────────────────────────────────────────────────────

  /// Sends a Catalog Message (shows full catalog with View Catalog button).
  Future<String> sendCatalogMessage(CatalogMessageRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-catalog-message',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send catalog message');
    }
    return 'sent';
  }

  /// Sends a Single Product Message (highlights one SKU).
  Future<String> sendSingleProduct(SingleProductRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-single-product',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send single product message');
    }
    return 'sent';
  }

  /// Sends a Multi-Product Message (up to 30 products across 10 sections).
  Future<String> sendMultiProduct(MultiProductRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-multi-product',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send multi-product message');
    }
    return 'sent';
  }

  /// Sends a Product Carousel (2–10 horizontally scrollable product cards).
  Future<String> sendProductCarousel(ProductCarouselRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-carousel',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send product carousel');
    }
    return 'sent';
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _extractMessageId(dynamic data) {
    if (data is Map) {
      final messages = data['messages'] as List?;
      if (messages != null && messages.isNotEmpty) {
        return messages.first['id']?.toString() ?? 'sent';
      }
      return data['messageId']?.toString() ?? data['wamid']?.toString() ?? 'sent';
    }
    return 'sent';
  }

  String? _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['error'] as String? ?? data['message'] as String?;
    }
    return e.message;
  }
}
