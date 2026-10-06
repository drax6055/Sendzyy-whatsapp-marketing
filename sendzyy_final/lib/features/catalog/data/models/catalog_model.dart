// Catalog Commerce Settings
class CatalogCommerceSettings {
  final bool isCartEnabled;
  final bool isCatalogVisible;
  final String id;

  CatalogCommerceSettings({
    required this.isCartEnabled,
    required this.isCatalogVisible,
    required this.id,
  });

  factory CatalogCommerceSettings.fromJson(Map<String, dynamic> json) {
    return CatalogCommerceSettings(
      isCartEnabled: json['is_cart_enabled'] ?? false,
      isCatalogVisible: json['is_catalog_visible'] ?? false,
      id: json['id']?.toString() ?? '',
    );
  }

  factory CatalogCommerceSettings.defaultSettings() {
    return CatalogCommerceSettings(
      isCartEnabled: true,
      isCatalogVisible: false,
      id: '',
    );
  }
}

// A single product from the Meta catalog
class CatalogProduct {
  final String retailerId; // product_retailer_id / content_id / SKU
  final String name;
  final String description;
  final double? price;
  final String? currency;
  final String? imageUrl;
  final bool isAvailable;
  final String? brand;

  CatalogProduct({
    required this.retailerId,
    required this.name,
    required this.description,
    this.price,
    this.currency,
    this.imageUrl,
    this.isAvailable = true,
    this.brand,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    double? parsedPrice;
    final rawPrice = json['price'] ?? json['sale_price'];
    if (rawPrice != null) {
      parsedPrice = double.tryParse(rawPrice.toString());
      // Meta returns price as integer cents sometimes
      if (parsedPrice != null && parsedPrice > 100) {
        parsedPrice = parsedPrice / 100;
      }
    }

    return CatalogProduct(
      retailerId: json['retailer_id']?.toString() ??
          json['id']?.toString() ??
          json['product_retailer_id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: parsedPrice,
      currency: json['currency']?.toString(),
      imageUrl: json['image_url']?.toString() ??
          json['imageUrl']?.toString(),
      isAvailable: json['availability']?.toString() != 'out of stock',
      brand: json['brand']?.toString(),
    );
  }

  String get formattedPrice {
    if (price == null) return '';
    final symbol = _currencySymbol(currency);
    return '$symbol${price!.toStringAsFixed(2)}';
  }

  String _currencySymbol(String? currency) {
    switch (currency?.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency != null ? '$currency ' : '';
    }
  }
}

// ── Message Request Models ────────────────────────────────────────────────────

/// Catalog Message — shows full catalog with thumbnail + "View catalog" button
class CatalogMessageRequest {
  final String to;
  final String bodyText;
  final String? footerText;
  final String? thumbnailProductRetailerId;

  CatalogMessageRequest({
    required this.to,
    required this.bodyText,
    this.footerText,
    this.thumbnailProductRetailerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
      if (thumbnailProductRetailerId != null &&
          thumbnailProductRetailerId!.isNotEmpty)
        'thumbnailProductRetailerId': thumbnailProductRetailerId,
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'catalog_message',
        'body': {'text': bodyText},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'name': 'catalog_message',
          if (thumbnailProductRetailerId != null &&
              thumbnailProductRetailerId!.isNotEmpty)
            'parameters': {
              'thumbnail_product_retailer_id': thumbnailProductRetailerId!,
            },
        },
      },
    };
  }
}

/// Single Product Message — highlights one specific product
class SingleProductRequest {
  final String to;
  final String catalogId;
  final String productRetailerId;
  final String? bodyText;
  final String? footerText;

  SingleProductRequest({
    required this.to,
    required this.catalogId,
    required this.productRetailerId,
    this.bodyText,
    this.footerText,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'catalogId': catalogId,
      'productRetailerId': productRetailerId,
      if (bodyText != null && bodyText!.isNotEmpty) 'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'product',
        if (bodyText != null && bodyText!.isNotEmpty)
          'body': {'text': bodyText!},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'catalog_id': catalogId,
          'product_retailer_id': productRetailerId,
        },
      },
    };
  }
}

/// A section within a Multi-Product Message
class MultiProductSection {
  final String title;
  final List<String> productRetailerIds;

  MultiProductSection({
    required this.title,
    required this.productRetailerIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'productItems': productRetailerIds.map((id) => {'productRetailerId': id}).toList(),
    };
  }
}

/// Multi-Product Message — up to 30 products across 10 sections
class MultiProductRequest {
  final String to;
  final String catalogId;
  final String headerText;
  final String bodyText;
  final String? footerText;
  final List<MultiProductSection> sections;

