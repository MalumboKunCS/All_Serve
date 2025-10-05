import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;

class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  final shared.AdminManagementService _adminManagementService = shared.AdminManagementService();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
    _loadAdmins();
  }

  Future<void> _checkSuperAdminStatus() async {
    try {
      final authService = context.read<shared.AuthService>();
      final currentUser = await authService.getCurrentUserWithData();
      if (currentUser != null) {
        final isSuper = await _adminManagementService.isSuperAdmin(currentUser.uid);
        if (mounted) {
          setState(() => _isSuperAdmin = isSuper);
        }
      }
    } catch (e) {
      print('Error checking super admin status: $e');
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final admins = await _adminManagementService.getAllAdmins();
      if (mounted) {
        setState(() => _admins = admins);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading admins: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createAdmin() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateAdminDialog(),
    );

    if (result != null && result['success'] == true) {
      _loadAdmins();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (result != null && result['success'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAdminStatus(Map<String, dynamic> admin) async {
    final isActive = admin['isActive'] == true;
    final action = isActive ? 'deactivate' : 'reactivate';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(
          '$action Admin',
          style: shared.AppTheme.heading3.copyWith(
            color: shared.AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to $action ${admin['name']}?',
          style: shared.AppTheme.bodyMedium.copyWith(
            color: shared.AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: shared.AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            child: Text(isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = context.read<shared.AuthService>();
        final currentUser = await authService.getCurrentUserWithData();
        
        if (currentUser != null) {
          Map<String, dynamic> result;
          if (isActive) {
            result = await _adminManagementService.deactivateAdmin(
              adminUid: admin['uid'],
              deactivatedBy: currentUser.uid,
              reason: 'Deactivated by super admin',
            );
          } else {
            result = await _adminManagementService.reactivateAdmin(
              adminUid: admin['uid'],
              reactivatedBy: currentUser.uid,
            );
          }

          if (result['success'] == true) {
            _loadAdmins();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message']),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error']),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: shared.AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied', 
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Admin Management',
                style: shared.AppTheme.heading1.copyWith(
                  color: shared.AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createAdmin,
                icon: const Icon(Icons.person_add),
                label: const Text('Create Admin'),
                style: shared.AppTheme.primaryButtonStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage admin users and their permissions',
            style: shared.AppTheme.bodyLarge.copyWith(
              color: shared.AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Admins Table
          Expanded(
            child: Card(
              color: shared.AppTheme.cardDark,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _admins.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 64,
                                  color: shared.AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No admins found',
                                  style: shared.AppTheme.heading3.copyWith(
                                    color: shared.AppTheme.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first admin user',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    color: shared.AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 800,
                            columns: [
                              DataColumn2(
                                label: Text(
                                  'Admin',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: shared.AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              DataColumn2(
                                label: Text(
                                  'Role',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: shared.AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              DataColumn2(
                                label: Text(
                                  'Status',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: shared.AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              DataColumn2(
                                label: Text(
                                  'Created',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: shared.AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              DataColumn2(
                                label: Text(
                                  'Actions',
                                  style: shared.AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: shared.AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                            rows: _admins.map((admin) {
                              final isActive = admin['isActive'] == true;
                              final isSuper = admin['isSuperAdmin'] == true;
                              final createdAt = admin['createdAt'];
                              
                              return DataRow2(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isSuper 
                                              ? shared.AppTheme.warning 
                                              : shared.AppTheme.primaryPurple,
                                          child: Text(
                                            admin['name']?.toString().isNotEmpty == true 
                                              ? admin['name']!.toString().substring(0, 1).toUpperCase()
                                              : 'A',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              admin['name'] ?? 'Unknown',
                                              style: shared.AppTheme.bodyMedium.copyWith(
                                                color: shared.AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              admin['email'] ?? 'No email',
                                              style: shared.AppTheme.caption.copyWith(
                                                color: shared.AppTheme.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSuper 
                                            ? shared.AppTheme.warning.withValues(alpha: 0.1)
                                            : shared.AppTheme.primaryPurple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSuper 
                                              ? shared.AppTheme.warning
                                              : shared.AppTheme.primaryPurple,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        isSuper ? 'Super Admin' : 'Admin',
                                        style: shared.AppTheme.caption.copyWith(
                                          color: isSuper 
                                              ? shared.AppTheme.warning
                                              : shared.AppTheme.primaryPurple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive 
                                            ? shared.AppTheme.success.withValues(alpha: 0.1)
                                            : shared.AppTheme.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive 
                                              ? shared.AppTheme.success
                                              : shared.AppTheme.error,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: shared.AppTheme.caption.copyWith(
                                          color: isActive 
                                              ? shared.AppTheme.success
                                              : shared.AppTheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      createdAt != null 
                                          ? _formatDate(createdAt is Timestamp ? createdAt.toDate() : DateTime.now())
                                          : 'Unknown',
                                      style: shared.AppTheme.bodyMedium.copyWith(
                                        color: shared.AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _toggleAdminStatus(admin),
                                          icon: Icon(
                                            isActive ? Icons.person_off : Icons.person_add,
                                            color: isActive ? Colors.red : Colors.green,
                                          ),
                                          tooltip: isActive ? 'Deactivate' : 'Reactivate',
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
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class CreateAdminDialog extends StatefulWidget {
  const CreateAdminDialog({super.key});

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSuperAdmin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<shared.AuthService>();
      final currentUser = await authService.getCurrentUserWithData();
      
      if (currentUser != null) {
        final adminManagementService = shared.AdminManagementService();
        final result = await adminManagementService.createAdmin(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          isSuperAdmin: _isSuperAdmin,
          createdBy: currentUser.uid,
        );

        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, {
          'success': false,
          'error': e.toString(),
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: shared.AppTheme.cardDark,
      title: Text(
        'Create New Admin',
        style: shared.AppTheme.heading3.copyWith(
          color: shared.AppTheme.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!_isValidEmail(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(
                  'Super Admin',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Can manage other admins',
                  style: shared.AppTheme.caption.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
                value: _isSuperAdmin,
                onChanged: (value) {
                  setState(() => _isSuperAdmin = value ?? false);
                },
                activeColor: shared.AppTheme.primaryPurple,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: shared.AppTheme.textTertiary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAdmin,
          style: shared.AppTheme.primaryButtonStyle,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Admin'),
        ),
      ],
    );
  }
}
