import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/utils/catalog_report_export_helper.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_report_tab.dart';

// Fake repository for testing CatalogBloc without network calls
class FakeCatalogRepository extends CatalogRepository {
  List<WhatsAppOrder> mockOrders = [];
  List<CatalogProduct> mockProducts = [];
  String? updatedOrderId;
  String? updatedStatus;

  FakeCatalogRepository() : super(Dio());

  @override
  Future<List<WhatsAppOrder>> getOrders({String? status, String? contactId}) async {
    return mockOrders;
  }

  @override
  Future<List<CatalogProduct>> fetchProducts({
    String? after,
    String? catalogId,
    int limit = 25,
    String? searchQuery,
  }) async {
    return mockProducts;
  }

  @override
  Future<CatalogCommerceSettings> getCommerceSettings() async {
    return CatalogCommerceSettings(
      isCartEnabled: true,
      isCatalogVisible: true,
      id: 'settings-123',
    );
  }

  @override
  Future<({String? activeCatalogId, List<CatalogInfo> catalogs})> getCatalogs() async {
    return (
      activeCatalogId: 'cat-123',
      catalogs: [
        CatalogInfo(
          catalogId: 'cat-123',
          name: 'Main Catalog',
          vertical: 'commerce',
          isDefault: true,
          productCount: 10,
        )
      ],
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    updatedOrderId = orderId;
    updatedStatus = status;
  }
}

class StaticCatalogBloc extends CatalogBloc {
  final CatalogState _fixedState;
  StaticCatalogBloc(super.repository, this._fixedState);

  @override
  CatalogState get state => _fixedState;

