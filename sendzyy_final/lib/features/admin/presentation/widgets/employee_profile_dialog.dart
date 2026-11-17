import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/services/country_code_service.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/default_country_tile.dart';

class EmployeeProfileDialog extends StatefulWidget {
  const EmployeeProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const EmployeeProfileDialog(),
      );
    }
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => const EmployeeProfileDialog(),
    );
  }

  @override
  State<EmployeeProfileDialog> createState() => _EmployeeProfileDialogState();
}

class _EmployeeProfileDialogState extends State<EmployeeProfileDialog> {
  final Dio _dio = getIt<Dio>();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  // Password change state
  bool _showPasswordForm = false;
  bool _isSavingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Name edit state
  bool _isEditingName = false;
  bool _isSavingName = false;
  final TextEditingController _nameController = TextEditingController();

  final Map<String, String> _moduleLabels = {
    'chat': 'Chats & Inbox',
    'broadcast': 'Broadcast Campaigns',
    'templates': 'Template Manager',
    'clients': 'Clients & Contacts',
    'leads': 'Lead Management',
    'reports': 'Reports (Compulsory)',
    'chatbot': 'AI Chatbot & Automation',
    'catalog': 'Product Catalog',
    'whatsapp_flows': 'WhatsApp Flows',
    'instagram': 'Instagram Messaging',
    'help': 'Help & FAQ',
  };

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _dio.get('/api/employees/me/profile');
      if (res.statusCode == 200 && res.data['employee'] != null) {
        if (mounted) {
          setState(() {
            _profileData = Map<String, dynamic>.from(res.data['employee']);
            _nameController.text = _profileData!['name'] ?? '';
            _isLoading = false;
          });
          final empCountry = _profileData!['defaultCountry']?.toString();
          if (empCountry != null && empCountry.isNotEmpty) {
            CountryCodeService.instance.setIsoLocally(empCountry);
          }
        }
        return;
      }
    } catch (e) {
      debugPrint('[EmployeeProfileDialog] Error fetching remote profile: $e');
    }

    // Fallback to local AuthBloc state if remote call fails
    if (mounted) {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        setState(() {
          _profileData = {
            'name': auth.employeeName ?? auth.user,
            'email': auth.employeeEmail ?? '',
            'role': 'employee',
            'status': 'active',
            'permissions': auth.permissions,
            'tenantName': auth.tenant['name'] ?? 'Your Organization',
            'assignedChatsCount': 0,
          };
          _nameController.text = _profileData!['name'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackbarUtils.showError(context, 'Name cannot be empty');
      return;
    }

    setState(() => _isSavingName = true);
    try {
      final res = await _dio.put('/api/employees/me/profile', data: {'name': newName});
      if (res.statusCode == 200) {
        if (mounted) {
          context.read<AuthBloc>().add(UpdateEmployeeName(newName));
          setState(() {
            _profileData!['name'] = newName;
            _isEditingName = false;
            _isSavingName = false;
          });
          SnackbarUtils.showSuccess(context, 'Profile name updated');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingName = false);
        SnackbarUtils.showError(context, 'Failed to update name: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty) {
      SnackbarUtils.showError(context, 'Please enter your current password');
      return;
    }
    if (newPass.length < 6) {
      SnackbarUtils.showError(context, 'New password must be at least 6 characters');
      return;
    }
    if (newPass != confirmPass) {
      SnackbarUtils.showError(context, 'New passwords do not match');
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      final res = await _dio.put('/api/employees/me/profile', data: {
        'currentPassword': currentPass,
        'newPassword': newPass,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          setState(() {
            _showPasswordForm = false;
            _isSavingPassword = false;
          });
          SnackbarUtils.showSuccess(context, 'Password changed successfully');
        }
      }
    } on DioException catch (dioErr) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        final msg = dioErr.response?.data?['error'] ?? dioErr.message ?? 'Password change failed';
        SnackbarUtils.showError(context, msg.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        SnackbarUtils.showError(context, 'Failed to change password: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    final content = _isLoading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        : _buildProfileContent(isMobile);

    if (isMobile) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              content,
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDesktopHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Team Member Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(bool isMobile) {
    final name = _profileData?['name'] ?? 'Team Member';
    final email = _profileData?['email'] ?? '';
    final tenantName = _profileData?['tenantName'] ?? 'Organization';
    final assignedChatsCount = _profileData?['assignedChatsCount'] ?? 0;
    final createdAtRaw = _profileData?['createdAt'];
    DateTime? joinedDate;
    if (createdAtRaw != null) {
      joinedDate = DateTime.tryParse(createdAtRaw.toString())?.toLocal();
    }

    final rawPermissions = _profileData?['permissions'] as List? ?? ['reports'];
    final permissions = List<String>.from(rawPermissions);
    if (!permissions.contains('reports')) permissions.add('reports');

    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'M';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card 1: Identity & Avatar Banner ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditingName)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: _isSavingName
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check, size: 20, color: Colors.green),
                            onPressed: _isSavingName ? null : _updateName,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _isEditingName = false;
                                _nameController.text = name;
                              });
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _isEditingName = true),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.secondaryColor),
                              SizedBox(width: 4),
                              Text(
                                'Team Member',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Active Status',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Card 2: Organization & Workload Stats ─────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
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
                        Icon(Icons.business_rounded, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        const Text(
                          'Organization',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tenantName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
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
                        const Icon(Icons.forum_outlined, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        const Text(
                          'Assigned Chats',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$assignedChatsCount active',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (joinedDate != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Joined organization on ${DateFormat.yMMMd().format(joinedDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Default Country Code ──────────────────────────────────────────
        DefaultCountryCodeTile(
          onCountryChanged: () {
            if (mounted) {
              setState(() {
                if (_profileData != null) {
                  _profileData!['defaultCountry'] = CountryCodeService.instance.defaultIso;
                }
              });
            }
          },
        ),

        const SizedBox(height: 20),

        // ── Section 3: Granted Module Permissions ─────────────────────────
        Row(
          children: [
            const Icon(Icons.security_rounded, size: 18, color: AppTheme.secondaryColor),
            const SizedBox(width: 8),
            const Text(
              'Granted Modules & Access',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions.map((p) {
            final isReports = p == 'reports';
            final label = _moduleLabels[p] ?? p;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isReports
                    ? Colors.teal.withValues(alpha: 0.12)
                    : AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isReports
                      ? Colors.teal.withValues(alpha: 0.35)
                      : AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isReports ? Icons.verified_rounded : Icons.check_circle_outline,
                    size: 14,
                    color: isReports ? Colors.teal.shade700 : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isReports ? Colors.teal.shade800 : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        // ── Section 4: Security & Password Update ──────────────────────────
        InkWell(
          onTap: () {
            setState(() => _showPasswordForm = !_showPasswordForm);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, size: 16, color: Colors.orange),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Change Account Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
                Icon(
                  _showPasswordForm ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        if (_showPasswordForm) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: 'Current Password',
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: 'New Password (min 6 characters)',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ).buildButton(
                    onPressed: _isSavingPassword ? null : _changePassword,
                    child: _isSavingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save New Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

extension ButtonStyleBuilder on ButtonStyle {
  Widget buildButton({required VoidCallback? onPressed, required Widget child}) {
    return ElevatedButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
