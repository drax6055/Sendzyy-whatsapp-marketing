import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/commerce_settings_card.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/product_browser_widget.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_message_composer.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/multi_product_composer.dart';

import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
  
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<CatalogBloc>().add(LoadCommerceSettings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.successMessage!)),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<CatalogBloc>().add(ClearCatalogStatus());
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.errorMessage!)),
                  ],
                ),
                backgroundColor: Colors.red.shade500,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<CatalogBloc>().add(ClearCatalogStatus());
          }
        }
      },
      child: Column(
        children: [
          // ── Page Header ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              isMobile ? 14 : 20,
              isMobile ? 16 : 24,
              0,
            ),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WhatsApp Catalog',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1D1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Manage your Meta products, catalogs, orders, and messages',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 20),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 2.5,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
                  unselectedLabelStyle: TextStyle(fontSize: isMobile ? 12 : 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.settings_rounded, size: 18),
                      text: 'Overview',
                    ),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'Products',
                    ),
                    Tab(
                      icon: Icon(Icons.shopping_bag_outlined, size: 18),
                      text: 'Orders',
                    ),
                    Tab(
                      icon: Icon(Icons.send_rounded, size: 18),
                      text: 'Send Messages',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Tab Views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(),
                _ProductsTab(),
                _OrdersTab(),
                _SendMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab: Overview ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is CatalogSettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CatalogError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade400, size: 48),
                const SizedBox(height: 16),
                Text(state.message,
                    style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<CatalogBloc>().add(LoadCommerceSettings()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state is CatalogSettingsLoaded) ...[
                // Connected Catalog Card & Switcher
                _ConnectedCatalogBanner(state: state),
                SizedBox(height: isMobile ? 16 : 20),
                // Stats row
                _StatsRow(state: state),
                SizedBox(height: isMobile ? 16 : 24),
              ],
              // Commerce settings
              const CommerceSettingsCard(),
              SizedBox(height: isMobile ? 16 : 24),
              // Info card
              _HelpCard(),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectedCatalogBanner extends StatelessWidget {
  final CatalogSettingsLoaded state;
  const _ConnectedCatalogBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final activeCat = state.activeCatalog;
    final hasCatalogs = state.catalogs.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            activeCat?.name ??
                                (hasCatalogs
                                    ? 'Connected Meta Catalog'
                                    : 'No Meta Catalog Connected'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1A1D1E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasCatalogs
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasCatalogs ? 'Connected' : 'Unlinked',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasCatalogs
                                  ? const Color(0xFF10B981)
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCatalogs
                          ? 'Catalog ID: ${state.activeCatalogId ?? "N/A"} • ${activeCat?.vertical ?? "commerce"}'
                          : 'Connect your catalog via Meta Commerce Manager or click Sync below',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.isSyncingCatalogs
                    ? null
                    : () => context
                        .read<CatalogBloc>()
                        .add(SyncCatalogsWithMeta()),
                icon: state.isSyncingCatalogs
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                    state.isSyncingCatalogs ? 'Syncing...' : 'Sync with Meta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          if (state.catalogs.length > 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Switch Active Catalog:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.activeCatalogId,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: state.catalogs.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.catalogId,
                          child: Text(
                            '${c.name} (${c.catalogId})',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<CatalogBloc>()
                              .add(SelectActiveCatalog(val));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final CatalogSettingsLoaded state;

  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    final cards = [
      _StatCard(
        icon: Icons.inventory_2_rounded,
        label: 'Products',
        value: state.isLoadingProducts ? '...' : '${state.products.length}',
        color: const Color(0xFF06B6D4),
      ),
      _StatCard(
        icon: Icons.shopping_bag_outlined,
        label: 'Orders Received',
        value: '${state.orders.length}',
        color: const Color(0xFF6366F1),
      ),
      _StatCard(
        icon: Icons.shopping_cart_checkout_rounded,
        label: 'Cart',
        value: state.settings.isCartEnabled ? 'Enabled' : 'Disabled',
        color: state.settings.isCartEnabled
            ? const Color(0xFF10B981)
            : Colors.grey,
      ),
      _StatCard(
        icon: Icons.visibility_rounded,
        label: 'Catalog',
        value: state.settings.isCatalogVisible ? 'Visible' : 'Hidden',
        color: state.settings.isCatalogVisible
            ? AppTheme.primaryColor
            : Colors.grey,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: c,
                ))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                ),
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'How Catalog Commerce Works',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            '1. Upload inventory to Meta via Commerce Manager or via Sendzyy',
            '2. Connect your catalog to your WABA via Embedded Signup or click "Sync with Meta"',
            '3. Configure cart and catalog visibility above',
            '4. Use the "Send Messages" tab to share products or single items in chat',
            '5. When customers check out in WhatsApp, orders appear in the Orders tab and live chat',
          ].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Tab: Products ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: const ProductBrowserWidget(),
    );
  }
}

