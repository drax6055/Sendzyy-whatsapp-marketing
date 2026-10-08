import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/meta_ads_bloc.dart';
import '../bloc/meta_ads_event.dart';
import '../bloc/meta_ads_state.dart';
import '../widgets/campaign_kpi_card.dart';
import 'create_campaign_wizard_page.dart';
import 'campaign_details_analytics_page.dart';
import 'meta_leads_page.dart';

class MetaAdsDashboardPage extends StatefulWidget {
  const MetaAdsDashboardPage({super.key});

  @override
  State<MetaAdsDashboardPage> createState() => _MetaAdsDashboardPageState();
}

class _MetaAdsDashboardPageState extends State<MetaAdsDashboardPage> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    final bloc = context.read<MetaAdsBloc>();
    bloc.add(const LoadMetaAccountStatusEvent());
    bloc.add(const LoadMetaCampaignsEvent());
  }

  void _showConnectDialog(BuildContext context) {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Meta Business Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Facebook User Access Token or System User Token with ads_management and pages_read_engagement permissions.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'User Access Token',
                hintText: 'EAAB...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
            onPressed: () {
              final token = tokenController.text.trim();
              if (token.isNotEmpty) {
                context.read<MetaAdsBloc>().add(ConnectMetaAccountEvent(userAccessToken: token));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, size: 24),
            SizedBox(width: 8),
            Text('Meta Ads Manager'),
          ],
        ),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'View Meta Leads',
            icon: const Icon(Icons.contact_phone_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MetaLeadsPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<MetaAdsBloc>().add(const LoadMetaCampaignsEvent()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCampaignWizardPage()),
          );
        },
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<MetaAdsBloc, MetaAdsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          } else if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!), backgroundColor: const Color(0xFF10B981)),
            );
          }
        },
        builder: (context, state) {
          final isConnected = state.accountStatus?.connected == true;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MetaAdsBloc>().add(const LoadMetaCampaignsEvent());
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Connection Banner
                  _buildConnectionBanner(context, state, isConnected),
                  const SizedBox(height: 20),

                  // Overall KPIs Grid
                  const Text(
                    'Overall Performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      CampaignKpiCard(
                        title: 'Total Spend',
                        value: '₹ ${state.totalSpend.toStringAsFixed(2)}',
                        icon: Icons.currency_rupee_rounded,
                        iconColor: const Color(0xFF1877F2),
                      ),
                      CampaignKpiCard(
                        title: 'Total Leads',
                        value: '${state.totalLeads}',
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                      CampaignKpiCard(
                        title: 'Avg Cost/Lead',
                        value: state.averageCpl > 0 ? '₹ ${state.averageCpl.toStringAsFixed(2)}' : '₹ 0.00',
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      CampaignKpiCard(
                        title: 'Total Reach',
                        value: '${state.totalReach}',
                        icon: Icons.group_work_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Campaigns Section Header & Filter Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Campaigns (${state.campaigns.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Row(
                        children: [
                          _buildFilterChip('ALL', 'All'),
                          const SizedBox(width: 6),
                          _buildFilterChip('ACTIVE', 'Active'),
                          const SizedBox(width: 6),
                          _buildFilterChip('PAUSED', 'Paused'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Campaigns List
                  if (state.isLoading && state.campaigns.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (state.campaigns.isEmpty)
                    _buildEmptyState(context)
                  else ...[
                    ...state.campaigns.where((c) {
                      if (_selectedFilter == 'ALL') return true;
                      return c.status == _selectedFilter;
                    }).map((campaign) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCampaignCard(context, campaign),
                      );
                    }),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionBanner(BuildContext context, MetaAdsState state, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.amber.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isConnected ? const Color(0xFF10B981) : Colors.amber,
            radius: 20,
            child: Icon(isConnected ? Icons.check : Icons.warning_amber_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Facebook Account Connected' : 'Meta Account Not Connected',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  isConnected
                      ? 'Ad Account: ${state.accountStatus?.adAccountName ?? state.accountStatus?.adAccountId ?? 'Active'}'
                      : 'Connect your Facebook Business account to manage ads and receive leads.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (isConnected) {
                context.read<MetaAdsBloc>().add(const DisconnectMetaAccountEvent());
              } else {
                _showConnectDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? Colors.grey.shade200 : const Color(0xFF1877F2),
              foregroundColor: isConnected ? Colors.black87 : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1877F2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  Widget _buildCampaignCard(BuildContext context, dynamic campaign) {
    final isActive = campaign.status == 'ACTIVE';
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CampaignDetailsAnalyticsPage(campaign: campaign),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    campaign.status,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF10B981) : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Objective: ${campaign.objective.replaceAll('OUTCOME_', '')} · Destination: ${campaign.destinationType.replaceAll('_', ' ')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn('Spend', '₹ ${campaign.insights.spend.toStringAsFixed(0)}'),
                _buildStatColumn('Leads', '${campaign.insights.leadsCount}'),
                _buildStatColumn(
                  'CPL',
                  campaign.insights.cpl > 0 ? '₹ ${campaign.insights.cpl.toStringAsFixed(0)}' : '—',
                ),
                _buildStatColumn('Reach', '${campaign.insights.reach}'),
                IconButton(
                  tooltip: isActive ? 'Pause' : 'Resume',
                  icon: Icon(
                    isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: isActive ? Colors.grey.shade700 : const Color(0xFF10B981),
                  ),
                  onPressed: () {
                    final nextStatus = isActive ? 'PAUSED' : 'ACTIVE';
                    context.read<MetaAdsBloc>().add(UpdateMetaCampaignStatusEvent(campaign.id, nextStatus));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.rocket_launch_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No campaigns created yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first Facebook & Instagram ad campaign using the 4-step wizard.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCampaignWizardPage()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Launch First Campaign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
