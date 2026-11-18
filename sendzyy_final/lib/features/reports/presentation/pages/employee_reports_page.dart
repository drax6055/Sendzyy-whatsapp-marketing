import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/campaign_report_dialog.dart';

class EmployeeReportsPage extends StatefulWidget {
  const EmployeeReportsPage({super.key});

  @override
  State<EmployeeReportsPage> createState() => _EmployeeReportsPageState();
}

class _EmployeeReportsPageState extends State<EmployeeReportsPage> {
  final Dio _dio = getIt<Dio>();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _employees = [];

  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  String _sortBy = 'campaigns'; // 'campaigns', 'delivery', 'chats', 'name'
  bool _isTableView = false;

  DateTimeRange? _selectedDateRange;
  String _datePreset = 'all'; // 'all', 'today', 'week', 'month', 'custom'

  static const Map<String, IconData> _moduleIcons = {
    'chat': Icons.forum_rounded,
    'broadcast': Icons.send_rounded,
    'templates': Icons.copy_rounded,
    'clients': Icons.people_alt_rounded,
    'leads': Icons.contacts_rounded,
    'reports': Icons.bar_chart_rounded,
    'chatbot': Icons.smart_toy_rounded,
    'catalog': Icons.storefront_rounded,
    'whatsapp_flows': Icons.schema_rounded,
    'instagram': Icons.camera_alt_outlined,
    'help': Icons.help_outline_rounded,
  };