// ── Tab: Orders ───────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = state.orders;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<CatalogBloc>().add(LoadOrders());
          },
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined,
                            size: 48, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Orders Received Yet',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D1E)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'When customers browse your catalog and send an order, it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<CatalogBloc>().add(LoadOrders()),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh Orders'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    return _OrderCard(order: order);
                  },
                ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final WhatsAppOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.contactName.isNotEmpty
                          ? order.contactName
                          : order.contactId,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      order.contactId,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildPaymentBadge(order.paymentStatus),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Items
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SKU ${item.productRetailerId} (x${item.quantity})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (item.itemPrice > 0)
                    Text(
                      '${item.currency} ${(item.itemPrice * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            );
          }),
          if (order.customerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: "${order.customerNote}"',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.createdAt != null
                    ? '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year} ${order.createdAt!.hour}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
                    : '',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              if (order.totalAmount > 0)
                Text(
                  'Total: ${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF10B981)),
                ),
            ],
          ),

          // Payment Link banner (if generated)
          if (order.paymentLinkUrl != null && order.paymentLinkUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Link Generated',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                        Text(
                          order.paymentLinkUrl!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF15803D),
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF16A34A)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy payment link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.paymentLinkUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment link copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Paid details banner
          if (order.paymentStatus.toLowerCase() == 'paid') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    order.paymentId != null
                        ? 'Payment ID: ${order.paymentId}'
                        : 'Paid via Razorpay',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons for unpaid orders
          if (order.paymentStatus.toLowerCase() != 'paid' && order.totalAmount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: Text(
                      order.paymentLinkUrl != null ? 'Resend Payment Link' : 'Send Payment Link',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      context.read<CatalogBloc>().add(SendOrderPaymentLinkEvent(order.id));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _confirmMarkPaid(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmMarkPaid(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Mark as Paid?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Confirm that customer "${order.contactName.isNotEmpty ? order.contactName : order.contactId}" has completed payment of ${order.currency} ${order.totalAmount.toStringAsFixed(2)}?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CatalogBloc>().add(MarkOrderPaidEvent(order.id));
            },
            child: const Text('Confirm Paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF10B981)),
              SizedBox(width: 4),
              Text(
                'PAID',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

      case 'failed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 10, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Text(
                'FAILED',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

      case 'pending':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 10, color: Colors.amber.shade800),
              const SizedBox(width: 4),
              Text(
                'UNPAID',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return const Color(0xFF6366F1);
      case 'accepted':
        return const Color(0xFF06B6D4);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ── Tab: Send Messages ────────────────────────────────────────────────────────

class _SendMessagesTab extends StatefulWidget {
  @override
  State<_SendMessagesTab> createState() => _SendMessagesTabState();
}

class _SendMessagesTabState extends State<_SendMessagesTab> {
  int _selectedComposer = 0;

  final _composerLabels = [
    (icon: Icons.storefront_rounded, label: 'Catalog Msg', color: const Color(0xFF25D366)),
    (icon: Icons.inventory_2_outlined, label: 'Single Product', color: const Color(0xFF06B6D4)),
    (icon: Icons.grid_view_rounded, label: 'Multi-Product', color: const Color(0xFF6366F1)),
    (icon: Icons.view_carousel_rounded, label: 'Carousel', color: const Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      return Column(
        children: [
          // Top horizontal selector on mobile
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _composerLabels.length,
                  (i) {
                    final item = _composerLabels[i];
                    final isSelected = _selectedComposer == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedComposer = i),
                        avatar: Icon(item.icon,
                            size: 16,
                            color: isSelected ? Colors.white : item.color),
                        label: Text(item.label),
                        selectedColor: item.color,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildComposer(),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Left: composer type selector on desktop/tablet
        Container(
          width: 200,
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12, top: 8),
                child: Text(
                  'Message Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ...List.generate(
                _composerLabels.length,
                (i) {
                  final item = _composerLabels[i];
                  final isSelected = _selectedComposer == i;
                  return InkWell(
                    onTap: () => setState(() => _selectedComposer = i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: item.color.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon,
                              color: isSelected
                                  ? item.color
                                  : Colors.grey.shade400,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? item.color
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        // Right: composer form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildComposer(),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    switch (_selectedComposer) {
      case 0:
        return const CatalogMessageComposer();
      case 1:
        return const SingleProductComposer();
      case 2:
        return const MultiProductComposer();
      case 3:
        return const ProductCarouselComposer();
      default:
        return const SizedBox.shrink();
    }
  }
}
