import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../chat/data/services/socket_service.dart';
import '../bloc/meta_ads_bloc.dart';
import '../bloc/meta_ads_event.dart';
import '../bloc/meta_ads_state.dart';
import '../../data/models/meta_lead_model.dart';

class MetaLeadsPage extends StatefulWidget {
  final String? campaignId;

  const MetaLeadsPage({super.key, this.campaignId});

  @override
  State<MetaLeadsPage> createState() => _MetaLeadsPageState();
}

class _MetaLeadsPageState extends State<MetaLeadsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription? _leadSub;
  String? _selectedCampaignId;
  int _newLeadFlashCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedCampaignId = widget.campaignId;
    final bloc = context.read<MetaAdsBloc>();
    bloc.add(LoadMetaLeadsEvent(campaignId: _selectedCampaignId));
    if (bloc.state.campaigns.isEmpty) {
      bloc.add(const LoadMetaCampaignsEvent());
    }

    try {
      _leadSub = getIt<SocketService>().metaLeadStream.listen((data) {
        if (!mounted) return;
        final leadName = data['lead']?['name'] ?? 'New Lead';
        final leadPhone = data['lead']?['mobileNumber'] ?? '';
        setState(() => _newLeadFlashCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('🎯 New Meta Lead: $leadName${leadPhone.isNotEmpty ? ' (+$leadPhone)' : ''}')),
              ],
            ),
            backgroundColor: const Color(0xFF1877F2),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: _selectedCampaignId));
              },
            ),
          ),
        );
        context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: _selectedCampaignId));
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _leadSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<dynamic> leads) {
    if (leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leads to export')),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('Name,Phone,Email,Form Name,Campaign ID,Created At');
    for (final l in leads) {
      final name = '"${(l.name ?? '').toString().replaceAll('"', '""')}"';
      final phone = '"${(l.mobileNumber ?? '').toString().replaceAll('"', '""')}"';
      final email = '"${(l.email ?? '').toString().replaceAll('"', '""')}"';
      final form = '"${(l.formName ?? '').toString().replaceAll('"', '""')}"';
      final campaign = '"${(l.metaCampaignId ?? '').toString().replaceAll('"', '""')}"';
      final date = l.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(l.createdAt!) : '';
      buffer.writeln('$name,$phone,$email,$form,$campaign,$date');
    }
    webDownloadBytes(
      utf8.encode(buffer.toString()),
      'meta_ads_leads_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leads exported to CSV'), backgroundColor: Color(0xFF10B981)),
    );
  }

  String _getCampaignName(MetaAdsState state, String? campaignId) {
    if (campaignId == null || campaignId.isEmpty) return '';
    try {
      final camp = state.campaigns.firstWhere((c) => c.id == campaignId);
      return camp.name;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.contact_phone_rounded, size: 22),
            SizedBox(width: 8),
            Text('Meta Ad Leads'),
          ],
        ),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<MetaAdsBloc, MetaAdsState>(
            buildWhen: (p, c) => p.leads.length != c.leads.length,
            builder: (ctx, state) => IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportCsv(state.leads),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: _selectedCampaignId)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Real-time stats banner
          BlocBuilder<MetaAdsBloc, MetaAdsState>(
            builder: (context, state) {
              final total = state.leads.length;
              final now = DateTime.now();
              final today = state.leads.where((l) =>
                  l.createdAt != null &&
                  l.createdAt!.year == now.year &&
                  l.createdAt!.month == now.month &&
                  l.createdAt!.day == now.day).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF0D5FD8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    _buildStatBadge('Total Leads', '$total', Icons.people_alt_rounded),
                    const SizedBox(width: 20),
                    _buildStatBadge('Today', '$today', Icons.today_rounded),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                          SizedBox(width: 4),
                          Text('Real-Time Sync', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search & Campaign Filter header
          BlocBuilder<MetaAdsBloc, MetaAdsState>(
            buildWhen: (prev, curr) => prev.campaigns != curr.campaigns,
            builder: (context, state) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search name, phone, email...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                    if (state.campaigns.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCampaignId,
                          decoration: InputDecoration(
                            labelText: 'Campaign',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Campaigns', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            ...state.campaigns.map((c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedCampaignId = val);
                            context.read<MetaAdsBloc>().add(LoadMetaLeadsEvent(campaignId: val));
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Leads List
          Expanded(
            child: BlocBuilder<MetaAdsBloc, MetaAdsState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF1877F2)),
                        SizedBox(height: 12),
                        Text('Loading leads...', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  );
                }

                final filteredLeads = state.leads.where((lead) {
                  if (_searchQuery.isEmpty) return true;
                  return lead.name.toLowerCase().contains(_searchQuery) ||
                      lead.mobileNumber.contains(_searchQuery) ||
                      lead.email.toLowerCase().contains(_searchQuery) ||
                      lead.formName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredLeads.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLeads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    final campaignName = _getCampaignName(state, lead.metaCampaignId);
                    return _buildLeadCard(context, lead, campaignName);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildLeadCard(BuildContext context, MetaLeadModel lead, String campaignName) {
    final phone = lead.mobileNumber.replaceAll(RegExp(r'\D'), '');
    final words = lead.name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.isNotEmpty
        ? words.take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    final avatarColors = [
      const Color(0xFF1877F2), const Color(0xFF10B981),
      const Color(0xFF8B5CF6), const Color(0xFFEC4899),
      const Color(0xFFF59E0B), const Color(0xFF06B6D4),
    ];
    final colorIndex = lead.id.isNotEmpty ? lead.id.codeUnitAt(lead.id.length - 1) % avatarColors.length : 0;
    final avatarColor = avatarColors[colorIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(initials, style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 15))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lead.name.isNotEmpty ? lead.name : 'Meta Lead',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF6366F1)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('📊 Meta Ad', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (lead.mobileNumber.isNotEmpty)
                        Row(children: [
                          Icon(Icons.phone_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('+${lead.mobileNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                        ]),
                      if (lead.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(child: Text(lead.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ],
                  ),
                ),
                if (lead.createdAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('dd MMM').format(lead.createdAt!), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      Text(DateFormat('hh:mm a').format(lead.createdAt!), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
              ],
            ),
            if (campaignName.isNotEmpty || lead.formName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (campaignName.isNotEmpty)
                  _buildTag(Icons.campaign_rounded, campaignName, const Color(0xFF1877F2)),
                if (lead.formName.isNotEmpty)
                  _buildTag(Icons.assignment_outlined, 'Form: ${lead.formName}', const Color(0xFF6366F1)),
              ]),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),
            Row(
              children: [
                if (phone.isNotEmpty)
                  _buildActionBtn(Icons.chat_bubble_outline_rounded, 'WhatsApp', const Color(0xFF25D366), () => webOpenUrl('https://wa.me/$phone')),
                if (phone.isNotEmpty) const SizedBox(width: 8),
                if (phone.isNotEmpty)
                  _buildActionBtn(Icons.copy_rounded, 'Copy', const Color(0xFF64748B), () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: +$phone'), duration: const Duration(seconds: 2)));
                  }),
                const Spacer(),
                InkWell(
                  onTap: () => _showLeadDetails(context, lead, campaignName),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('Details', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showLeadDetails(BuildContext context, MetaLeadModel lead, String campaignName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.contact_phone_rounded, color: Color(0xFF1877F2)),
                  const SizedBox(width: 8),
                  const Text('Lead Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  if (lead.createdAt != null)
                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt!), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Name', lead.name.isNotEmpty ? lead.name : 'N/A'),
              _detailRow('Phone', lead.mobileNumber.isNotEmpty ? '+${lead.mobileNumber}' : 'N/A'),
              _detailRow('Email', lead.email.isNotEmpty ? lead.email : 'N/A'),
              _detailRow('Form Name', lead.formName.isNotEmpty ? lead.formName : 'N/A'),
              if (campaignName.isNotEmpty) _detailRow('Campaign', campaignName),
              if (lead.metaLeadgenId != null) _detailRow('Meta Lead ID', lead.metaLeadgenId!),
              if (lead.metaFormId != null) _detailRow('Meta Form ID', lead.metaFormId!),
              const SizedBox(height: 16),
              if (lead.metadata.isNotEmpty) ...[
                Text('Additional Fields', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ...lead.metadata.entries
                    .where((e) => !['metaLeadgenId', 'metaFormId', 'metaAdId', 'metaCampaignId', 'rawFieldData'].contains(e.key))
                    .map((e) => _detailRow(e.key, e.value?.toString() ?? '')),
              ],
              const SizedBox(height: 20),
              if (lead.mobileNumber.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final phone = lead.mobileNumber.replaceAll(RegExp(r'\D'), '');
                      webOpenUrl('https://wa.me/$phone');
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Open WhatsApp Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contact_phone_outlined, size: 56, color: Color(0xFF1877F2)),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty ? 'No leads yet' : 'No leads matching "$_searchQuery"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isEmpty
                  ? 'When customers fill your Meta lead forms, their details appear here in real-time.'
                  : 'Try a different search or clear the filter.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1877F2))),
                  const SizedBox(height: 10),
                  _howItWorksStep('1', 'Create a campaign with a Lead Form objective'),
                  _howItWorksStep('2', 'Customers see your ad on Facebook / Instagram'),
                  _howItWorksStep('3', 'They fill the instant form inside the ad'),
                  _howItWorksStep('4', 'Lead details appear here automatically in real-time!'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _howItWorksStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
            child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
        ],
      ),
    );
  }
}
