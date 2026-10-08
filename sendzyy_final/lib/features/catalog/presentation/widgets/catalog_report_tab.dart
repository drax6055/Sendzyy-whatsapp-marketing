import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

/// Comprehensive Catalog Analytics & Orders Report Tab
/// Displays high-level KPIs, revenue metrics, product sales performance,
/// status funnels, filterable order table, and CSV export.
class CatalogReportTab extends StatefulWidget {
  const CatalogReportTab({super.key});

  @override
  State<CatalogReportTab> createState() => _CatalogReportTabState();
}

class _CatalogReportTabState extends State<CatalogReportTab> {
  DateTimeRange? _dateRange;
  String _datePreset = 'all'; // 'all', 'today', '7d', '30d', 'custom'
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setDatePreset(String preset) async {
    final now = DateTime.now();
    DateTimeRange? range;

    if (preset == 'today') {
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      range = DateTimeRange(start: startOfDay, end: endOfDay);
    } else if (preset == '7d') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      range = DateTimeRange(start: sevenDaysAgo, end: now);
    } else if (preset == '30d') {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      range = DateTimeRange(start: thirtyDaysAgo, end: now);
    } else if (preset == 'custom') {
      final picked = await showCompactDateRangePicker(
        context: context,
        initialDateRange: _dateRange ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      );
      if (picked != null) {
        setState(() {
          _datePreset = 'custom';
          _dateRange = picked;
        });
      }
      return;
    } else {
      range = null;
    }

