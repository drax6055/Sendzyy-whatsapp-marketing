import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class TeamMembersPage extends StatefulWidget {
  const TeamMembersPage({super.key});

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  final Dio _dio = getIt<Dio>();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _employees = [];
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  static const Map<String, String> _availableModules = {
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

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.get('/api/employees');
      if (response.statusCode == 200 && response.data['employees'] != null) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(response.data['employees']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.data['error'] ?? 'Failed to load team members';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading team members: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((emp) {
      final name = (emp['name'] ?? '').toString().toLowerCase();
      final email = (emp['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesQuery = name.contains(q) || email.contains(q);

      if (!matchesQuery) return false;

      if (_statusFilter == 'active') {
        return emp['status'] == 'active';
      } else if (_statusFilter == 'inactive') {
        return emp['status'] == 'inactive';
      }
      return true;
    }).toList();
  }

  int get _totalChatsAssigned {
    return _employees.fold(0, (sum, emp) => sum + ((emp['assignedChatsCount'] as num?)?.toInt() ?? 0));
  }

  int get _activeCount {
    return _employees.where((e) => e['status'] == 'active').length;
  }

  String _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%*';
    final random = Random.secure();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _showAddEditEmployeeDialog({Map<String, dynamic>? employee}) {
    final isEditing = employee != null;
    final nameController = TextEditingController(text: employee?['name'] ?? '');
    final emailController = TextEditingController(text: employee?['email'] ?? '');
    final passwordController = TextEditingController();
    final Set<String> selectedPermissions = Set<String>.from(
      employee?['permissions'] ?? ['chat', 'broadcast', 'templates'],
    );
    selectedPermissions.add('reports'); // Reports is compulsory for all employees
    bool obscurePassword = true;
    bool isSubmitting = false;

    if (!isEditing) {
      passwordController.text = _generatePassword();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? 'Edit Team Member' : 'Add New Team Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEditing)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read_outlined, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'An automated welcome email with these login credentials will be dispatched to the employee immediately upon creation.',
                                style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Full Name
                    const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rahul Sharma',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email Address
                    const Text('Email Address *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'e.g. rahul@company.com',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'New Password (leave blank to keep current)' : 'Password *',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              passwordController.text = _generatePassword();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Generate', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: isEditing ? 'Enter to reset password' : 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Module Permissions Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Granted Module Access',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedPermissions.length} of ${_availableModules.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setDialogState(() {
                                  selectedPermissions.addAll(_availableModules.keys);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Select All',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setDialogState(() {
                                  selectedPermissions.clear();
                                  selectedPermissions.add('reports'); // Reports is compulsory
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.restart_alt_rounded, size: 14, color: Colors.red.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the modules this team member is authorized to access.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    // Module Selection Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final crossAxisCount = isNarrow ? 1 : 2;
                        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableModules.entries.map((entry) {
                            final key = entry.key;
                            final label = entry.value;
                            final icon = _moduleIcons[key] ?? Icons.widgets_rounded;
                            final isPermanent = key == 'reports';
                            final isSelected = isPermanent || selectedPermissions.contains(key);

                            return SizedBox(
                              width: itemWidth,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: isPermanent
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            selectedPermissions.remove(key);
                                          } else {
                                            selectedPermissions.add(key);
                                          }
                                        });
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isPermanent
                                        ? const Color(0xFFF0FDF4)
                                        : (isSelected
                                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isPermanent
                                          ? AppTheme.primaryColor.withValues(alpha: 0.7)
                                          : (isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFFE2E8F0)),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Module Icon
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isPermanent
                                              ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                              : (isSelected
                                                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                                  : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 17,
                                          color: isPermanent || isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Module Label
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected
                                                    ? (isPermanent ? const Color(0xFF065F46) : const Color(0xFF0F172A))
                                                    : const Color(0xFF334155),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isPermanent)
                                              const Text(
                                                'Always compulsory',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Status Indicator / Lock Badge
                                      if (isPermanent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 10, color: AppTheme.primaryColor),
                                              SizedBox(width: 3),
                                              Text(
                                                'Locked',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: AppTheme.primaryColor,
                                        )
                                      else
                                        Icon(
                                          Icons.circle_outlined,
                                          size: 18,
                                          color: Colors.grey.shade400,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final currentCtx = context;
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();

                        if (name.isEmpty) {
                          SnackbarUtils.showError(currentCtx, 'Name is required');
                          return;
                        }
                        if (email.isEmpty || !email.contains('@')) {
                          SnackbarUtils.showError(currentCtx, 'Valid email is required');
                          return;
                        }
                        if (!isEditing && (password.isEmpty || password.length < 6)) {
                          SnackbarUtils.showError(currentCtx, 'Password must be at least 6 characters');
                          return;
                        }
                        if (isEditing && password.isNotEmpty && password.length < 6) {
                          SnackbarUtils.showError(currentCtx, 'Password must be at least 6 characters');
                          return;
                        }
                        if (selectedPermissions.isEmpty) {
                          SnackbarUtils.showError(currentCtx, 'Please select at least one module permission');
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        try {
                          if (isEditing) {
                            final payload = {
                              'name': name,
                              'email': email,
                              'permissions': selectedPermissions.toList(),
                            };
                            if (password.isNotEmpty) {
                              payload['password'] = password;
                            }
                            final res = await _dio.put('/api/employees/${employee['_id'] ?? employee['id']}', data: payload);
                            if (res.statusCode == 200) {
                              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                              if (currentCtx.mounted) {
                                SnackbarUtils.showSuccess(currentCtx, 'Team member updated successfully');
                                _fetchEmployees();
                              }
                            }
                          } else {
                            final payload = {
                              'name': name,
                              'email': email,
                              'password': password,
                              'permissions': selectedPermissions.toList(),
                            };
                            final res = await _dio.post('/api/employees', data: payload);
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                              if (currentCtx.mounted) {
                                SnackbarUtils.showSuccess(currentCtx, 'Team member created and welcome email dispatched!');
                                _fetchEmployees();
                              }
                            }
                          }
                        } on DioException catch (dioErr) {
                          setDialogState(() => isSubmitting = false);
                          final msg = dioErr.response?.data?['error'] ?? dioErr.message ?? 'Operation failed';
                          if (currentCtx.mounted) {
                            SnackbarUtils.showError(currentCtx, msg.toString());
                          }
                        } catch (err) {
                          setDialogState(() => isSubmitting = false);
                          if (currentCtx.mounted) {
                            SnackbarUtils.showError(currentCtx, err.toString());
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(Map<String, dynamic> employee) async {
    final currentStatus = employee['status'] ?? 'active';
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final empId = employee['_id'] ?? employee['id'];

    try {
      final res = await _dio.patch('/api/employees/$empId/status', data: {'status': newStatus});
      if (res.statusCode == 200) {
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Status updated to $newStatus');
          _fetchEmployees();
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _deleteEmployee(Map<String, dynamic> employee) async {
    final empId = employee['_id'] ?? employee['id'];
    final name = employee['name'] ?? 'Member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Team Member?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$name"?\n\nAll contacts and chats currently bound to this employee will automatically be unassigned and returned to the organization pool.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await _dio.delete('/api/employees/$empId');
        if (res.statusCode == 200) {
          if (mounted) {
            SnackbarUtils.showSuccess(context, res.data['message'] ?? 'Team member removed');
            _fetchEmployees();
          }
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to remove team member: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Member Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage employee accounts, configure module access permissions, and oversee chat assignments.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    onPressed: () => _showAddEditEmployeeDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Team Member', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Total Members',
                      value: _employees.length.toString(),
                      icon: Icons.people_alt_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Active Accounts',
                      value: _activeCount.toString(),
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Assigned Chats',
                      value: _totalChatsAssigned.toString(),
                      icon: Icons.forum_outlined,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Bar
              Container(
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
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search team members by name or email...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(value: 'inactive', label: Text('Inactive')),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh list',
                      onPressed: _fetchEmployees,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Employees Table / List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _fetchEmployees, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _filteredEmployees.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 14),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No team members matching "$_searchQuery"'
                                          : 'No team members yet.',
                                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click "Add Team Member" above to create employee accounts.',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListView.separated(
                                  itemCount: _filteredEmployees.length,
                                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (ctx, i) {
                                    final emp = _filteredEmployees[i];
                                    return _buildEmployeeRow(emp);
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> emp) {
    final name = emp['name'] ?? 'Unnamed';
    final email = emp['email'] ?? '';
    final status = emp['status'] ?? 'active';
    final isActive = status == 'active';
    final assignedChats = (emp['assignedChatsCount'] as num?)?.toInt() ?? 0;
    final permissions = List<String>.from(emp['permissions'] ?? []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name & Email
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActive ? Colors.green.shade300 : Colors.grey.shade400),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Assigned Chats Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_rounded, size: 13, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  '$assignedChats active chat${assignedChats == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Module Permissions Chips
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: permissions.take(4).map((p) {
                final label = _availableModules[p] ?? p;
                final icon = _moduleIcons[p];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 12, color: const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList()..addAll(
                permissions.length > 4
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${permissions.length - 4}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        )
                      ]
                    : [],
              ),
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Member & Permissions',
                onPressed: () => _showAddEditEmployeeDialog(employee: emp),
              ),
              IconButton(
                icon: Icon(
                  isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 26,
                ),
                tooltip: isActive ? 'Deactivate Member' : 'Activate Member',
                onPressed: () => _toggleEmployeeStatus(emp),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                tooltip: 'Remove Member',
                onPressed: () => _deleteEmployee(emp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