  MultiProductRequest({
    required this.to,
    required this.catalogId,
    required this.headerText,
    required this.bodyText,
    this.footerText,
    required this.sections,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'catalogId': catalogId,
      'headerText': headerText,
      'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'product_list',
        'header': {'type': 'text', 'text': headerText},
        'body': {'text': bodyText},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'catalog_id': catalogId,
          'sections': sections
              .map((s) => {
                    'title': s.title,
                    'product_items': s.productRetailerIds
                        .map((id) => {'product_retailer_id': id})
                        .toList(),
                  })
              .toList(),
        },
      },
    };
  }
}

/// A single card in a product carousel
class ProductCarouselCard {
  final int cardIndex;
  final String productRetailerId;
  final String catalogId;

  ProductCarouselCard({
    required this.cardIndex,
    required this.productRetailerId,
    required this.catalogId,
  });

  Map<String, dynamic> toJson() {
    return {
      'cardIndex': cardIndex,
      'productRetailerId': productRetailerId,
      'catalogId': catalogId,
    };
  }
}

/// Product Carousel Message — 2–10 horizontally scrollable product cards
class ProductCarouselRequest {
  final String to;
  final String bodyText;
  final List<ProductCarouselCard> cards;

  ProductCarouselRequest({
    required this.to,
    required this.bodyText,
    required this.cards,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'bodyText': bodyText,
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'carousel',
        'body': {'text': bodyText},
        'action': {
          'cards': cards
              .map((c) => {
                    'card_index': c.cardIndex,
                    'components': [
                      {
                        'type': 'button',
                        'sub_type': 'product',
                        'parameters': [
                          {
                            'type': 'product',
                            'product': {
                              'catalog_id': c.catalogId,
                              'product_retailer_id': c.productRetailerId,
                            },
                          },
                        ],
                      },
                    ],
                  })
              .toList(),
        },
      },
    };
  }
}

/// Discovered / Connected Meta Catalog Info
class CatalogInfo {
  final String catalogId;
  final String name;
  final String vertical;
  final bool isDefault;
  final int productCount;

  CatalogInfo({
    required this.catalogId,
    required this.name,
    required this.vertical,
    this.isDefault = false,
    this.productCount = 0,
  });

  factory CatalogInfo.fromJson(Map<String, dynamic> json) {
    return CatalogInfo(
      catalogId: json['catalogId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Catalog',
      vertical: json['vertical']?.toString() ?? 'commerce',
      isDefault: json['isDefault'] == true,
      productCount: (json['productCount'] is num) ? (json['productCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'catalogId': catalogId,
    'name': name,
    'vertical': vertical,
    'isDefault': isDefault,
    'productCount': productCount,
  };
}

/// Item inside a WhatsApp Catalog Order
class WhatsAppOrderItem {
  final String productRetailerId;
  final int quantity;
  final double itemPrice;
  final String currency;

  WhatsAppOrderItem({
    required this.productRetailerId,
    required this.quantity,
    required this.itemPrice,
    required this.currency,
  });

  factory WhatsAppOrderItem.fromJson(Map<String, dynamic> json) {
    return WhatsAppOrderItem(
      productRetailerId: json['productRetailerId']?.toString() ?? json['product_retailer_id']?.toString() ?? '',
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      itemPrice: (json['itemPrice'] is num) ? (json['itemPrice'] as num).toDouble() : (double.tryParse(json['item_price']?.toString() ?? '0') ?? 0.0),
      currency: json['currency']?.toString() ?? 'INR',
    );
  }
}

/// Customer Order received via WhatsApp Catalog cart
class WhatsAppOrder {
  final String id;
  final String contactId;
  final String contactName;
  final String catalogId;
  final String customerNote;
  final List<WhatsAppOrderItem> items;
  final double totalAmount;
  final String currency;
  final String status;
  final String paymentStatus;
  final String? paymentLinkId;
  final String? paymentLinkUrl;
  final String? paymentId;
  final DateTime? paidAt;
  final DateTime? createdAt;

  WhatsAppOrder({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.catalogId,
    required this.customerNote,
    required this.items,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.paymentStatus = 'pending',
    this.paymentLinkId,
    this.paymentLinkUrl,
    this.paymentId,
    this.paidAt,
    this.createdAt,
  });

  factory WhatsAppOrder.fromJson(Map<String, dynamic> json) {
    return WhatsAppOrder(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      contactId: json['contactId']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      catalogId: json['catalogId']?.toString() ?? '',
      customerNote: json['customerNote']?.toString() ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => WhatsAppOrderItem.fromJson(Map<String, dynamic>.from(i as Map)))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : (double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0),
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'received',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      paymentLinkId: json['paymentLinkId']?.toString(),
      paymentLinkUrl: json['paymentLinkUrl']?.toString(),
      paymentId: json['paymentId']?.toString(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