    setState(() {
      _datePreset = preset;
      _dateRange = range;
    });
  }

  List<WhatsAppOrder> _filterOrders(List<WhatsAppOrder> allOrders) {
    return allOrders.where((order) {
      // Date range filter
      if (_dateRange != null && order.createdAt != null) {
        final orderDate = order.createdAt!;
        if (orderDate.isBefore(_dateRange!.start) ||
            orderDate.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Order status filter
      if (_statusFilter != 'all') {
        if (order.status.toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      // Payment status filter
      if (_paymentFilter != 'all') {
        if (order.paymentStatus.toLowerCase() != _paymentFilter.toLowerCase()) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesId = order.id.toLowerCase().contains(q);
        final matchesContact = order.contactId.toLowerCase().contains(q) ||
            order.contactName.toLowerCase().contains(q);
        final matchesNote = order.customerNote.toLowerCase().contains(q);
        final matchesItem = order.items.any((item) =>
            item.productRetailerId.toLowerCase().contains(q) ||
            item.currency.toLowerCase().contains(q));

        if (!matchesId && !matchesContact && !matchesNote && !matchesItem) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _exportCsv(List<WhatsAppOrder> orders) async {
    if (orders.isEmpty) {
      SnackbarUtils.showWarning(context, 'No orders available to export.');
      return;
    }

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'Order ID,Date,Time,Customer Phone,Customer Name,Items Count,Products (SKU x Qty),Currency,Total Amount,Payment Status,Order Status,Payment Link ID,Payment ID,Customer Note');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final o in orders) {
      final dateStr = o.createdAt != null ? dateFormat.format(o.createdAt!) : '';
      final timeStr = o.createdAt != null ? timeFormat.format(o.createdAt!) : '';
      final itemsSummary = o.items
          .map((i) => '${i.productRetailerId} (x${i.quantity})')
          .join('; ');

      buffer.writeln(
        '"${o.id}",'
        '"$dateStr",'
        '"$timeStr",'
        '"${o.contactId}",'
        '"${o.contactName.replaceAll('"', '""')}",'
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

    final bytes = utf8.encode(buffer.toString());
    final fileName =
        'catalog_orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    await webDownloadBytes(bytes, fileName, mimeType: 'text/csv;charset=utf-8');
    if (mounted) {
      SnackbarUtils.showSuccess(context, 'Report exported as $fileName');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final allOrders = state.orders;
        final filteredOrders = _filterOrders(allOrders);
        final catalogProducts = state.products;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<CatalogBloc>().add(LoadOrders());
            context.read<CatalogBloc>().add(LoadProducts());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Controls & Filters ────────────────────────────────
                _buildHeaderControls(isMobile, filteredOrders),
                const SizedBox(height: 16),

                // ── 2. Hero KPI Metric Cards ─────────────────────────────────
                _buildKpiMetricsGrid(isMobile, filteredOrders, catalogProducts),
                const SizedBox(height: 20),

                // ── 3. Visual Funnels & Top Products ─────────────────────────
                _buildAnalyticsBreakdown(isMobile, filteredOrders, catalogProducts),
                const SizedBox(height: 24),

                // ── 4. Detailed Orders Activity Table ────────────────────────
                _buildOrdersTableSection(isMobile, filteredOrders),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header Controls ──────────────────────────────────────────────────────────

  Widget _buildHeaderControls(bool isMobile, List<WhatsAppOrder> filteredOrders) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catalog Performance & Orders Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1E),
                      ),
                    ),
                    Text(
                      'Real-time revenue, order fulfillment, and product sales insights',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                // Refresh Button
                IconButton(
                  tooltip: 'Refresh Data',
                  onPressed: () {
                    context.read<CatalogBloc>().add(LoadOrders());
                    context.read<CatalogBloc>().add(LoadProducts());
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 8),
                // Export CSV Button
                ElevatedButton.icon(
                  onPressed: () => _exportCsv(filteredOrders),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportCsv(filteredOrders),
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh Data',
                  onPressed: () {
                    context.read<CatalogBloc>().add(LoadOrders());
                    context.read<CatalogBloc>().add(LoadProducts());
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppTheme.secondaryColor,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Date presets row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Time Period:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              _buildFilterChip('All Time', 'all'),
              _buildFilterChip('Today', 'today'),
              _buildFilterChip('Last 7 Days', '7d'),
              _buildFilterChip('Last 30 Days', '30d'),
              _buildFilterChip(
                _datePreset == 'custom' && _dateRange != null
                    ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                    : 'Custom Range 📅',
                'custom',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters Row: Search + Status + Payment
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by phone, name, SKU, or order ID...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Order Status Dropdown
              SizedBox(
                width: isMobile ? 120 : 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Order Status',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Orders')),
                    DropdownMenuItem(value: 'received', child: Text('Received')),
                    DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                    DropdownMenuItem(value: 'processing', child: Text('Processing')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              // Payment Status Dropdown
              SizedBox(
                width: isMobile ? 120 : 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Payment Status',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Payments')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                  ],
                  onChanged: (val) => setState(() => _paymentFilter = val ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String preset) {
    final isSelected = _datePreset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.grey.shade100,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _setDatePreset(preset),
    );
  }

  // ── Hero KPI Metric Cards ────────────────────────────────────────────────────

  Widget _buildKpiMetricsGrid(
    bool isMobile,
    List<WhatsAppOrder> orders,
    List<CatalogProduct> products,
  ) {
    double totalRevenue = 0;
    double paidRevenue = 0;
    double pendingRevenue = 0;
    int paidOrdersCount = 0;

    for (final o in orders) {
      totalRevenue += o.totalAmount;
      if (o.paymentStatus == 'paid') {
        paidRevenue += o.totalAmount;
        paidOrdersCount++;
      } else {
        pendingRevenue += o.totalAmount;
      }
    }

    final totalOrdersCount = orders.length;
    final aov = totalOrdersCount > 0 ? (totalRevenue / totalOrdersCount) : 0.0;
    final inStockCount = products.where((p) => p.isAvailable).length;

    final cards = [
      _buildKpiCard(
        title: 'Total Orders',
        value: NumberFormat.compact().format(totalOrdersCount),
        subtitle: '$totalOrdersCount orders received',
        icon: Icons.shopping_bag_rounded,
        iconColor: const Color(0xFF6366F1),
      ),
      _buildKpiCard(
        title: 'Gross Revenue',
        value: '₹${NumberFormat('#,##0.00').format(totalRevenue)}',
        subtitle: 'Total cart value ordered',
        icon: Icons.currency_rupee_rounded,
        iconColor: const Color(0xFF10B981),
      ),
      _buildKpiCard(
        title: 'Collected Revenue',
        value: '₹${NumberFormat('#,##0.00').format(paidRevenue)}',
        subtitle: '$paidOrdersCount orders completed & paid',
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF059669),
      ),
      _buildKpiCard(
        title: 'Pending Amount',
        value: '₹${NumberFormat('#,##0.00').format(pendingRevenue)}',
        subtitle: 'Unpaid / pending payment links',
        icon: Icons.pending_actions_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
      _buildKpiCard(
        title: 'Avg Order Value (AOV)',
        value: '₹${NumberFormat('#,##0.00').format(aov)}',
        subtitle: 'Average per order',
        icon: Icons.trending_up_rounded,
        iconColor: const Color(0xFF0284C7),
      ),
      _buildKpiCard(
        title: 'Catalog Products',
        value: '${products.length}',
        subtitle: '$inStockCount in stock in Meta',
        icon: Icons.inventory_2_rounded,
        iconColor: const Color(0xFF8B5CF6),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: cards,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100 ? 6 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: cards,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D1E),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Visual Funnel & Top Selling Products ─────────────────────────────────────

  Widget _buildAnalyticsBreakdown(
    bool isMobile,
    List<WhatsAppOrder> orders,
    List<CatalogProduct> products,
  ) {
    if (isMobile) {
      return Column(
        children: [
          _buildOrderStatusFunnel(orders),
          const SizedBox(height: 16),
          _buildTopProductsCard(orders, products),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildOrderStatusFunnel(orders)),
        const SizedBox(width: 16),
        Expanded(flex: 7, child: _buildTopProductsCard(orders, products)),
      ],
    );
  }

  Widget _buildOrderStatusFunnel(List<WhatsAppOrder> orders) {
    final total = orders.isEmpty ? 1 : orders.length;
    final completed = orders.where((o) => o.status == 'completed').length;
    final processing =
        orders.where((o) => o.status == 'processing' || o.status == 'accepted').length;
    final received = orders.where((o) => o.status == 'received').length;
    final cancelled = orders.where((o) => o.status == 'cancelled').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                'Fulfillment Status Funnel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressRow('Completed', completed, total, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildProgressRow('Processing / Accepted', processing, total, const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildProgressRow('Received / Pending', received, total, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildProgressRow('Cancelled', cancelled, total, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, int count, int total, Color color) {
    final percent = total > 0 ? (count / total) : 0.0;
    final percentStr = (percent * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('$count ($percentStr%)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsCard(List<WhatsAppOrder> orders, List<CatalogProduct> products) {
    // Aggregate product sales
    final Map<String, int> qtyMap = {};
    final Map<String, double> revenueMap = {};

    for (final o in orders) {
      for (final item in o.items) {
        final sku = item.productRetailerId;
        qtyMap[sku] = (qtyMap[sku] ?? 0) + item.quantity;
        revenueMap[sku] = (revenueMap[sku] ?? 0.0) + (item.quantity * item.itemPrice);
      }
    }

    final sortedSkus = qtyMap.keys.toList()
      ..sort((a, b) => (revenueMap[b] ?? 0).compareTo(revenueMap[a] ?? 0));

    final topSkus = sortedSkus.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_rounded, size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text(
                'Top Performing Catalog Products',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (topSkus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No product orders recorded yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...topSkus.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final sku = entry.value;
              final qty = qtyMap[sku] ?? 0;
              final rev = revenueMap[sku] ?? 0.0;

              // Find product details
              final matchedProduct = products.cast<CatalogProduct?>().firstWhere(
                    (p) => p?.retailerId == sku,
                    orElse: () => null,
                  );

              final name = matchedProduct?.name.isNotEmpty == true
                  ? matchedProduct!.name
                  : 'SKU: $sku';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? const Color(0xFFFEF3C7)
                            : (rank == 2 ? Colors.grey.shade200 : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: rank == 1 ? const Color(0xFFD97706) : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'SKU: $sku  •  $qty units sold',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##0.00').format(rev)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Detailed Orders Table Section ────────────────────────────────────────────

  Widget _buildOrdersTableSection(bool isMobile, List<WhatsAppOrder> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Text(
                  'Orders & Inquiries Log',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D1E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${orders.length} Records',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No orders match the selected filters.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final order = orders[i];
                return _buildOrderRow(order, isMobile);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(WhatsAppOrder order, bool isMobile) {
    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!)
        : 'Unknown Date';

    final totalFormatted = '₹${NumberFormat('#,##0.00').format(order.totalAmount)}';
    final itemsCount = order.items.fold<int>(0, (sum, it) => sum + it.quantity);

    return InkWell(
      onTap: () => _showOrderDetailDialog(context, order),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 14),
        child: Row(
          children: [
            // Order Icon & ID
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF4B5563)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: isMobile ? 2 : 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${order.id.length > 8 ? order.id.substring(order.id.length - 8) : order.id}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($itemsCount ${itemsCount == 1 ? 'item' : 'items'})',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            // Customer Phone
            if (!isMobile)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          order.contactId,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (order.contactName.isNotEmpty)
                      Text(
                        order.contactName,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

            // Amount
            Expanded(
              flex: 2,
              child: Text(
                totalFormatted,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ),

            // Payment Badge
            _buildPaymentStatusBadge(order.paymentStatus),
            const SizedBox(width: 8),

            // Order Status Badge
            _buildOrderStatusBadge(order.status),
            const SizedBox(width: 8),

            // Action: View Detail icon
            IconButton(
              tooltip: 'View Report Details',
              onPressed: () => _showOrderDetailDialog(context, order),
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Paid';
        break;
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Failed';
        break;
      case 'refunded':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'Refunded';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Completed';
        break;
      case 'processing':
      case 'accepted':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        label = status == 'accepted' ? 'Accepted' : 'Processing';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        label = 'Received';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ── Drill-down Detail Dialog ─────────────────────────────────────────────────

  void _showOrderDetailDialog(BuildContext context, WhatsAppOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => _CatalogOrderDetailDialog(order: order),
    );
  }
}

// ── Detail Drill-Down Dialog (like CampaignReportDialog) ──────────────────────

class _CatalogOrderDetailDialog extends StatefulWidget {
  final WhatsAppOrder order;
  const _CatalogOrderDetailDialog({required this.order});

  @override
  State<_CatalogOrderDetailDialog> createState() => _CatalogOrderDetailDialogState();
}

class _CatalogOrderDetailDialogState extends State<_CatalogOrderDetailDialog> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final repo = context.read<CatalogBloc>();
      // Trigger status update
      await context
          .read<CatalogBloc>()
          .repository
          .updateOrderStatus(widget.order.id, newStatus);
      setState(() => _currentStatus = newStatus);
      repo.add(LoadOrders());
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Order status updated to $newStatus');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to update status: $e');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _sendPaymentLink() async {
    setState(() => _isUpdating = true);
    try {
      context.read<CatalogBloc>().add(SendOrderPaymentLinkEvent(widget.order.id));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsPaid() async {
    setState(() => _isUpdating = true);
    try {
      context.read<CatalogBloc>().add(MarkOrderPaidEvent(widget.order.id));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!)
        : 'Unknown Date';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Report: #${order.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 16, color: Color(0xFF4B5563)),
                              const SizedBox(width: 8),
                              const Text('Customer Details',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  final clean = order.contactId.replaceAll(RegExp(r'[^0-9]'), '');
                                  webOpenUrl('https://wa.me/$clean');
                                },
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                label: const Text('Open WhatsApp Chat', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Phone: ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              Text(order.contactId,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 12),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Copy Phone',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: order.contactId));
                                  SnackbarUtils.showSuccess(context, 'Phone copied');
                                },
                              ),
                            ],
                          ),
                          if (order.contactName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Name: ${order.contactName}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                          if (order.customerNote.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.notes_rounded,
                                      size: 14, color: Colors.amber.shade800),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Note: ${order.customerNote}',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Products Itemized Table
                    const Text('Itemized Products Ordered',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ...order.items.asMap().entries.map((entry) {
                            final item = entry.value;
                            final isLast = entry.key == order.items.length - 1;
                            final lineTotal = item.itemPrice * item.quantity;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined,
                                        size: 18, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SKU: ${item.productRetailerId}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        Text(
                                          '₹${item.itemPrice.toStringAsFixed(2)} × ${item.quantity}',
                                          style: TextStyle(
                                              fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Total & Payment Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(
                                '₹${NumberFormat('#,##0.00').format(order.totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment Status:', style: TextStyle(fontSize: 12)),
                              Text(
                                order.paymentStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: order.paymentStatus == 'paid'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          if (order.paymentLinkId != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment Link ID:', style: TextStyle(fontSize: 11)),
                                Text(order.paymentLinkId!,
                                    style: const TextStyle(
                                        fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Update Status Section
                    Row(
                      children: [
                        const Text('Change Status: ',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _currentStatus,
                          items: const [
                            DropdownMenuItem(value: 'received', child: Text('Received')),
                            DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                            DropdownMenuItem(value: 'processing', child: Text('Processing')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: _isUpdating
                              ? null
                              : (newVal) {
                                  if (newVal != null && newVal != _currentStatus) {
                                    _updateStatus(newVal);
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Dialog Footer Actions
            Row(
              children: [
                if (order.paymentStatus != 'paid') ...[
                  OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _markAsPaid,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Mark Paid'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _sendPaymentLink,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Send Payment Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
