import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/models/whatsapp_flow_model.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/data/repositories/whatsapp_flow_repository.dart';
import 'package:iFloraBuzz/features/whatsapp_flows/presentation/pages/create_flow_page.dart';
import 'package:intl/intl.dart';

class WhatsAppFlowsPage extends StatefulWidget {
  const WhatsAppFlowsPage({super.key});

  @override
  State<WhatsAppFlowsPage> createState() => _WhatsAppFlowsPageState();
}

class _WhatsAppFlowsPageState extends State<WhatsAppFlowsPage> with SingleTickerProviderStateMixin {
  WhatsAppFlowRepository get _repository {
    try {
      return getIt<WhatsAppFlowRepository>();
    } catch (_) {
      return WhatsAppFlowRepository(getIt<Dio>());
    }
  }

  late final TabController _tabController;

  List<WhatsAppFlowModel> _flows = [];
  List<FlowSubmissionModel> _submissions = [];

  bool _loadingFlows = true;
  bool _syncingMeta = false;
  bool _loadingSubmissions = true;
  String _searchQuery = '';
  String? _selectedFlowFilterId;
  String? _selectedFlowFilterName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _loadSubmissions();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFlows();
        _loadSubmissions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFlows({bool sync = false}) async {
    if (sync) {
      if (mounted) setState(() => _syncingMeta = true);
    } else if (!_loadingFlows) {
      if (mounted) setState(() => _loadingFlows = true);
    }

    try {
      final flows = await _repository.getFlows(sync: sync);
      if (mounted) {
        setState(() {
          _flows = flows;
          _loadingFlows = false;
          _syncingMeta = false;
        });
        if (sync) {
          SnackbarUtils.showSuccess(context, 'Flows successfully synced with Meta WABA!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFlows = false;
          _syncingMeta = false;
        });
        SnackbarUtils.showError(context, 'Error loading flows: $e');
      }
    }
  }

