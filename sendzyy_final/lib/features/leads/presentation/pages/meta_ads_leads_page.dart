import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/leads/presentation/widgets/meta_trigger_dialog.dart';

class MetaAdsLeadsPage extends StatefulWidget {
  const MetaAdsLeadsPage({super.key});

  @override
  State<MetaAdsLeadsPage> createState() => _MetaAdsLeadsPageState();
}

class _MetaAdsLeadsPageState extends State<MetaAdsLeadsPage> {
  final Dio _dio = getIt<Dio>();

  bool _loading = true;
  bool _syncingForm = false;
  String? _syncingFormId;
  String? _error;

  // Connection state
  bool _isConnected = false;
  Map<String, dynamic>? _connection;
  List<Map<String, dynamic>> _pages = [];
  List<Map<String, dynamic>> _forms = [];

  // Leads & Analytics
  List<Map<String, dynamic>> _leads = [];
  Map<String, dynamic> _analytics = {
    'total': 0,
    'today': 0,
    'contacted': 0,
    'engaged': 0,
    'converted': 0,
  };

  // Filters
  String _searchQuery = '';
  String _selectedAdType = 'all'; // all | instant_form | ctwa
  String _selectedPlatform = 'all'; // all | fb | ig
  String _selectedFormId = 'all';
  String _selectedStatus = 'all';
  DateTimeRange? _dateRange;

  // Accordion expansion state
  bool _pagesExpanded = false;

  final TextEditingController _searchController = TextEditingController();