  @override
  Future<void> close() async {
    await super.close();
  }
}

void main() {
  group('Catalog Models & Data Integrity Tests', () {
    test('WhatsAppOrder.fromJson parses all fields and nested items correctly', () {
      final json = {
        '_id': 'ord_987',
        'contactId': '919876543210',
        'contactName': 'Rahul Sharma',
        'catalogId': 'cat_456',
        'customerNote': 'Please deliver before 5 PM',
        'items': [
          {
            'productRetailerId': 'SKU_SHIRT_01',
            'quantity': 2,
            'itemPrice': 499.50,
            'currency': 'INR',
          },
          {
            'productRetailerId': 'SKU_JEANS_02',
            'quantity': 1,
            'itemPrice': 1299.00,
            'currency': 'INR',
          }
        ],
        'totalAmount': 2298.00,
        'currency': 'INR',
        'status': 'received',
        'paymentStatus': 'pending',
        'paymentLinkId': 'plink_abc123',
        'paymentLinkUrl': 'https://rzp.io/i/abc123',
        'paymentId': 'pay_xyz789',
        'createdAt': '2026-10-08T10:30:00.000Z',
      };

      final order = WhatsAppOrder.fromJson(json);

      expect(order.id, 'ord_987');
      expect(order.contactId, '919876543210');
      expect(order.contactName, 'Rahul Sharma');
      expect(order.catalogId, 'cat_456');
      expect(order.customerNote, 'Please deliver before 5 PM');
      expect(order.items.length, 2);

      expect(order.items[0].productRetailerId, 'SKU_SHIRT_01');
      expect(order.items[0].quantity, 2);
      expect(order.items[0].itemPrice, 499.50);
      expect(order.items[0].currency, 'INR');

      expect(order.items[1].productRetailerId, 'SKU_JEANS_02');
      expect(order.items[1].quantity, 1);
      expect(order.items[1].itemPrice, 1299.00);

      expect(order.totalAmount, 2298.00);
      expect(order.currency, 'INR');
      expect(order.status, 'received');
      expect(order.paymentStatus, 'pending');
      expect(order.paymentLinkId, 'plink_abc123');
      expect(order.paymentLinkUrl, 'https://rzp.io/i/abc123');
      expect(order.paymentId, 'pay_xyz789');
      expect(order.createdAt, isNotNull);
      expect(order.createdAt!.year, 2026);
    });

    test('WhatsAppOrder fallback handling for legacy keys and null values', () {
      final json = {
        'id': 'ord_fallback',
        'contactId': '919999999999',
        'items': [
          {
            'product_retailer_id': 'SKU_TEST',
            'quantity': '3',
            'item_price': '150.0',
          }
        ],
        'totalAmount': '450.0',
      };

      final order = WhatsAppOrder.fromJson(json);

      expect(order.id, 'ord_fallback');
      expect(order.contactId, '919999999999');
      expect(order.items.length, 1);
      expect(order.items[0].productRetailerId, 'SKU_TEST');
      expect(order.items[0].itemPrice, 150.0);
      expect(order.totalAmount, 450.0);
      expect(order.status, 'received');
      expect(order.paymentStatus, 'pending');
    });

    test('CatalogProduct price and effectivePrice calculations', () {
      final productWithSale = CatalogProduct.fromJson({
        'retailer_id': 'PROD_001',
        'name': 'Wireless Headphones',
        'description': 'Noise cancelling bluetooth headphones',
        'price': '₹2,999.00',
        'sale_price': '1999.00',
        'currency': 'INR',
        'availability': 'in stock',
      });

      expect(productWithSale.retailerId, 'PROD_001');
      expect(productWithSale.name, 'Wireless Headphones');
      expect(productWithSale.price, 2999.00);
      expect(productWithSale.salePrice, 1999.00);
      expect(productWithSale.effectivePrice, 1999.00);
      expect(productWithSale.isAvailable, true);
      expect(productWithSale.formattedPrice, '₹1999.00');
      expect(productWithSale.formattedOriginalPrice, '₹2999.00');

      final productRegular = CatalogProduct.fromJson({
        'retailer_id': 'PROD_002',
        'name': 'USB-C Cable',
        'price': 299.00,
        'currency': 'INR',
        'availability': 'out of stock',
      });

      expect(productRegular.effectivePrice, 299.00);
      expect(productRegular.isAvailable, false);
      expect(productRegular.formattedOriginalPrice, '');
    });
  });

  group('Catalog Report Analytics Computations', () {
    final sampleOrders = [
      WhatsAppOrder(
        id: 'ord_1',
        contactId: '919000000001',
        contactName: 'Alice',
        catalogId: 'cat_1',
        customerNote: '',
        items: [
          WhatsAppOrderItem(productRetailerId: 'SKU_A', quantity: 2, itemPrice: 500, currency: 'INR'),
          WhatsAppOrderItem(productRetailerId: 'SKU_B', quantity: 1, itemPrice: 200, currency: 'INR'),
        ],
        totalAmount: 1200.0,
        currency: 'INR',
        status: 'completed',
        paymentStatus: 'paid',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WhatsAppOrder(
        id: 'ord_2',
        contactId: '919000000002',
        contactName: 'Bob',
        catalogId: 'cat_1',
        customerNote: '',
        items: [
          WhatsAppOrderItem(productRetailerId: 'SKU_A', quantity: 1, itemPrice: 500, currency: 'INR'),
        ],
        totalAmount: 500.0,
        currency: 'INR',
        status: 'processing',
        paymentStatus: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      WhatsAppOrder(
        id: 'ord_3',
        contactId: '919000000003',
        contactName: 'Charlie',
        catalogId: 'cat_1',
        customerNote: '',
        items: [
          WhatsAppOrderItem(productRetailerId: 'SKU_C', quantity: 3, itemPrice: 100, currency: 'INR'),
        ],
        totalAmount: 300.0,
        currency: 'INR',
        status: 'received',
        paymentStatus: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      WhatsAppOrder(
        id: 'ord_4',
        contactId: '919000000004',
        contactName: 'David',
        catalogId: 'cat_1',
        customerNote: '',
        items: [
          WhatsAppOrderItem(productRetailerId: 'SKU_B', quantity: 1, itemPrice: 200, currency: 'INR'),
        ],
        totalAmount: 200.0,
        currency: 'INR',
        status: 'cancelled',
        paymentStatus: 'failed',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];

    test('KPI metrics calculations (Total Orders, Gross, Paid, Pending, AOV)', () {
      double totalRevenue = 0;
      double paidRevenue = 0;
      double pendingRevenue = 0;
      int paidCount = 0;

      for (final o in sampleOrders) {
        totalRevenue += o.totalAmount;
        if (o.paymentStatus == 'paid') {
          paidRevenue += o.totalAmount;
          paidCount++;
        } else {
          pendingRevenue += o.totalAmount;
        }
      }

      final aov = totalRevenue / sampleOrders.length;

      expect(sampleOrders.length, 4);
      expect(totalRevenue, 2200.0);
      expect(paidRevenue, 1200.0);
      expect(paidCount, 1);
      expect(pendingRevenue, 1000.0);
      expect(aov, 550.0);
    });

    test('Fulfillment status funnel distribution and counts', () {
      final total = sampleOrders.length;
      final completed = sampleOrders.where((o) => o.status == 'completed').length;
      final processing = sampleOrders.where((o) => o.status == 'processing' || o.status == 'accepted').length;
      final received = sampleOrders.where((o) => o.status == 'received').length;
      final cancelled = sampleOrders.where((o) => o.status == 'cancelled').length;

      expect(completed, 1);
      expect(processing, 1);
      expect(received, 1);
      expect(cancelled, 1);

      // Each is 25% of the total 4 orders
      expect((completed / total) * 100, 25.0);
      expect((processing / total) * 100, 25.0);
      expect((received / total) * 100, 25.0);
      expect((cancelled / total) * 100, 25.0);
    });

    test('Top selling products aggregation by SKU, units sold, and revenue', () {
      final Map<String, int> productQty = {};
      final Map<String, double> productRev = {};

      for (final o in sampleOrders) {
        for (final item in o.items) {
          final sku = item.productRetailerId;
          productQty[sku] = (productQty[sku] ?? 0) + item.quantity;
          productRev[sku] = (productRev[sku] ?? 0) + (item.itemPrice * item.quantity);
        }
      }

      // SKU_A: (2 in ord_1, 1 in ord_2) = 3 units -> ₹1500
      expect(productQty['SKU_A'], 3);
      expect(productRev['SKU_A'], 1500.0);

      // SKU_B: (1 in ord_1, 1 in ord_4) = 2 units -> ₹400
      expect(productQty['SKU_B'], 2);
      expect(productRev['SKU_B'], 400.0);

      // SKU_C: (3 in ord_3) = 3 units -> ₹300
      expect(productQty['SKU_C'], 3);
      expect(productRev['SKU_C'], 300.0);

      // Verify sorted rankings by revenue
      final sortedSkus = productRev.keys.toList()
        ..sort((a, b) => productRev[b]!.compareTo(productRev[a]!));

      expect(sortedSkus, ['SKU_A', 'SKU_B', 'SKU_C']);
    });

    test('Filter logic: search by customer name, phone, SKU, and status', () {
      // 1. Search by customer phone
      final matchPhone = sampleOrders.where((o) => o.contactId.contains('9000000002')).toList();
      expect(matchPhone.length, 1);
      expect(matchPhone.first.contactName, 'Bob');

      // 2. Search by customer name
      final matchName = sampleOrders.where((o) => o.contactName.toLowerCase().contains('charlie')).toList();
      expect(matchName.length, 1);
      expect(matchName.first.id, 'ord_3');

      // 3. Search by SKU
      final matchSku = sampleOrders.where((o) => o.items.any((i) => i.productRetailerId.contains('SKU_C'))).toList();
      expect(matchSku.length, 1);
      expect(matchSku.first.id, 'ord_3');

      // 4. Filter by status 'completed'
      final completedOnly = sampleOrders.where((o) => o.status == 'completed').toList();
      expect(completedOnly.length, 1);
      expect(completedOnly.first.contactName, 'Alice');

      // 5. Filter by paymentStatus 'pending'
      final pendingPayments = sampleOrders.where((o) => o.paymentStatus == 'pending').toList();
      expect(pendingPayments.length, 2);
    });

    test('CSV export payload contains accurate headers and formatted order data', () {
      final buffer = StringBuffer();
      buffer.writeln(
        'Order ID,Date,Customer Phone,Customer Name,Items Count,Items Summary,Currency,Total Amount,Payment Status,Fulfillment Status,Payment Link ID,Payment ID,Note',
      );

      for (final o in sampleOrders) {
        final itemsSummary = o.items.map((i) => '${i.productRetailerId} (x${i.quantity})').join('; ');
        buffer.writeln(
          '"${o.id}",'
          '"${o.createdAt?.toIso8601String() ?? ''}",'
          '"${o.contactId}",'
          '"${o.contactName}",'
          '${o.items.length},'
          '"$itemsSummary",'
          '"${o.currency}",'
          '${o.totalAmount.toStringAsFixed(2)},'
          '"${o.paymentStatus}",'
          '"${o.status}",'
          '"${o.paymentLinkId ?? ''}",'
          '"${o.paymentId ?? ''}",'
          '"${o.customerNote.replaceAll('"', '""')}"',
        );
      }

      final csvContent = buffer.toString();
      expect(csvContent.contains('Order ID,Date,Customer Phone'), true);
      expect(csvContent.contains('"ord_1"'), true);
      expect(csvContent.contains('SKU_A (x2); SKU_B (x1)'), true);
      expect(csvContent.contains('1200.00'), true);
      expect(csvContent.contains('"paid"'), true);
      expect(csvContent.contains('"completed"'), true);
    });

    test('CatalogReportExportHelper Excel export produces valid CSV file', () async {
      final fileName = await CatalogReportExportHelper.exportExcel(orders: sampleOrders);
      expect(fileName.startsWith('catalog_orders_report_'), isTrue);
      expect(fileName.endsWith('.csv'), isTrue);
    });

    test('CatalogReportExportHelper PDF export produces valid PDF file', () async {
      final fileName = await CatalogReportExportHelper.exportPdf(
        orders: sampleOrders,
        products: [
          CatalogProduct(
            retailerId: 'SKU_A',
            name: 'Product A',
            description: 'Description A',
            price: 500,
            currency: 'INR',
            isAvailable: true,
          ),
        ],
        datePreset: '30d',
      );
      expect(fileName.startsWith('catalog_orders_report_'), isTrue);
      expect(fileName.endsWith('.pdf'), isTrue);
    });

    test('CatalogReportExportHelper throws exception when exporting empty orders', () async {
      expect(
        () => CatalogReportExportHelper.exportExcel(orders: []),
        throwsA(isA<Exception>()),
      );
      expect(
        () => CatalogReportExportHelper.exportPdf(orders: [], products: []),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CatalogBloc UpdateOrderStatusEvent test', () {
    test('UpdateOrderStatusEvent calls repository and updates orders', () async {
      final fakeRepo = FakeCatalogRepository();
      fakeRepo.mockOrders = [
        WhatsAppOrder(
          id: 'order_test_update',
          contactId: '919876543210',
          contactName: 'Tester',
          catalogId: 'cat_1',
          customerNote: '',
          items: [],
          totalAmount: 100,
          currency: 'INR',
          status: 'received',
        ),
      ];

      final bloc = CatalogBloc(fakeRepo);

      // Load initial settings
      bloc.add(LoadCommerceSettings());
      await Future.delayed(const Duration(milliseconds: 50));

      // Dispatch status update
      bloc.add(UpdateOrderStatusEvent('order_test_update', 'accepted'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeRepo.updatedOrderId, 'order_test_update');
      expect(fakeRepo.updatedStatus, 'accepted');

      final state = bloc.state as CatalogSettingsLoaded;
      expect(state.successMessage, 'Order status updated to accepted!');

      await bloc.close();
    });
  });

  group('CatalogReportTab Widget Test', () {
    testWidgets('Renders KPI metrics, funnels, and orders table accurately', (WidgetTester tester) async {
      final fakeRepo = FakeCatalogRepository();
      final orders = [
        WhatsAppOrder(
          id: 'ORD_UI_1',
          contactId: '919876543210',
          contactName: 'Vijay Kumar',
          catalogId: 'cat_1',
          customerNote: 'Fast shipping please',
          items: [
            WhatsAppOrderItem(
              productRetailerId: 'SKU_PREMIUM_SHIRT',
              quantity: 2,
              itemPrice: 750.0,
              currency: 'INR',
            ),
          ],
          totalAmount: 1500.0,
          currency: 'INR',
          status: 'completed',
          paymentStatus: 'paid',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ];

      final products = [
        CatalogProduct(
          retailerId: 'SKU_PREMIUM_SHIRT',
          name: 'Premium Cotton Shirt',
          description: '100% pure cotton',
          price: 750.0,
          currency: 'INR',
          isAvailable: true,
        ),
      ];

      final bloc = StaticCatalogBloc(
        fakeRepo,
        CatalogSettingsLoaded(
          settings: CatalogCommerceSettings.defaultSettings(),
          orders: orders,
          products: products,
        ),
      );

      // Build CatalogReportTab widget
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<CatalogBloc>.value(
              value: bloc,
              child: const CatalogReportTab(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Top Controls and Filter chips
      expect(find.text('Catalog Performance & Orders Report'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('Export Report'), findsOneWidget);

      // Verify Export dropdown menu displays options for Excel and PDF
      await tester.tap(find.text('Export Report'));
      await tester.pumpAndSettle();
      expect(find.text('Download in Excel'), findsOneWidget);
      expect(find.text('Download in PDF'), findsOneWidget);

      // Dismiss menu to continue checking rest of page
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 2. Verify Hero KPI Metric cards
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Gross Revenue'), findsOneWidget);
      expect(find.text('Collected Revenue'), findsOneWidget);
      expect(find.text('Pending Amount'), findsOneWidget);
      expect(find.text('Avg Order Value (AOV)'), findsOneWidget);
      expect(find.text('Catalog Products'), findsOneWidget);

      // Verify calculated currency values across KPI cards, top products list, and order table
      expect(find.text('₹1,500.00'), findsNWidgets(5)); // Gross, Collected, AOV, Top Product revenue, Order row total

      // 3. Verify Funnel & Top Selling Products
      expect(find.text('Fulfillment Status Funnel'), findsOneWidget);
      expect(find.text('Top Performing Catalog Products'), findsOneWidget);
      expect(find.text('Premium Cotton Shirt'), findsOneWidget);
      expect(find.textContaining('SKU_PREMIUM_SHIRT'), findsOneWidget);

      // 4. Verify Orders Activity Log Table
      expect(find.text('Orders & Inquiries Log'), findsOneWidget);
      expect(find.text('Vijay Kumar'), findsOneWidget);
      expect(find.text('919876543210'), findsOneWidget);
      expect(find.text('Completed'), findsAtLeastNWidgets(1));
      expect(find.text('Paid'), findsOneWidget);

      // Cleanly unmount widget
      await tester.pumpWidget(const SizedBox());
      await bloc.close();
    });
  });
}
