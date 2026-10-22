import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
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
            backgroundColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(data['healthy'] == true ? 'Connection Healthy' : 'Action Required'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['message']?.toString() ?? 'Page token and permissions are active.', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Text('• Webhook Subscribed: ${data['isSubscribed'] == true ? "YES" : "NO"}'),
                Text('• Forms Discovered: ${data['formsDiscovered'] ?? 0}'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text('Access Diagnostic Alert'),
              ],
            ),
            content: Text(
              'Diagnostic test returned error:\n\n$e\n\nEnsure user has "Leads Access" in Meta Business Settings.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchMetaStatusAndData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildConnectionBanner(),
                    const SizedBox(height: 20),
                    _buildPagesAccordion(),
                    const SizedBox(height: 20),
                    _buildKpiMetricsRow(),
                    const SizedBox(height: 20),
                    _buildFiltersCard(),
                    const SizedBox(height: 20),
                    _buildLeadsTableCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1877F2).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2), size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meta Ads Leads',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 2),
              Text(
                'Facebook & Instagram Instant Forms + Click-to-WhatsApp (CTWA) CRM Ingestion',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openTriggersDialog,
          icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF1877F2)),
          label: const Text('Automation Rules'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF1877F2)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: _fetchMetaStatusAndData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Refresh Leads',
        ),
      ],
    );
  }

  Widget _buildConnectionBanner() {
    if (!_isConnected) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.3)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1877F2).withValues(alpha: 0.08),
              AppTheme.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(FontAwesomeIcons.facebookF, color: Color(0xFF1877F2), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect Facebook & Instagram Pages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Receive Instant Form lead submissions in real-time (< 3 seconds) and automatically dispatch approved WhatsApp greeting templates.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _connectFacebook,
              icon: const Icon(FontAwesomeIcons.facebook, size: 16),
              label: const Text('Connect Facebook'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }

    final fbUser = _connection?['fbUserName'] ?? 'Authorized User';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Webhook Active',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pages.length} Connected Page(s) • ${_forms.length} Instant Form(s) registered',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _connectFacebook,
            icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF1877F2)),
            label: const Text('Reconnect / Refresh', style: TextStyle(color: Color(0xFF1877F2))),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesAccordion() {
    if (_pages.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        initiallyExpanded: _pagesExpanded,
        onExpansionChanged: (v) => setState(() => _pagesExpanded = v),
        title: Row(
          children: [
            const Icon(Icons.view_list_rounded, size: 20, color: Color(0xFF1877F2)),
            const SizedBox(width: 12),
            Text(
              'Connected Facebook Pages & Instant Forms (${_pages.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(color: Colors.white10),
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
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.facebook, size: 18, color: Color(0xFF1877F2)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pageName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    Text('Page ID: $pageId', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSubscribed ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSubscribed ? 'Subscribed' : 'Not Subscribed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSubscribed ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _testPageAccess(page['id']),
                icon: const Icon(Icons.health_and_safety_outlined, size: 14),
                label: const Text('Test Access', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          if (pageForms.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text(
              'Instant Forms (${pageForms.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
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
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, size: 16, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('ID: $formId', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                isSyncEnabled ? 'Sync Enabled' : 'Sync Paused',
                style: TextStyle(fontSize: 11, color: isSyncEnabled ? Colors.greenAccent : Colors.grey),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: isSyncEnabled,
                  onChanged: (_) => _toggleFormSync(form),
                  activeTrackColor: const Color(0xFF1877F2),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isSyncing ? null : () => _syncFormNow(form),
                icon: isSyncing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 14),
                label: const Text('Sync now', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFF1877F2),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsRow() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = (constraints.maxWidth - 48) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard('Total Meta Leads', _analytics['total'].toString(), Icons.campaign_rounded, const Color(0xFF1877F2), width),
            _buildKpiCard('Leads Today', _analytics['today'].toString(), Icons.today_rounded, Colors.tealAccent, width),
            _buildKpiCard('Contacted (Templates)', _analytics['contacted'].toString(), Icons.send_rounded, Colors.purpleAccent, width),
            _buildKpiCard('Engaged (Replied)', _analytics['engaged'].toString(), Icons.forum_rounded, Colors.amberAccent, width),
            _buildKpiCard('Converted', _analytics['converted'].toString(), Icons.verified_rounded, Colors.greenAccent, width),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width < 160 ? 160 : width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search leads by name, phone, email, campaign, ad...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _fetchLeads();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
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
              CompactDateRangePicker(
                initialDateRange: _dateRange,
                onDateRangeSelected: (range) {
                  setState(() => _dateRange = range);
                  _fetchLeads();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Ad Type Filter
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
              // Platform Filter
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
              // Form Filter
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
              // Status Filter
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
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppTheme.surfaceColor,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  Widget _buildLeadsTableCard() {
    if (_leads.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No Meta Ads Leads Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery"'
                  : 'Instant Form submissions from Facebook & Instagram will display here within seconds.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Auto-synced via Meta Webhooks & Graph API v26.0',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceColor),
              columns: const [
                DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Type & Platform', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Form / Campaign', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Submission Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                          Row(
                            children: [
                              Text(phone.isNotEmpty ? '+$phone' : 'No phone number',
                                  style: TextStyle(fontSize: 11, color: phone.isNotEmpty ? Colors.grey.shade400 : Colors.redAccent)),
                              if (needsAttention) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Needs Attention', style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Type & Platform
                    DataCell(
                      Row(
                        children: [
                          if (platform == 'ig')
                            const Icon(FontAwesomeIcons.instagram, size: 14, color: Colors.pinkAccent)
                          else
                            const Icon(FontAwesomeIcons.facebook, size: 14, color: Color(0xFF1877F2)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: adType == 'ctwa' ? Colors.teal.withValues(alpha: 0.15) : Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              adType == 'ctwa' ? 'CTWA' : (platform == 'ig' ? 'IG Form' : 'FB Form'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: adType == 'ctwa' ? Colors.tealAccent : Colors.purpleAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Form / Campaign
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(formName, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          if (campaignName.isNotEmpty)
                            Text(campaignName, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    // Submission Date
                    DataCell(
                      Text(
                        createdAt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt) : '—',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1877F2)),
                            tooltip: 'View Touchpoint Attribution',
                            onPressed: () => _showLeadDetailsDrawer(lead),
                          ),
                          if (phone.isNotEmpty)
                            IconButton(
                              icon: const Icon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.greenAccent),
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
        return Colors.blue;
      case 'contacted':
        return Colors.purpleAccent;
      case 'engaged':
        return Colors.amberAccent;
      case 'converted':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          dropdownColor: AppTheme.cardColor,
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
        color: AppTheme.cardColor,
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
                      color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF1877F2)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(phone.isNotEmpty ? '+$phone' : 'No phone number', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
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
                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
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
                      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
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
                  _buildSectionTitle('Attribution Touchpoints (${touchpoints.length})'),
                  const SizedBox(height: 8),
                  for (final tp in touchpoints) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Color(0xFF1877F2)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tp['adType'] == 'ctwa' ? "Click-to-WhatsApp" : "Instant Form"} • ${tp['formName'] ?? tp['adName'] ?? "Ad"}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Text(
                                  tp['at'] != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(tp['at'])) : '—',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
