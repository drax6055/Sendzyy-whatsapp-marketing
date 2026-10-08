import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/js/meta_ads_auth_helper.dart';
import '../../../../core/js/meta_signup_helper.dart';
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
    final metaBloc = context.read<MetaAdsBloc>();
    final accountStatus = metaBloc.state.accountStatus;
    final tokenController = TextEditingController();
    bool isAuthenticating = false;
    String? statusMessage;
    bool showManualToken = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF1877F2), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Connect Meta Ads',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAuthenticating) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              statusMessage ?? 'Authorizing with Meta...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Text(
                        'Connect your Facebook account to manage ads, sync ad accounts, and ingest lead generation forms automatically.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),

                      // Option 1: One-Click Sync from General Settings WhatsApp Onboarding
                      if (accountStatus?.hasTenantOnboarding == true) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Connected Meta Account Detected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Re-use your credentials verified during General Settings onboarding.${accountStatus?.tenantBusinessId != null ? ' Business ID: ${accountStatus!.tenantBusinessId}' : ''}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: const Text('1-Click Connect with Onboarded Account', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  metaBloc.add(const ConnectMetaAccountEvent(useTenantOnboarding: true));
                                  Navigator.pop(ctx);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Option 2: Facebook Login OAuth Flow (Popup)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.facebook_rounded, size: 22),
                        label: const Text(
                          'Continue with Facebook (Popup Login)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          setDialogState(() {
                            isAuthenticating = true;
                            statusMessage = 'Opening Facebook OAuth popup...';
                          });

                          try {
                            final res = await triggerFacebookAdsLogin(AppConstants.metaAppId);
                            if (res != null && res['status'] == 'success') {
                              final token = res['accessToken'] as String?;
                              final code = res['code'] as String?;
                              metaBloc.add(ConnectMetaAccountEvent(
                                userAccessToken: token,
                                code: code,
                              ));
                              if (dialogContext.mounted) {
                                Navigator.pop(ctx);
                              }
                            } else if (res != null && res['status'] == 'cancelled') {
                              setDialogState(() {
                                isAuthenticating = false;
                                statusMessage = null;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Facebook login was cancelled.')),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isAuthenticating = false;
                                statusMessage = null;
                              });
                              final err = res?['error'] ?? 'Facebook SDK error';
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Facebook Login: $err'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              isAuthenticating = false;
                              statusMessage = null;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Facebook error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Option 3: Launch Embedded Onboarding Signup
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Re-run Meta Embedded Signup Flow'),
                        onPressed: () async {
                          setDialogState(() {
                            isAuthenticating = true;
                            statusMessage = 'Opening Meta Embedded Signup popup...';
                          });

                          try {
                            final res = await triggerMetaSignup(
                              AppConstants.metaAppId,
                              AppConstants.metaConfigId,
                            );

                            if (res != null && res['status'] == 'success') {
                              final code = res['code'] as String?;
                              final bizId = res['businessPortfolioId'] as String?;
                              metaBloc.add(ConnectMetaAccountEvent(
                                code: code,
                                businessId: bizId,
                              ));
                              if (dialogContext.mounted) {
                                Navigator.pop(ctx);
                              }
                            } else {
                              setDialogState(() {
                                isAuthenticating = false;
                                statusMessage = null;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isAuthenticating = false;
                              statusMessage = null;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 14),
                      Divider(color: Colors.grey.shade200),

                      // Option 4: Manual Access Token Expandable Fallback
                      InkWell(
                        onTap: () {
                          setDialogState(() => showManualToken = !showManualToken);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                showManualToken ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Advanced: Enter Access Token Manually',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (showManualToken) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: tokenController,
                          decoration: InputDecoration(
                            labelText: 'User Access Token',
                            hintText: 'EAAB...',
                            prefixIcon: const Icon(Icons.key_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final token = tokenController.text.trim();
                            if (token.isNotEmpty) {
                              metaBloc.add(ConnectMetaAccountEvent(userAccessToken: token));
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Connect with Manual Token'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssetSelectionDialog(BuildContext context, MetaAdsState state) {
    final metaBloc = context.read<MetaAdsBloc>();
    String? selectedAdAccountId = state.accountStatus?.adAccountId ?? (state.adAccounts.isNotEmpty ? state.adAccounts.first.id : null);
    String? selectedPageId = state.accountStatus?.pageId ?? (state.pages.isNotEmpty ? state.pages.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final selectedAccount = state.adAccounts.where((a) => a.id == selectedAdAccountId).firstOrNull;
          final selectedPage = state.pages.where((p) => p.id == selectedPageId).firstOrNull;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: Color(0xFF1877F2)),
                SizedBox(width: 10),
                Text('Active Ad Account & Page', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select which Ad Account and Facebook Page to use for creating campaigns and tracking lead generation forms.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Ad Account Selector
                  const Text('Ad Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (state.adAccounts.isEmpty)
                    const Text('No ad accounts found for this Facebook account.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedAdAccountId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: state.adAccounts.map((account) {
                        return DropdownMenuItem<String>(
                          value: account.id,
                          child: Text(
                            '${account.name} (${account.id})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedAdAccountId = val);
                        }
                      },
                    ),

                  const SizedBox(height: 16),

                  // Facebook Page Selector
                  const Text('Facebook Page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (state.pages.isEmpty)
                    const Text('No Facebook pages found for this user.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedPageId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: state.pages.map((page) {
                        return DropdownMenuItem<String>(
                          value: page.id,
                          child: Text(
                            '${page.name} (${page.category ?? 'Page'})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedPageId = val);
                        }
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedAdAccountId != null && selectedPageId != null) {
                    metaBloc.add(SelectMetaAssetsEvent(
                      adAccountId: selectedAdAccountId!,
                      adAccountName: selectedAccount?.name,
                      pageId: selectedPageId!,
                      pageName: selectedPage?.name,
                    ));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Active Assets'),
              ),
            ],
          );
        },
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
                const SizedBox(height: 2),
                if (isConnected) ...[
                  Text(
                    'Ad Account: ${state.accountStatus?.adAccountName ?? state.accountStatus?.adAccountId ?? 'Active'}${state.accountStatus?.pageName != null ? '  •  Page: ${state.accountStatus!.pageName}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ] else ...[
                  Text(
                    'Connect your Facebook account to run ads, sync ad accounts, and collect leads.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (isConnected) ...[
            OutlinedButton.icon(
              onPressed: () => _showAssetSelectionDialog(context, state),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E293B),
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(60, 36),
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Assets', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
          ],
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
