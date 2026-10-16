import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_recipient_selector.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';

class FakeCatalogRepository extends CatalogRepository {
  FakeCatalogRepository() : super(Dio());

  final List<CatalogMessageRequest> sentCatalogMessages = [];

  @override
  Future<String> sendCatalogMessage(CatalogMessageRequest request) async {
    sentCatalogMessages.add(request);
    return 'wamid.test_${request.to}';
  }
}

void main() {
  group('Catalog Models Bulk Recipient Tests', () {
    test('CatalogMessageRequest allRecipients returns list or single to', () {
      final singleReq = CatalogMessageRequest(
        to: '919876543210',
        bodyText: 'Hello Catalog',
      );
      expect(singleReq.allRecipients, ['919876543210']);
      expect(singleReq.toJson()['to'], '919876543210');
      expect(singleReq.toJson().containsKey('recipients'), isFalse);

      final bulkReq = CatalogMessageRequest(
        to: '919876543210',
        recipients: ['919876543210', '919876543211', '919876543212'],
        bodyText: 'Hello Bulk Catalog',
      );
      expect(bulkReq.allRecipients.length, 3);
      expect(bulkReq.toJson()['to'], ['919876543210', '919876543211', '919876543212']);
      expect(bulkReq.toJson()['recipients'], ['919876543210', '919876543211', '919876543212']);

      final copied = bulkReq.copyWith(to: '919999999999');
      expect(copied.to, '919999999999');
      expect(copied.recipients?.length, 3);
    });

    test('SingleProductRequest allRecipients handles single and bulk', () {
      final req = SingleProductRequest(
        to: '919876543210',
        catalogId: 'cat_1',
        productRetailerId: 'sku_100',
        recipients: ['919876543210', '919876543211'],
      );
      expect(req.allRecipients, ['919876543210', '919876543211']);
      expect(req.toJson()['recipients'], ['919876543210', '919876543211']);
      expect(req.toJson()['productRetailerId'], 'sku_100');
    });

    test('MultiProductRequest allRecipients handles single and bulk', () {
      final req = MultiProductRequest(
        to: '919876543210',
        catalogId: 'cat_1',
        headerText: 'Specials',
        bodyText: 'Check these out',
        sections: [
          MultiProductSection(title: 'Sec 1', productRetailerIds: ['sku_1'])
        ],
        recipients: ['919876543210', '919876543211'],
      );
      expect(req.allRecipients.length, 2);
      expect(req.toJson()['headerText'], 'Specials');
    });

    test('ProductCarouselRequest allRecipients handles single and bulk', () {
      final req = ProductCarouselRequest(
        to: '919876543210',
        bodyText: 'Carousel Items',
        cards: [
          ProductCarouselCard(cardIndex: 0, productRetailerId: 'sku_1', catalogId: 'cat_1'),
          ProductCarouselCard(cardIndex: 1, productRetailerId: 'sku_2', catalogId: 'cat_1'),
        ],
        recipients: ['919876543210', '919876543211'],
      );
      expect(req.allRecipients.length, 2);
      expect(req.toJson()['bodyText'], 'Carousel Items');
    });

    test('CatalogBulkResult instantiates correctly', () {
      final result = CatalogBulkResult(
        total: 5,
        successCount: 4,
        failureCount: 1,
        failedNumbers: ['919876543219'],
        dispatchedAt: DateTime(2026, 10, 15),
      );
      expect(result.total, 5);
      expect(result.successCount, 4);
      expect(result.failureCount, 1);
      expect(result.failedNumbers, ['919876543219']);
    });
  });

  group('CatalogBloc Bulk Dispatch Tests', () {
    late FakeCatalogRepository fakeRepo;
    late CatalogBloc bloc;

    setUp(() {
      fakeRepo = FakeCatalogRepository();
      bloc = CatalogBloc(fakeRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('SendCatalogMessageEvent sends in bulk and updates progress', () async {
      final initialState = CatalogSettingsLoaded(
        settings: CatalogCommerceSettings(id: 'settings-1', isCartEnabled: true, isCatalogVisible: true),
      );

      bloc.emit(initialState);

      final req = CatalogMessageRequest(
        to: '919876543210',
        recipients: ['919876543210', '919876543211', '919876543212'],
        bodyText: 'Bulk text',
      );

      final states = <CatalogState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(SendCatalogMessageEvent(req));

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 150));

      expect(fakeRepo.sentCatalogMessages.length, 3);
      expect(fakeRepo.sentCatalogMessages.map((m) => m.to).toList(), [
        '919876543210',
        '919876543211',
        '919876543212',
      ]);
      // Verify recipients list is cleared on each single request so backend does not re-broadcast bulk
      for (final sent in fakeRepo.sentCatalogMessages) {
        expect(sent.recipients, isNull);
        expect(sent.toJson().containsKey('recipients'), isFalse);
      }

      final finalState = bloc.state;
      expect(finalState, isA<CatalogSettingsLoaded>());
      final loaded = finalState as CatalogSettingsLoaded;
      expect(loaded.isSending, isFalse);
      expect(loaded.lastBulkResult, isNotNull);
      expect(loaded.lastBulkResult!.total, 3);
      expect(loaded.lastBulkResult!.successCount, 3);
      expect(loaded.lastBulkResult!.failureCount, 0);
      expect(loaded.successMessage, contains('all 3 recipient(s)'));

      await sub.cancel();
    });

    test('SendCatalogMessageEvent single recipient uses single send', () async {
      bloc.emit(CatalogSettingsLoaded(
        settings: CatalogCommerceSettings(id: 'settings-1', isCartEnabled: true, isCatalogVisible: true),
      ));

      final req = CatalogMessageRequest(
        to: '919876543210',
        bodyText: 'Single text',
      );

      bloc.add(SendCatalogMessageEvent(req));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeRepo.sentCatalogMessages.length, 1);
      expect(fakeRepo.sentCatalogMessages.first.to, '919876543210');

      final loaded = bloc.state as CatalogSettingsLoaded;
      expect(loaded.isSending, isFalse);
      expect(loaded.successMessage, contains('wamid.test_919876543210'));
    });
  });

  group('CatalogRecipientSelector Widget Tests', () {
    testWidgets('Renders manual entry, buttons, and adds recipients correctly',
        (WidgetTester tester) async {
      List<RecipientData> currentRecipients = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return CatalogRecipientSelector(
                  recipients: currentRecipients,
                  onRecipientsChanged: (list) {
                    setState(() => currentRecipients = list);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Recipient Phone Numbers'), findsOneWidget);
      expect(find.text('0 Contacts'), findsOneWidget);
      expect(find.text('Add from Clients'), findsOneWidget);
      expect(find.text('Add from Group'), findsOneWidget);
      expect(find.text('Upload CSV'), findsOneWidget);

      // Enter a valid 10-digit number
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(currentRecipients.length, 1);
      expect(currentRecipients.first.mobileNumber, '919876543210');
      expect(find.text('1 Contact'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);

      // Add a comma-separated list
      await tester.enterText(find.byType(TextField), '919123456789, 917890123456');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(currentRecipients.length, 3);
      expect(find.text('3 Contacts'), findsOneWidget);

      // Delete one recipient via chip close button
      final deleteIcons = find.byIcon(Icons.close_rounded);
      expect(deleteIcons, findsNWidgets(3));
      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      expect(currentRecipients.length, 2);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(currentRecipients.isEmpty, isTrue);
      expect(find.text('0 Contacts'), findsOneWidget);
    });

    testWidgets('flushPendingInput automatically flushes typed numbers',
        (WidgetTester tester) async {
      final key = GlobalKey<CatalogRecipientSelectorState>();
      List<RecipientData> currentRecipients = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return CatalogRecipientSelector(
                  key: key,
                  recipients: currentRecipients,
                  onRecipientsChanged: (list) {
                    setState(() => currentRecipients = list);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Type without pressing Add
      await tester.enterText(find.byType(TextField), '9876543210');

      // Call flushPendingInput programmatically (like when pressing Send)
      key.currentState?.flushPendingInput();
      await tester.pumpAndSettle();

      expect(currentRecipients.length, 1);
      expect(currentRecipients.first.mobileNumber, '919876543210');
    });
  });
}