  Future<void> _loadSubmissions({String? flowId}) async {
    final targetFlowId = flowId ?? _selectedFlowFilterId ?? 'all';
    if (!_loadingSubmissions && mounted) {
      setState(() => _loadingSubmissions = true);
    }
    try {
      final subs = await _repository.getFlowResponses(flowId: targetFlowId);
      if (mounted) {
        setState(() {
          _submissions = subs;
          _loadingSubmissions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSubmissions = false);
    }
  }

  void _openCreateFlow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFlowPage(
          repository: _repository,
          existingFlows: _flows,
          onFlowCreated: () => _loadFlows(),
        ),
      ),
    );
    if (result != null) {
      _loadFlows();
    }
  }

  void _showTestSendDialog(WhatsAppFlowModel flow) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('Send Flow: ${flow.name}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter customer WhatsApp number with country code (e.g. 919876543210):',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g. 919876543210',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.sendFlow(
                  to: phone,
                  flowId: flow.flowId,
                  bodyText: flow.bodyText.isNotEmpty ? flow.bodyText : 'Please complete this form:',
                  ctaText: flow.ctaText,
                );
                if (mounted) {
                  SnackbarUtils.showSuccess(context, 'Flow sent successfully to $phone!');
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtils.showError(context, 'Failed to send flow: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }

  void _confirmPublishFlow(WhatsAppFlowModel flow) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Publish Flow to Live?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to publish "${flow.name}" on Meta WABA?'),
            const SizedBox(height: 10),
            const Text(
              '⚠️ Once published, the flow is locked by Meta and can be sent to all real customers.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final success = await _repository.publishFlow(flow.flowId);
                if (success && mounted) {
                  SnackbarUtils.showSuccess(context, 'Flow "${flow.name}" published successfully!');
                  _loadFlows();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtils.showError(context, 'Failed to publish: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Publish Now'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFlow(WhatsAppFlowModel flow) {
    final isPublished = flow.status.toUpperCase() == 'PUBLISHED';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Flow?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${flow.name}"?'),
            const SizedBox(height: 10),
            Text(
              isPublished
                  ? '⚠️ This flow is published on Meta. It will be removed from Sendzyy and deprecated on Meta WABA.'
                  : '⚠️ This flow draft will be permanently deleted from Sendzyy and Meta WABA.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final success = await _repository.deleteFlow(flow.flowId);
                if (success && mounted) {
                  SnackbarUtils.showSuccess(context, 'Flow "${flow.name}" deleted successfully!');
                  _loadFlows();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtils.showError(context, 'Failed to delete flow: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFlows = _flows.where((f) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) ||
          f.flowId.toLowerCase().contains(q) ||
          f.status.toLowerCase().contains(q);
    }).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFlowsTab(filteredFlows),
                _buildSubmissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncMetaButton() {
    return OutlinedButton.icon(
      onPressed: _syncingMeta ? null : () => _loadFlows(sync: true),
      icon: _syncingMeta
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
            )
          : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF2E7D32)),
      label: Text(
        _syncingMeta ? 'Syncing...' : 'Sync Meta',
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2E7D32),
        side: const BorderSide(color: Color(0xFF2E7D32), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildCreateFlowButton() {
    return ElevatedButton.icon(
      onPressed: _openCreateFlow,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Create New Flow',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: Size.zero,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schema_rounded, color: Color(0xFF2E7D32), size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WhatsApp Flows',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Interactive forms & surveys in WhatsApp',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildSyncMetaButton(),
                const SizedBox(width: 12),
                _buildCreateFlowButton(),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.schema_rounded, color: Color(0xFF2E7D32), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'WhatsApp Flows',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Interactive forms & surveys in WhatsApp',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildSyncMetaButton(),
                    _buildCreateFlowButton(),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 14),
          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search flows by name or ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppTheme.primaryColor,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list_alt_rounded, size: 18),
                const SizedBox(width: 8),
                Text('All Flows (${_flows.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_rounded, size: 18),
                const SizedBox(width: 8),
                Text('Submissions (${_submissions.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowsTab(List<WhatsAppFlowModel> flows) {
    if (_loadingFlows) {
      return const Center(child: CircularProgressIndicator());
    }

    if (flows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dynamic_form_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No WhatsApp Flows Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first interactive Flow to capture leads, book appointments, or collect survey feedback inside WhatsApp.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openCreateFlow,
                icon: const Icon(Icons.add),
                label: const Text('Create New Flow'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFlows(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: flows.length,
        itemBuilder: (ctx, index) {
          final flow = flows[index];
          return _buildFlowCard(flow);
        },
      ),
    );
  }

  Widget _buildFlowCard(WhatsAppFlowModel flow) {
    final isPublished = flow.status.toUpperCase() == 'PUBLISHED';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flow.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'ID: ${flow.flowId}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                            tooltip: 'Copy Flow ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: flow.flowId));
                              SnackbarUtils.showSuccess(context, 'Flow ID copied!');
                            },
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublished ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublished ? Icons.check_circle : Icons.pending,
                        size: 14,
                        color: isPublished ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        flow.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPublished ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            // Metadata chips row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _badgeInfo(Icons.category_outlined, flow.categories.join(', ')),
                _badgeInfo(Icons.touch_app_outlined, 'CTA: ${flow.ctaText}'),
                _badgeInfo(Icons.inbox_outlined, '${flow.submissionsCount} submissions'),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons (Responsive & Clean Wrap)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Delete Button
                IconButton(
                  tooltip: 'Delete Flow',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _confirmDeleteFlow(flow),
                ),

                // View Submissions Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFlowFilterId = flow.flowId;
                      _selectedFlowFilterName = flow.name;
                    });
                    _tabController.animateTo(1);
                    _loadSubmissions(flowId: flow.flowId);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF16A34A)),
                  label: const Text(
                    'Submissions',
                    style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    backgroundColor: const Color(0xFFF0FDF4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                ),

                // Publish Button (if DRAFT)
                if (!isPublished)
                  OutlinedButton.icon(
                    onPressed: () => _confirmPublishFlow(flow),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: const Text(
                      'Publish',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 36),
                    ),
                  ),

                // Primary Send Test Button
                ElevatedButton.icon(
                  onPressed: () => _showTestSendDialog(flow),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text(
                    'Send Test',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildSubmissionsTab() {
    return Column(
      children: [
        _buildSubmissionsFilterBar(),
        Expanded(
          child: _loadingSubmissions
              ? const Center(child: CircularProgressIndicator())
              : _submissions.isEmpty
                  ? _buildEmptySubmissionsView()
                  : RefreshIndicator(
                      onRefresh: () => _loadSubmissions(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _submissions.length,
                        itemBuilder: (ctx, index) {
                          final sub = _submissions[index];
                          final dateStr = sub.createdAt != null
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(sub.createdAt!)
                              : 'Unknown date';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ExpansionTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Icon(Icons.check, color: Color(0xFF16A34A), size: 18),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub.contactName.isNotEmpty ? sub.contactName : sub.contactId,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  if (sub.flowName.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        sub.flowName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Phone: ${sub.contactId} • $dateStr',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                              childrenPadding: const EdgeInsets.all(16),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.assignment_turned_in_rounded, size: 16, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Submitted Answers:',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                          ),
                                          const Spacer(),
                                          if (sub.flowName.isNotEmpty)
                                            Text(
                                              'Flow: ${sub.flowName}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (sub.responseData.isEmpty)
                                        const Text(
                                          'No response fields submitted.',
                                          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                        )
                                      else
                                        ...sub.responseData.entries.map((entry) {
                                          return _buildAnswerItem(entry.key, entry.value);
                                        }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsFilterBar() {
    final hasFilter = _selectedFlowFilterId != null;
    final bool filterMatchesFlow = hasFilter && _flows.any((f) => f.flowId == _selectedFlowFilterId);
    final dropdownValue = hasFilter && filterMatchesFlow ? _selectedFlowFilterId! : 'all';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(
            hasFilter ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
            size: 18,
            color: hasFilter ? const Color(0xFF16A34A) : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          const Text(
            'Filter by Template:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFilter ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dropdownValue,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Row(
                        children: [
                          const Text('All Templates / Flows', style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_flows.fold<int>(0, (sum, f) => sum + f.submissionsCount)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._flows.map((flow) {
                      final isSelected = _selectedFlowFilterId == flow.flowId;
                      return DropdownMenuItem<String>(
                        value: flow.flowId,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                flow.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: flow.submissionsCount > 0 ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${flow.submissionsCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: flow.submissionsCount > 0 ? const Color(0xFF16A34A) : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (newFlowId) {
                    if (newFlowId == null) return;
                    setState(() {
                      if (newFlowId == 'all') {
                        _selectedFlowFilterId = null;
                        _selectedFlowFilterName = null;
                      } else {
                        _selectedFlowFilterId = newFlowId;
                        final matched = _flows.where((f) => f.flowId == newFlowId).firstOrNull;
                        _selectedFlowFilterName = matched?.name ?? newFlowId;
                      }
                    });
                    _loadSubmissions(flowId: newFlowId);
                  },
                ),
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFlowFilterId = null;
                  _selectedFlowFilterName = null;
                });
                _loadSubmissions(flowId: 'all');
              },
              icon: const Icon(Icons.clear, size: 14, color: Color(0xFFEF4444)),
              label: const Text('Show All', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 36),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySubmissionsView() {
    final isFiltered = _selectedFlowFilterId != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.filter_alt_off_rounded : Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'No Submissions for "${_selectedFlowFilterName ?? 'this Template'}"'
                  : 'No Form Submissions Yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'No customer has submitted responses for this specific flow template yet.'
                  : 'When customers fill out and submit your WhatsApp Flows, their responses will appear here in real-time.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFlowFilterId = null;
                    _selectedFlowFilterName = null;
                  });
                  _loadSubmissions(flowId: 'all');
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text(
                  'View All Submissions',
                  style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatQuestionKey(String rawKey) {
    if (rawKey.isEmpty) return 'Answer';

    // Remove screen prefix: screen_0_, screen_1_, etc.
    var cleaned = rawKey.replaceAll(RegExp(r'^screen_\d+_', caseSensitive: false), '');

    // Remove trailing index suffix: _0, _1, etc.
    cleaned = cleaned.replaceAll(RegExp(r'_\d+$'), '');

    // Replace underscores with spaces
    cleaned = cleaned.replaceAll('_', ' ').trim();

    if (cleaned.isEmpty) cleaned = rawKey;

    // Title case each word: "choose all that apply" -> "Choose All That Apply"
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _cleanValueString(String val) {
    var s = val.trim();
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    // Strip leading index like "0_Buy_it_right_away" -> "Buy_it_right_away"
    s = s.replaceAll(RegExp(r'^\d+_'), '');
    // Replace underscores with spaces
    s = s.replaceAll('_', ' ').trim();
    if (s.isNotEmpty) {
      s = s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }

  List<String> _parseAnswerValues(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((item) => _cleanValueString(item.toString()))
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final str = value.toString().trim();
    if (str.startsWith('[') && str.endsWith(']')) {
      final inner = str.substring(1, str.length - 1).trim();
      if (inner.isEmpty) return [];
      return inner
          .split(',')
          .map((item) => _cleanValueString(item))
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final cleaned = _cleanValueString(str);
    return cleaned.isEmpty ? [] : [cleaned];
  }

  Widget _buildAnswerItem(String rawKey, dynamic rawValue) {
    final questionTitle = _formatQuestionKey(rawKey);
    final answers = _parseAnswerValues(rawValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  questionTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (answers.isEmpty)
            const Text(
              'No answer provided',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          else if (answers.length == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      answers.first,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: answers.map((ans) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                      const SizedBox(width: 5),
                      Text(
                        ans,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w500,
                        ),
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
}