  // Sendzyy Palette constants for consistent clean styling
  static const Color _metaBlue = Color(0xFF1877F2);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _bgSoft = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchMetaStatusAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetaStatusAndData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchStatus(),
        _fetchForms(),
        _fetchLeads(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await _dio.get('/api/meta/status');
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        _isConnected = data['isConnected'] == true;
        _connection = data['connection'] as Map<String, dynamic>?;
        _pages = (data['pages'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchForms() async {
    try {
      final res = await _dio.get('/api/meta/forms');
      if (res.statusCode == 200) {
        final list = (res.data['forms'] as List<dynamic>? ?? []);
        _forms = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchLeads() async {
    try {
      final queryParams = <String, dynamic>{
        'source': 'meta_ads',
      };
      if (_selectedAdType != 'all') queryParams['adType'] = _selectedAdType;
      if (_selectedPlatform != 'all') queryParams['platform'] = _selectedPlatform;
      if (_selectedFormId != 'all') queryParams['formId'] = _selectedFormId;
      if (_selectedStatus != 'all') queryParams['status'] = _selectedStatus;
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
      if (_dateRange != null) {
        queryParams['startDate'] = _dateRange!.start.toIso8601String();
        queryParams['endDate'] = _dateRange!.end.toIso8601String();
      }

      final res = await _dio.get('/api/leads', queryParameters: queryParams);
      if (res.statusCode == 200) {
        final rawLeads = (res.data['leads'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        _leads = rawLeads;

        // Compute local analytics
        final now = DateTime.now();
        int today = 0;
        int contacted = 0;
        int engaged = 0;
        int converted = 0;

        for (final l in _leads) {
          final dt = DateTime.tryParse(l['createdAt']?.toString() ?? '');
          if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            today++;
          }
          final st = l['status']?.toString();
          if (st == 'contacted') contacted++;
          if (st == 'engaged') engaged++;
          if (st == 'converted') converted++;
        }

        _analytics = {
          'total': _leads.length,
          'today': today,
          'contacted': contacted,
          'engaged': engaged,
          'converted': converted,
        };
      }
    } catch (_) {}
  }

  Future<void> _connectFacebook() async {
    try {
      final res = await _dio.get('/api/meta/connect-url');
      if (res.statusCode == 200 && res.data['url'] != null) {
        final url = res.data['url'] as String;
        webOpenUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Facebook Login opened in a new tab. Refresh here after authorizing.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate connection: $e')),
        );
      }
    }
  }

  Future<void> _testPageAccess(String pageDocId) async {
    try {
      final res = await _dio.post('/api/meta/pages/$pageDocId/test-access');
      if (mounted) {
        final data = res.data;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  data['healthy'] == true ? 'Connection Healthy' : 'Action Required',
                  style: const TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['message']?.toString() ?? 'Page token and permissions are active.',
                  style: const TextStyle(color: _textDark, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text('• Webhook Subscribed: ${data['isSubscribed'] == true ? "YES" : "NO"}',
                    style: const TextStyle(color: _textMuted, fontSize: 12)),
                Text('• Forms Discovered: ${data['formsDiscovered'] ?? 0}',
                    style: const TextStyle(color: _textMuted, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppTheme.secondaryColor)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Access Diagnostic Alert', style: TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'Diagnostic test returned error:\n\n$e\n\nEnsure user has "Leads Access" in Meta Business Settings.',
              style: const TextStyle(color: _textDark, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppTheme.secondaryColor)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _toggleFormSync(Map<String, dynamic> form) async {
    final id = form['_id'];
    final newVal = !(form['syncEnabled'] == true);
    try {
      await _dio.post('/api/meta/forms/$id/toggle-sync', data: {'syncEnabled': newVal});
      setState(() => form['syncEnabled'] = newVal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle sync: $e')),
        );
      }
    }
  }

  Future<void> _syncFormNow(Map<String, dynamic> form) async {
    final id = form['_id'];
    setState(() {
      _syncingForm = true;
      _syncingFormId = id;
    });

    try {
      final res = await _dio.post('/api/meta/forms/$id/sync-now');
      final msg = res.data['message'] ?? 'Sync complete';
      await _fetchLeads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.secondaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingForm = false;
          _syncingFormId = null;
        });
      }
    }
  }

  Future<void> _updateLeadStatus(String leadId, String newStatus) async {
    try {
      await _dio.patch('/api/leads/$leadId/status', data: {'status': newStatus});
      setState(() {
        final idx = _leads.indexWhere((l) => l['_id'] == leadId);
        if (idx != -1) _leads[idx]['status'] = newStatus;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update failed: $e')),
        );
      }
    }
  }

  void _showLeadDetailsDrawer(Map<String, dynamic> lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeadDetailsDrawer(lead: lead),
    );
  }

  void _openTriggersDialog() {
    showDialog(
      context: context,
      builder: (_) => MetaTriggerDialog(forms: _forms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _fetchMetaStatusAndData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(),
                    ],
                    const SizedBox(height: 18),
                    _buildConnectionBanner(isMobile),
                    const SizedBox(height: 18),
                    _buildPagesAccordion(),
                    const SizedBox(height: 18),
                    _buildKpiMetricsRow(isMobile),
                    const SizedBox(height: 18),
                    _buildFiltersCard(isMobile),
                    const SizedBox(height: 18),
                    _buildLeadsTableCard(isMobile),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'An unexpected error occurred while loading Meta leads data.',
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _fetchMetaStatusAndData,
            child: Text('Retry', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _metaBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(FontAwesomeIcons.facebook, color: _metaBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Meta Ads Leads',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textDark),
                ),
              ),
              IconButton(
                onPressed: _fetchMetaStatusAndData,
                icon: const Icon(Icons.refresh_rounded, color: _textMuted),
                tooltip: 'Refresh Leads',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Facebook & Instagram Instant Forms + Click-to-WhatsApp (CTWA) CRM Ingestion',
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openTriggersDialog,
              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.secondaryColor),
              label: const Text('Automation Rules'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.secondaryColor,
                side: const BorderSide(color: AppTheme.secondaryColor, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _metaBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const FaIcon(FontAwesomeIcons.facebook, color: _metaBlue, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meta Ads Leads',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
              ),
              SizedBox(height: 2),
              Text(
                'Facebook & Instagram Instant Forms + Click-to-WhatsApp (CTWA) CRM Ingestion',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openTriggersDialog,
          icon: const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.secondaryColor),
          label: const Text('Automation Rules'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.secondaryColor,
            side: const BorderSide(color: AppTheme.secondaryColor, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: _fetchMetaStatusAndData,
          icon: const Icon(Icons.refresh_rounded, color: _textMuted),
          tooltip: 'Refresh Leads',
        ),
      ],
    );
  }

  Widget _buildConnectionBanner(bool isMobile) {
    if (!_isConnected) {
      if (isMobile) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
                      color: _metaBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const FaIcon(FontAwesomeIcons.facebookF, color: _metaBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Connect Facebook & Instagram Pages',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Receive Instant Form lead submissions in real-time (< 3 seconds) and automatically dispatch approved WhatsApp greeting templates.',
                style: TextStyle(fontSize: 12, color: _textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _connectFacebook,
                  icon: const FaIcon(FontAwesomeIcons.facebook, size: 15),
                  label: const Text('Connect Facebook'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _metaBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _metaBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(FontAwesomeIcons.facebookF, color: _metaBlue, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Facebook & Instagram Pages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Receive Instant Form lead submissions in real-time (< 3 seconds) and automatically dispatch approved WhatsApp greeting templates.',
                    style: TextStyle(fontSize: 12, color: _textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _connectFacebook,
              icon: const FaIcon(FontAwesomeIcons.facebook, size: 16),
              label: const Text('Connect Facebook'),
              style: FilledButton.styleFrom(
                backgroundColor: _metaBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final fbUser = _connection?['fbUserName'] ?? 'Authorized User';

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connected as $fbUser',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Webhook Active',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_pages.length} Connected Page(s) • ${_forms.length} Instant Form(s) registered',
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _connectFacebook,
                icon: const Icon(Icons.sync_rounded, size: 16, color: _metaBlue),
                label: const Text('Reconnect / Refresh', style: TextStyle(color: _metaBlue, fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Connected as $fbUser',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Webhook Active',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pages.length} Connected Page(s) • ${_forms.length} Instant Form(s) registered',
                  style: const TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _connectFacebook,
            icon: const Icon(Icons.sync_rounded, size: 16, color: _metaBlue),
            label: const Text('Reconnect / Refresh', style: TextStyle(color: _metaBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesAccordion() {
    if (_pages.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: _pagesExpanded,
        onExpansionChanged: (v) => setState(() => _pagesExpanded = v),
        title: Row(
          children: [
            const Icon(Icons.view_list_rounded, size: 20, color: _metaBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connected Facebook Pages & Instant Forms (${_pages.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(color: _borderColor),
          for (final page in _pages) ...[
            _buildPageCard(page),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildPageCard(Map<String, dynamic> page) {
    final pageId = page['pageId']?.toString() ?? '';
    final pageName = page['pageName']?.toString() ?? 'Facebook Page';
    final isSubscribed = page['isSubscribed'] == true;
    final pageForms = _forms.where((f) => f['pageId'] == pageId).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.facebook, size: 18, color: _metaBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pageName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textDark)),
                    Text('Page ID: $pageId', style: const TextStyle(fontSize: 11, color: _textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSubscribed ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSubscribed ? Colors.green.shade200 : Colors.amber.shade200),
                ),
                child: Text(
                  isSubscribed ? 'Subscribed' : 'Not Subscribed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSubscribed ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _testPageAccess(page['id']),
                icon: const Icon(Icons.health_and_safety_outlined, size: 14, color: AppTheme.secondaryColor),
                label: const Text('Test Access', style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (pageForms.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: _borderColor),
            const SizedBox(height: 8),
            Text(
              'Instant Forms (${pageForms.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
            ),
            const SizedBox(height: 8),
            for (final f in pageForms) _buildFormRow(f),
          ],
        ],
      ),
    );
  }

  Widget _buildFormRow(Map<String, dynamic> form) {
    final formName = form['name'] ?? 'Instant Form';
    final formId = form['formId'] ?? '';
    final isSyncEnabled = form['syncEnabled'] == true;
    final isSyncing = _syncingForm && _syncingFormId == form['_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, size: 16, color: _textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                Text('ID: $formId', style: const TextStyle(fontSize: 10, color: _textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                isSyncEnabled ? 'Sync Enabled' : 'Sync Paused',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSyncEnabled ? AppTheme.secondaryColor : _textMuted,
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: isSyncEnabled,
                  onChanged: (_) => _toggleFormSync(form),
                  activeThumbColor: AppTheme.primaryColor,
                  activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isSyncing ? null : () => _syncFormNow(form),
                icon: isSyncing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 14),
                label: const Text('Sync now', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsRow(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiCard('Total Meta Leads', _analytics['total'].toString(), Icons.campaign_rounded, _metaBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard('Leads Today', _analytics['today'].toString(), Icons.today_rounded, AppTheme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard('Contacted', _analytics['contacted'].toString(), Icons.send_rounded, Colors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard('Engaged (Replied)', _analytics['engaged'].toString(), Icons.forum_rounded, Colors.orange.shade800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildKpiCard('Converted', _analytics['converted'].toString(), Icons.verified_rounded, AppTheme.secondaryColor),
        ],
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = (constraints.maxWidth - 48) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard('Total Meta Leads', _analytics['total'].toString(), Icons.campaign_rounded, _metaBlue, width: width),
            _buildKpiCard('Leads Today', _analytics['today'].toString(), Icons.today_rounded, AppTheme.accentColor, width: width),
            _buildKpiCard('Contacted (Templates)', _analytics['contacted'].toString(), Icons.send_rounded, Colors.purple, width: width),
            _buildKpiCard('Engaged (Replied)', _analytics['engaged'].toString(), Icons.forum_rounded, Colors.orange.shade800, width: width),
            _buildKpiCard('Converted', _analytics['converted'].toString(), Icons.verified_rounded, AppTheme.secondaryColor, width: width),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {double? width}) {
    return Container(
      width: width != null ? (width < 160 ? 160 : width) : double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            TextField(
              controller: _searchController,
              style: const TextStyle(color: _textDark, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: _textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: _textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchLeads();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _bgSoft,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onSubmitted: (v) {
                setState(() => _searchQuery = v.trim());
                _fetchLeads();
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range_rounded, size: 16, color: _textDark),
                label: Text(
                  _dateRange != null
                      ? '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}'
                      : 'Date Range',
                  style: const TextStyle(fontSize: 12, color: _textDark),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final picked = await showCompactDateRangePicker(
                    context: context,
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) {
                    setState(() => _dateRange = picked);
                    _fetchLeads();
                  }
                },
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _textDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search leads by name, phone, email, campaign, ad...',
                      hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: _textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: _textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _fetchLeads();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: _bgSoft,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (v) {
                      setState(() => _searchQuery = v.trim());
                      _fetchLeads();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded, size: 16, color: _textDark),
                  label: Text(
                    _dateRange != null
                        ? '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}'
                        : 'Date Range',
                    style: const TextStyle(fontSize: 12, color: _textDark),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final picked = await showCompactDateRangePicker(
                      context: context,
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                      _fetchLeads();
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdownFilter(
                label: 'Type',
                value: _selectedAdType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'instant_form', child: Text('Instant Forms')),
                  DropdownMenuItem(value: 'ctwa', child: Text('Click-to-WhatsApp')),
                ],
                onChanged: (v) {
                  setState(() => _selectedAdType = v!);
                  _fetchLeads();
                },
              ),
              _buildDropdownFilter(
                label: 'Platform',
                value: _selectedPlatform,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Platforms')),
                  DropdownMenuItem(value: 'fb', child: Text('Facebook')),
                  DropdownMenuItem(value: 'ig', child: Text('Instagram')),
                ],
                onChanged: (v) {
                  setState(() => _selectedPlatform = v!);
                  _fetchLeads();
                },
              ),
              if (_forms.isNotEmpty)
                _buildDropdownFilter(
                  label: 'Form',
                  value: _selectedFormId,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Forms')),
                    ..._forms.map((f) => DropdownMenuItem(
                          value: f['formId']?.toString() ?? '',
                          child: Text(
                            f['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedFormId = v!);
                    _fetchLeads();
                  },
                ),
              _buildDropdownFilter(
                label: 'Status',
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                  DropdownMenuItem(value: 'engaged', child: Text('Engaged')),
                  DropdownMenuItem(value: 'converted', child: Text('Converted')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                ],
                onChanged: (v) {
                  setState(() => _selectedStatus = v!);
                  _fetchLeads();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: Colors.white,
          style: const TextStyle(fontSize: 12, color: _textDark),
          icon: const Icon(Icons.arrow_drop_down, color: _textMuted, size: 18),
        ),
      ),
    );
  }

  Widget _buildLeadsTableCard(bool isMobile) {
    if (_leads.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Meta Ads Leads Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery"'
                  : 'Instant Form submissions from Facebook & Instagram will display here within seconds.',
              style: const TextStyle(fontSize: 13, color: _textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Meta Leads (${_leads.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
            ),
          ),
          for (final lead in _leads) ...[
            _buildMobileLeadCard(lead),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meta Leads (${_leads.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                ),
                const Text(
                  'Auto-synced via Meta Webhooks & Graph API v26.0',
                  style: TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _borderColor),
          LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth > 950 ? constraints.maxWidth : 950.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: DataTable(
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 68,
                    columnSpacing: 16,
                    horizontalMargin: 20,
                    headingRowColor: WidgetStateProperty.all(_bgSoft),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: _textDark, fontSize: 13),
                    columns: const [
                      DataColumn(
                        label: Text('Contact'),
                        columnWidth: FlexColumnWidth(2.3),
                      ),
                      DataColumn(
                        label: Text('Type & Platform'),
                        columnWidth: FlexColumnWidth(1.5),
                      ),
                      DataColumn(
                        label: Text('Form / Campaign'),
                        columnWidth: FlexColumnWidth(2.4),
                      ),
                      DataColumn(
                        label: Text('Submission Date'),
                        columnWidth: FlexColumnWidth(1.8),
                      ),
                      DataColumn(
                        label: Text('Status'),
                        columnWidth: FlexColumnWidth(1.2),
                      ),
                      DataColumn(
                        label: Text('Actions'),
                        columnWidth: FlexColumnWidth(1.0),
                      ),
                    ],
                    rows: _leads.map((lead) {
                      final name = lead['name']?.toString() ?? 'Unnamed Lead';
                      final phone = lead['mobileNumber']?.toString() ?? '';
                      final needsAttention = lead['needsAttention'] == true;
                      final adType = lead['adType']?.toString() ?? (lead['meta']?['adType']?.toString() ?? 'instant_form');
                      final platform = lead['platform']?.toString() ?? (lead['meta']?['platform']?.toString() ?? 'unknown');
                      final formName = lead['meta']?['formName']?.toString() ?? lead['formName']?.toString() ?? 'Instant Form';
                      final campaignName = lead['meta']?['campaignName']?.toString() ?? '';
                      final createdAt = DateTime.tryParse(lead['createdAt']?.toString() ?? '');
                      final status = lead['status']?.toString() ?? 'new';

                      return DataRow(
                        cells: [
                          // Contact
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: _textDark, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        phone.isNotEmpty ? '+$phone' : 'No phone number',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: phone.isNotEmpty ? _textMuted : Colors.red.shade700,
                                        ),
                                      ),
                                      if (needsAttention) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                          child: Text('Needs Attention', style: TextStyle(fontSize: 9, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Type & Platform
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (platform == 'ig')
                                  const FaIcon(FontAwesomeIcons.instagram, size: 14, color: Colors.pink)
                                else
                                  const FaIcon(FontAwesomeIcons.facebook, size: 14, color: _metaBlue),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: adType == 'ctwa' ? Colors.teal.shade50 : Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: adType == 'ctwa' ? Colors.teal.shade200 : Colors.purple.shade200),
                                  ),
                                  child: Text(
                                    adType == 'ctwa' ? 'CTWA' : (platform == 'ig' ? 'IG Form' : 'FB Form'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: adType == 'ctwa' ? Colors.teal.shade800 : Colors.purple.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Form / Campaign
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formName,
                                    style: const TextStyle(fontSize: 12, color: _textDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (campaignName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      campaignName,
                                      style: const TextStyle(fontSize: 10, color: _textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Submission Date
                          DataCell(
                            Text(
                              createdAt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt) : '—',
                              style: const TextStyle(fontSize: 11, color: _textMuted),
                            ),
                          ),
                          // Status
                          DataCell(
                            _StatusPillDropdown(
                              status: status,
                              onChanged: (newSt) => _updateLeadStatus(lead['_id'], newSt),
                            ),
                          ),
                          // Actions
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: _metaBlue),
                                  tooltip: 'View Touchpoint Attribution',
                                  onPressed: () => _showLeadDetailsDrawer(lead),
                                ),
                                if (phone.isNotEmpty)
                                  IconButton(
                                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: AppTheme.primaryColor),
                                    tooltip: 'Open in WhatsApp',
                                    onPressed: () => webOpenUrl('https://wa.me/$phone'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLeadCard(Map<String, dynamic> lead) {
    final name = lead['name']?.toString() ?? 'Unnamed Lead';
    final phone = lead['mobileNumber']?.toString() ?? '';
    final adType = lead['adType']?.toString() ?? (lead['meta']?['adType']?.toString() ?? 'instant_form');
    final platform = lead['platform']?.toString() ?? (lead['meta']?['platform']?.toString() ?? 'unknown');
    final formName = lead['meta']?['formName']?.toString() ?? lead['formName']?.toString() ?? 'Instant Form';
    final campaignName = lead['meta']?['campaignName']?.toString() ?? '';
    final createdAt = DateTime.tryParse(lead['createdAt']?.toString() ?? '');
    final status = lead['status']?.toString() ?? 'new';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (platform == 'ig')
                      const FaIcon(FontAwesomeIcons.instagram, size: 15, color: Colors.pink)
                    else
                      const FaIcon(FontAwesomeIcons.facebook, size: 15, color: _metaBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPillDropdown(
                status: status,
                onChanged: (newSt) => _updateLeadStatus(lead['_id'], newSt),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 13, color: phone.isNotEmpty ? _textMuted : Colors.red.shade700),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? '+$phone' : 'No phone number',
                style: TextStyle(fontSize: 12, color: phone.isNotEmpty ? _textMuted : Colors.red.shade700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: adType == 'ctwa' ? Colors.teal.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  adType == 'ctwa' ? 'CTWA' : (platform == 'ig' ? 'IG Form' : 'FB Form'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: adType == 'ctwa' ? Colors.teal.shade800 : Colors.purple.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _borderColor),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                    if (campaignName.isNotEmpty)
                      Text(campaignName, style: const TextStyle(fontSize: 10, color: _textMuted)),
                    if (createdAt != null)
                      Text(DateFormat('MMM dd, hh:mm a').format(createdAt), style: const TextStyle(fontSize: 10, color: _textMuted)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18, color: _metaBlue),
                tooltip: 'Details',
                onPressed: () => _showLeadDetailsDrawer(lead),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: AppTheme.primaryColor),
                  tooltip: 'WhatsApp',
                  onPressed: () => webOpenUrl('https://wa.me/$phone'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPillDropdown extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusPillDropdown({required this.status, required this.onChanged});

  Color _getStatusColor(String s) {
    switch (s) {
      case 'new':
        return Colors.blue.shade700;
      case 'contacted':
        return Colors.purple.shade700;
      case 'engaged':
        return Colors.orange.shade800;
      case 'converted':
        return AppTheme.secondaryColor;
      case 'failed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getStatusBg(String s) {
    switch (s) {
      case 'new':
        return Colors.blue.shade50;
      case 'contacted':
        return Colors.purple.shade50;
      case 'engaged':
        return Colors.orange.shade50;
      case 'converted':
        return Colors.green.shade50;
      case 'failed':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    final bg = _getStatusBg(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: color, size: 16),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          items: const [
            DropdownMenuItem(value: 'new', child: Text('New')),
            DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
            DropdownMenuItem(value: 'engaged', child: Text('Engaged')),
            DropdownMenuItem(value: 'converted', child: Text('Converted')),
            DropdownMenuItem(value: 'failed', child: Text('Failed')),
          ],
          onChanged: (v) {
            if (v != null && v != status) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _LeadDetailsDrawer extends StatelessWidget {
  final Map<String, dynamic> lead;

  const _LeadDetailsDrawer({required this.lead});

  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _bgSoft = Color(0xFFF8FAFC);
  static const Color _metaBlue = Color(0xFF1877F2);

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = (lead['meta'] as Map<String, dynamic>?) ?? {};
    final touchpoints = (lead['touchpoints'] as List<dynamic>?) ?? [];
    final metadata = (lead['metadata'] as Map<String, dynamic>?) ?? {};
    final name = lead['name']?.toString() ?? 'Unnamed Lead';
    final phone = lead['mobileNumber']?.toString() ?? '';
    final email = lead['email']?.toString() ?? '';
    final company = lead['companyName']?.toString() ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _metaBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: _metaBlue),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
                      Text(phone.isNotEmpty ? '+$phone' : 'No phone number', style: const TextStyle(fontSize: 13, color: _textMuted)),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: _borderColor),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attribution Snapshot Card
                  _buildSectionTitle('Campaign Attribution & Ad Snapshot'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Platform', meta['platform'] == 'ig' ? 'Instagram' : 'Facebook'),
                        _buildDetailRow('Form Name', meta['formName'] ?? lead['formName'] ?? '—'),
                        _buildDetailRow('Form ID', meta['formId'] ?? '—'),
                        _buildDetailRow('Campaign Name', meta['campaignName'] ?? '—'),
                        _buildDetailRow('Campaign ID', meta['campaignId'] ?? '—'),
                        _buildDetailRow('Ad Name', meta['adName'] ?? '—'),
                        _buildDetailRow('Ad ID', meta['adId'] ?? '—'),
                        if (meta['ctwaClid'] != null && (meta['ctwaClid'] as String).isNotEmpty)
                          _buildDetailRow('CTWA Click ID', meta['ctwaClid']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submitted Form Questions
                  if (metadata.isNotEmpty) ...[
                    _buildSectionTitle('Lead Form Answers & Questions'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _bgSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        children: [
                          if (email.isNotEmpty) _buildDetailRow('Email', email),
                          if (company.isNotEmpty) _buildDetailRow('Company', company),
                          for (final entry in metadata.entries)
                            _buildDetailRow(entry.key.replaceAll('_', ' ').toUpperCase(), entry.value.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Touchpoint History
                  if (touchpoints.isNotEmpty) ...[
                    _buildSectionTitle('Touchpoint History (${touchpoints.length})'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _bgSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        children: [
                          for (final tp in touchpoints)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: _metaBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tp['event']?.toString() ?? 'Event',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark),
                                        ),
                                        if (tp['timestamp'] != null)
                                          Text(
                                            DateFormat('MMM dd, hh:mm a').format(DateTime.parse(tp['timestamp'])),
                                            style: const TextStyle(fontSize: 10, color: _textMuted),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