  static const Map<String, String> _moduleLabels = {
    'chat': 'Live Chat',
    'broadcast': 'Broadcast',
    'templates': 'Templates',
    'clients': 'Clients',
    'leads': 'Leads',
    'reports': 'Reports',
    'chatbot': 'Chatbot',
    'catalog': 'Catalog',
    'whatsapp_flows': 'WhatsApp Flows',
    'instagram': 'Instagram',
    'help': 'Q & A',
  };

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != 'all') {
        queryParams['status'] = _statusFilter;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }
      if (_selectedDateRange != null) {
        queryParams['startDate'] = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        queryParams['endDate'] = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }

      final response = await _dio.get(
        '/api/employees/reports/analytics',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _summary = Map<String, dynamic>.from(response.data['summary'] ?? {});
          _employees = List<Map<String, dynamic>>.from(response.data['employees'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? 'Failed to load employee analytics';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading analytics: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedEmployees {
    List<Map<String, dynamic>> list = List.from(_employees);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((emp) {
        final name = (emp['name'] ?? '').toString().toLowerCase();
        final email = (emp['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    if (_statusFilter != 'all') {
      list = list.where((emp) => emp['status'] == _statusFilter).toList();
    }

    list.sort((a, b) {
      final statsA = (a['stats'] as Map<String, dynamic>?) ?? {};
      final statsB = (b['stats'] as Map<String, dynamic>?) ?? {};

      switch (_sortBy) {
        case 'campaigns':
          final ca = (statsA['campaignsCount'] as num? ?? 0).toInt();
          final cb = (statsB['campaignsCount'] as num? ?? 0).toInt();
          return cb.compareTo(ca);
        case 'delivery':
          final da = (statsA['deliveryRate'] as num? ?? 0).toDouble();
          final db = (statsB['deliveryRate'] as num? ?? 0).toDouble();
          return db.compareTo(da);
        case 'chats':
          final cha = (statsA['assignedChatsCount'] as num? ?? 0).toInt();
          final chb = (statsB['assignedChatsCount'] as num? ?? 0).toInt();
          return chb.compareTo(cha);
        case 'name':
        default:
          final na = (a['name'] ?? '').toString().toLowerCase();
          final nb = (b['name'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
      }
    });

    return list;
  }

  void _setDatePreset(String preset) {
    setState(() {
      _datePreset = preset;
      final now = DateTime.now();
      switch (preset) {
        case 'today':
          _selectedDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day, 23, 59, 59),
          );
          break;
        case 'week':
          _selectedDateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          );
          break;
        case 'month':
          _selectedDateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
          break;
        case 'all':
        default:
          _selectedDateRange = null;
          break;
      }
    });
    _fetchAnalytics();
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showCompactDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() {
        _datePreset = 'custom';
        _selectedDateRange = range;
      });
      _fetchAnalytics();
    }
  }

  Future<void> _exportTeamReportCsv() async {
    if (_employees.isEmpty) return;

    final rows = <List<String>>[];
    // Header
    rows.add([
      'Employee Name',
      'Email',
      'Role',
      'Status',
      'Campaigns Created',
      'Total Sent',
      'Total Delivered',
      'Total Read',
      'Total Failed',
      'Delivery Rate (%)',
      'Read Rate (%)',
      'Assigned Chats',
      'Outbound Messages Sent',
      'Join Date',
      'Last Login',
    ]);

    for (final emp in _filteredAndSortedEmployees) {
      final stats = (emp['stats'] as Map<String, dynamic>?) ?? {};
      final joinDate = emp['createdAt'] != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(emp['createdAt']))
          : '-';
      final lastLogin = emp['lastLogin'] != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(emp['lastLogin']))
          : 'Never';

      rows.add([
        emp['name'] ?? '',
        emp['email'] ?? '',
        (emp['role'] ?? 'employee').toString().toUpperCase(),
        emp['status'] ?? 'active',
        '${stats['campaignsCount'] ?? 0}',
        '${stats['totalSent'] ?? 0}',
        '${stats['totalDelivered'] ?? 0}',
        '${stats['totalRead'] ?? 0}',
        '${stats['totalFailed'] ?? 0}',
        '${stats['deliveryRate'] ?? 0}%',
        '${stats['readRate'] ?? 0}%',
        '${stats['assignedChatsCount'] ?? 0}',
        '${stats['chatMessagesSentCount'] ?? 0}',
        joinDate,
        lastLogin,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);
    final fileName = 'employee_reports_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    await webDownloadBytes(bytes, fileName, mimeType: 'text/csv;charset=utf-8');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee report exported: $fileName'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  Future<void> _exportSingleEmployeeCsv(Map<String, dynamic> employee) async {
    try {
      final empId = employee['id'] ?? employee['_id'];
      final res = await _dio.get('/api/employees/$empId/report');
      if (res.statusCode != 200 || res.data['success'] != true) {
        throw Exception(res.data['error'] ?? 'Failed to fetch details');
      }

      final data = res.data;
      final emp = data['employee'] ?? employee;
      final stats = data['stats'] ?? {};
      final campaigns = List<Map<String, dynamic>>.from(data['campaigns'] ?? []);
      final convs = List<Map<String, dynamic>>.from(data['conversations'] ?? []);

      final rows = <List<String>>[];
      rows.add(['EMPLOYEE REPORT SUMMARY']);
      rows.add(['Name', emp['name'] ?? '']);
      rows.add(['Email', emp['email'] ?? '']);
      rows.add(['Role', (emp['role'] ?? 'employee').toString().toUpperCase()]);
      rows.add(['Status', emp['status'] ?? 'active']);
      rows.add(['Campaigns Count', '${stats['campaignsCount'] ?? 0}']);
      rows.add(['Total Sent', '${stats['totalSent'] ?? 0}']);
      rows.add(['Total Delivered', '${stats['totalDelivered'] ?? 0}']);
      rows.add(['Total Read', '${stats['totalRead'] ?? 0}']);
      rows.add(['Total Failed', '${stats['totalFailed'] ?? 0}']);
      rows.add(['Delivery Rate', '${stats['deliveryRate'] ?? 0}%']);
      rows.add(['Assigned Chats', '${stats['assignedChatsCount'] ?? 0}']);
      rows.add([]);

      rows.add(['BROADCAST CAMPAIGNS LAUNCHED BY EMPLOYEE']);
      rows.add(['Campaign ID', 'Template', 'Sent At', 'Total Sent', 'Delivered', 'Read', 'Failed', 'Status']);
      for (final c in campaigns) {
        final sentAt = c['timestamp'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(c['timestamp']))
            : '-';
        rows.add([
          '${c['id']}',
          '${c['template'] ?? '-'}',
          sentAt,
          '${c['totalCount'] ?? 0}',
          '${c['deliveredCount'] ?? 0}',
          '${c['readCount'] ?? 0}',
          '${c['failureCount'] ?? 0}',
          '${c['status'] ?? 'completed'}',
        ]);
      }
      rows.add([]);

      rows.add(['ASSIGNED CONVERSATIONS']);
      rows.add(['Contact Number', 'Name', 'Last Active', 'Last Message Preview']);
      for (final cv in convs) {
        final lastActive = cv['lastActive'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(cv['lastActive']))
            : '-';
        rows.add([
          '${cv['contactId']}',
          '${cv['name'] ?? '-'}',
          lastActive,
          (cv['lastMessage'] ?? '').toString().replaceAll('\n', ' '),
        ]);
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvString);
      final safeName = (emp['name'] ?? 'employee').toString().replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${safeName}_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

      await webDownloadBytes(bytes, fileName, mimeType: 'text/csv;charset=utf-8');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported report for ${emp['name']}'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export employee report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEmployeeDetailDialog(Map<String, dynamic> initialEmployee) {
    showDialog(
      context: context,
      builder: (ctx) => _EmployeeDetailModal(
        employeeId: initialEmployee['id'] ?? initialEmployee['_id'],
        initialData: initialEmployee,
        onExportCsv: () => _exportSingleEmployeeCsv(initialEmployee),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 20 : 32)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile: isMobile, isTablet: isTablet),
              const SizedBox(height: 20),
              if (_summary != null) _buildKpiCardsGrid(isMobile: isMobile, isTablet: isTablet),
              const SizedBox(height: 24),
              _buildFilterAndSearchRow(isMobile: isMobile),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _buildErrorCard()
              else if (_filteredAndSortedEmployees.isEmpty)
                _buildEmptyState()
              else if (_isTableView && !isMobile)
                _buildTableView()
              else
                _buildCardsGrid(isMobile: isMobile, isTablet: isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isMobile, required bool isTablet}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Employee Reports',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Comprehensive broadcast campaigns, live conversations, and delivery metrics across all team members.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export CSV'),
                    onPressed: _exportTeamReportCsv,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                    tooltip: 'Reload analytics',
                    onPressed: _fetchAnalytics,
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Date Presets Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDatePresetChip('all', 'All Time'),
              const SizedBox(width: 6),
              _buildDatePresetChip('today', 'Today'),
              const SizedBox(width: 6),
              _buildDatePresetChip('week', 'Last 7 Days'),
              const SizedBox(width: 6),
              _buildDatePresetChip('month', 'Last 30 Days'),
              const SizedBox(width: 6),
              ActionChip(
                backgroundColor: _datePreset == 'custom'
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Colors.white,
                side: BorderSide(
                  color: _datePreset == 'custom' ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                ),
                avatar: Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: _datePreset == 'custom' ? AppTheme.primaryColor : const Color(0xFF64748B),
                ),
                label: Text(
                  _selectedDateRange != null && _datePreset == 'custom'
                      ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}'
                      : 'Custom Range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _datePreset == 'custom' ? FontWeight.bold : FontWeight.w500,
                    color: _datePreset == 'custom' ? AppTheme.primaryColor : const Color(0xFF334155),
                  ),
                ),
                onPressed: _pickCustomDateRange,
              ),
              if (isMobile) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  tooltip: 'Export CSV',
                  onPressed: _exportTeamReportCsv,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Reload',
                  onPressed: _fetchAnalytics,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePresetChip(String key, String label) {
    final isSelected = _datePreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setDatePreset(key),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : const Color(0xFF475569),
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildKpiCardsGrid({required bool isMobile, required bool isTablet}) {
    final s = _summary ?? {};
    final totalEmployees = s['totalEmployees'] ?? 0;
    final activeEmployees = s['activeEmployees'] ?? 0;
    final totalCampaigns = s['totalCampaignsByTeam'] ?? 0;
    final totalSent = s['totalSentByTeam'] ?? 0;
    final totalDelivered = s['totalDeliveredByTeam'] ?? 0;
    final deliveryRate = s['overallDeliveryRate'] ?? 0.0;
    final totalAssignedChats = s['totalAssignedChatsByTeam'] ?? 0;
    final totalChatMessages = s['totalChatMessagesSentByTeam'] ?? 0;

    final cards = [
      _KpiCard(
        title: 'Team Members',
        value: '$totalEmployees',
        subtext: '$activeEmployees Active member${activeEmployees == 1 ? '' : 's'}',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF2563EB),
      ),
      _KpiCard(
        title: 'Broadcast Campaigns',
        value: '$totalCampaigns',
        subtext: 'Created by team members',
        icon: Icons.send_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _KpiCard(
        title: 'Messages Dispatched',
        value: '$totalSent',
        subtext: '$totalDelivered Delivered ($deliveryRate%)',
        icon: Icons.mark_email_read_rounded,
        color: const Color(0xFF059669),
      ),
      _KpiCard(
        title: 'Assigned Chats',
        value: '$totalAssignedChats',
        subtext: '$totalChatMessages Outbound chat replies',
        icon: Icons.forum_rounded,
        color: const Color(0xFFD97706),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
      );
    }

    final crossAxisCount = isTablet ? 2 : 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildFilterAndSearchRow({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search employee by name or email...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(width: 8),

          // Status filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active Only')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive Only')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sort dropdown
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  icon: const Icon(Icons.sort_rounded, size: 18),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'campaigns', child: Text('Most Campaigns')),
                    DropdownMenuItem(value: 'delivery', child: Text('Highest Delivery Rate')),
                    DropdownMenuItem(value: 'chats', child: Text('Most Assigned Chats')),
                    DropdownMenuItem(value: 'name', child: Text('Name (A-Z)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // View Mode Toggle (Card vs Table)
            IconButton(
              icon: Icon(
                _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              tooltip: _isTableView ? 'Switch to Card Grid' : 'Switch to Data Table',
              onPressed: () => setState(() => _isTableView = !_isTableView),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardsGrid({required bool isMobile, required bool isTablet}) {
    final employees = _filteredAndSortedEmployees;
    final crossAxisCount = isMobile ? 1 : (isTablet ? 1 : 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: employees.map((emp) {
            return SizedBox(
              width: itemWidth,
              child: _EmployeeReportCard(
                employee: emp,
                onViewReport: () => _showEmployeeDetailDialog(emp),
                onExportCsv: () => _exportSingleEmployeeCsv(emp),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTableView() {
    final employees = _filteredAndSortedEmployees;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingTextStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
            dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Campaigns')),
              DataColumn(label: Text('Messages Sent')),
              DataColumn(label: Text('Delivered')),
              DataColumn(label: Text('Delivery Rate')),
              DataColumn(label: Text('Assigned Chats')),
              DataColumn(label: Text('Actions')),
            ],
            rows: employees.map((emp) {
              final stats = (emp['stats'] as Map<String, dynamic>?) ?? {};
              final isActive = emp['status'] == 'active';
              final deliveryRate = stats['deliveryRate'] ?? 0;

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            (emp['name'] ?? 'E').toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emp['name'] ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              emp['email'] ?? '-',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : Colors.grey.shade300),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF065F46) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text((emp['role'] ?? 'employee').toString().toUpperCase(), style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${stats['campaignsCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${stats['totalSent'] ?? 0}')),
                  DataCell(Text('${stats['totalDelivered'] ?? 0}', style: const TextStyle(color: Color(0xFF059669)))),
                  DataCell(
                    Text(
                      '$deliveryRate%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: deliveryRate >= 70 ? const Color(0xFF059669) : Colors.amber.shade800,
                      ),
                    ),
                  ),
                  DataCell(Text('${stats['assignedChatsCount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.primaryColor),
                          tooltip: 'View Report Details',
                          onPressed: () => _showEmployeeDetailDialog(emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                          tooltip: 'Export CSV',
                          onPressed: () => _exportSingleEmployeeCsv(emp),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No employees found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No team members matched your search criteria.'
                  : 'Add employees under Team Members to see performance analytics here.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: _fetchAnalytics,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP KPI STAT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE REPORT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeReportCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onViewReport;
  final VoidCallback onExportCsv;

  const _EmployeeReportCard({
    required this.employee,
    required this.onViewReport,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    final name = employee['name'] ?? '-';
    final email = employee['email'] ?? '-';
    final role = (employee['role'] ?? 'employee').toString().toUpperCase();
    final isActive = employee['status'] == 'active';
    final stats = (employee['stats'] as Map<String, dynamic>?) ?? {};

    final campaignsCount = stats['campaignsCount'] ?? 0;
    final totalSent = stats['totalSent'] ?? 0;
    final totalDelivered = stats['totalDelivered'] ?? 0;
    final totalRead = stats['totalRead'] ?? 0;
    final totalFailed = stats['totalFailed'] ?? 0;
    final deliveryRate = stats['deliveryRate'] ?? 0;
    final assignedChats = stats['assignedChatsCount'] ?? 0;
    final permissions = List<String>.from(employee['permissions'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : Colors.grey.shade300),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? const Color(0xFF065F46) : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Stat Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Campaigns', '$campaignsCount', const Color(0xFF7C3AED), Icons.send_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Total Sent', '$totalSent', const Color(0xFF2563EB), Icons.mark_email_read_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Delivered', '$totalDelivered ($deliveryRate%)', const Color(0xFF059669), Icons.check_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Read', '$totalRead', const Color(0xFFD97706), Icons.remove_red_eye_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Failed', '$totalFailed', const Color(0xFFDC2626), Icons.error_outline_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile('Assigned Chats', '$assignedChats', const Color(0xFF0891B2), Icons.forum_rounded),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Permissions Chips
          if (permissions.isNotEmpty) ...[
            Text(
              'Authorized Modules (${permissions.length}):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissions.take(5).map((p) {
                final label = _EmployeeReportsPageState._moduleLabels[p] ?? p;
                final icon = _EmployeeReportsPageState._moduleIcons[p];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 11, color: const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                      ],
                      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }).toList()..addAll(
                permissions.length > 5
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${permissions.length - 5}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        )
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('View Full Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: onViewReport,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF475569)),
                tooltip: 'Export Employee CSV',
                onPressed: onExportCsv,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAILED EMPLOYEE REPORT MODAL
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeDetailModal extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> initialData;
  final VoidCallback onExportCsv;

  const _EmployeeDetailModal({
    required this.employeeId,
    required this.initialData,
    required this.onExportCsv,
  });

  @override
  State<_EmployeeDetailModal> createState() => _EmployeeDetailModalState();
}

class _EmployeeDetailModalState extends State<_EmployeeDetailModal> with SingleTickerProviderStateMixin {
  final Dio _dio = getIt<Dio>();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dio.get('/api/employees/${widget.employeeId}/report');
      if (res.statusCode == 200 && res.data['success'] == true) {
        setState(() {
          _reportData = Map<String, dynamic>.from(res.data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data['error'] ?? 'Failed to load report';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading report: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = _reportData?['employee'] ?? widget.initialData;
    final name = emp['name'] ?? '-';
    final email = emp['email'] ?? '-';
    final stats = _reportData?['stats'] ?? widget.initialData['stats'] ?? {};
    final campaigns = List<Map<String, dynamic>>.from(_reportData?['campaigns'] ?? []);
    final convs = List<Map<String, dynamic>>.from(_reportData?['conversations'] ?? []);
    final permissions = List<String>.from(emp['permissions'] ?? []);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'E',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name — Detailed Report',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                      onPressed: widget.onExportCsv,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top Stat Bar for this Employee
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Campaigns', '${stats['campaignsCount'] ?? 0}'),
                  _buildStatItem('Messages Sent', '${stats['totalSent'] ?? 0}'),
                  _buildStatItem('Delivered', '${stats['totalDelivered'] ?? 0}', color: const Color(0xFF059669)),
                  _buildStatItem('Delivery Rate', '${stats['deliveryRate'] ?? 0}%', color: AppTheme.primaryColor),
                  _buildStatItem('Failed', '${stats['totalFailed'] ?? 0}', color: Colors.red),
                  _buildStatItem('Assigned Chats', '${stats['assignedChatsCount'] ?? 0}'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Navigation
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Broadcast Campaigns (${campaigns.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.forum_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Assigned Chats (${convs.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Permissions & Info (${permissions.length})'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Campaigns Table
                            _buildCampaignsTab(campaigns),
                            // Tab 2: Conversations List
                            _buildConversationsTab(convs),
                            // Tab 3: Permissions & Info
                            _buildPermissionsTab(emp, permissions),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCampaignsTab(List<Map<String, dynamic>> campaigns) {
    if (campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('No campaigns launched yet by this employee', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1.2),
          6: FlexColumnWidth(1),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              _buildHeaderCell('Template / Name'),
              _buildHeaderCell('Sent At'),
              _buildHeaderCell('Sent'),
              _buildHeaderCell('Delivered'),
              _buildHeaderCell('Failed'),
              _buildHeaderCell('Status'),
              _buildHeaderCell('Action'),
            ],
          ),
          ...campaigns.map((c) {
            final sentAt = c['timestamp'] != null
                ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(c['timestamp']))
                : '-';
            final status = (c['status'] ?? 'completed').toString();

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text(
                    c['template'] ?? 'Campaign',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text(sentAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text('${c['totalCount'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text('${c['deliveredCount'] ?? 0}', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text('${c['failureCount'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'retrying'
                          ? Colors.amber.shade50
                          : (status == 'completed' ? const Color(0xFFECFDF5) : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: status == 'retrying'
                            ? Colors.amber.shade900
                            : (status == 'completed' ? const Color(0xFF065F46) : Colors.blue.shade800),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: IconButton(
                    icon: const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.primaryColor),
                    tooltip: 'View Campaign Phase Report',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => CampaignReportDialog(campaign: c),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConversationsTab(List<Map<String, dynamic>> convs) {
    if (convs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('No conversations currently assigned to this employee', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: convs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, i) {
        final c = convs[i];
        final lastActive = c['lastActive'] != null
            ? DateFormat('dd MMM, HH:mm').format(DateTime.parse(c['lastActive']))
            : '-';
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE2E8F0),
            radius: 16,
            child: const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
          ),
          title: Row(
            children: [
              Text(c['contactId'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (c['name'] != null && c['name'] != c['contactId']) ...[
                const SizedBox(width: 8),
                Text('(${c['name']})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
          subtitle: Text(
            c['lastMessage'] ?? 'No message',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          trailing: Text(lastActive, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        );
      },
    );
  }

  Widget _buildPermissionsTab(Map<String, dynamic> emp, List<String> permissions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Account ID', '${emp['id'] ?? emp['_id']}'),
          _buildInfoRow('Role', (emp['role'] ?? 'employee').toString().toUpperCase()),
          _buildInfoRow('Account Status', (emp['status'] ?? 'active').toString().toUpperCase()),
          _buildInfoRow('Created On', emp['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(emp['createdAt'])) : '-'),
          _buildInfoRow('Last Login', emp['lastLogin'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(emp['lastLogin'])) : 'Never'),
          const SizedBox(height: 20),
          const Text('Granted Module Permissions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _EmployeeReportsPageState._moduleLabels.entries.map((entry) {
              final key = entry.key;
              final label = entry.value;
              final hasPermission = permissions.contains(key) || key == 'reports';
              final icon = _EmployeeReportsPageState._moduleIcons[key];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasPermission ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPermission ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: hasPermission ? const Color(0xFF065F46) : Colors.grey.shade400),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasPermission ? FontWeight.w600 : FontWeight.normal,
                        color: hasPermission ? const Color(0xFF065F46) : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      hasPermission ? Icons.check_circle_rounded : Icons.cancel_outlined,
                      size: 14,
                      color: hasPermission ? const Color(0xFF059669) : Colors.grey.shade400,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
      ),
    );
  }
}
