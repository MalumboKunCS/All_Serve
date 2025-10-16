import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;

class AnnouncementDialog extends StatefulWidget {
  final Function({
    required String title,
    required String message,
    required String audience,
    List<String> specificUserIds,
    List<String> targetCategories,
    String priority,
    String type,
    DateTime? expiresAt,
  }) onSend;

  const AnnouncementDialog({
    super.key,
    required this.onSend,
  });

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedAudience = 'all';
  String _selectedPriority = 'medium';
  String _selectedType = 'info';
  List<String> _selectedUserIds = [];
  List<String> _selectedCategories = [];
  DateTime? _expiresAt;
  bool _hasExpiry = false;
  
  List<shared.User> _allUsers = [];
  List<shared.User> _filteredUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    
    try {
      _allUsers = await shared.AdminService.getUsersForTargeting();
      _filteredUsers = List.from(_allUsers);
    } catch (e) {
      print('Error loading users: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: shared.AppTheme.primaryPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (selectedDate != null) {
      setState(() => _expiresAt = selectedDate);
    }
  }

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate audience-specific requirements
    if (_selectedAudience == 'specific' && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one user for specific audience'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onSend(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        audience: _selectedAudience,
        specificUserIds: _selectedUserIds,
        targetCategories: _selectedCategories,
        priority: _selectedPriority,
        type: _selectedType,
        expiresAt: _hasExpiry ? _expiresAt : null,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: shared.AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: shared.AppTheme.cardDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: shared.AppTheme.primaryPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Announcement',
                    style: shared.AppTheme.heading2.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: shared.AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic information
                      _buildBasicInfoSection(),
                      const SizedBox(height: 16),
                      
                      // Audience selection
                      _buildAudienceSection(),
                      const SizedBox(height: 16),
                      
                      // Settings
                      _buildSettingsSection(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: shared.AppTheme.cardDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: shared.AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendAnnouncement,
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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send, size: 18),
                              const SizedBox(width: 8),
                              const Text('Send Announcement'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      color: shared.AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcement Details',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Announcement Title',
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Message Field
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Message',
                prefixIcon: const Icon(Icons.message),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                if (value.trim().length < 10) {
                  return 'Message must be at least 10 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceSection() {
    return Card(
      color: shared.AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Audience',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Audience options
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildAudienceChip('all', 'All Users', Icons.people),
                _buildAudienceChip('customers', 'Customers Only', Icons.person),
                _buildAudienceChip('providers', 'Providers Only', Icons.business),
                _buildAudienceChip('admins', 'Admins Only', Icons.admin_panel_settings),
                _buildAudienceChip('specific', 'Specific Users', Icons.person_add),
              ],
            ),
            
            // Specific user selection
            if (_selectedAudience == 'specific') ...[
              const SizedBox(height: 16),
              Text(
                'Select Users',
                style: shared.AppTheme.bodyLarge.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _searchController,
                decoration: shared.AppTheme.inputDecoration.copyWith(
                  labelText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingUsers)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: shared.AppTheme.cardLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUserIds.contains(user.uid);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected 
                              ? shared.AppTheme.primaryPurple
                              : shared.AppTheme.cardDark,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: isSelected ? Colors.white : shared.AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: shared.AppTheme.bodyMedium.copyWith(
                            color: shared.AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${user.email} • ${user.role}',
                          style: shared.AppTheme.caption.copyWith(
                            color: shared.AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedUserIds.add(user.uid);
                              } else {
                                _selectedUserIds.remove(user.uid);
                              }
                            });
                          },
                          activeColor: shared.AppTheme.primaryPurple,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(user.uid);
                            } else {
                              _selectedUserIds.add(user.uid);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              if (_selectedUserIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _selectedUserIds.map((userId) {
                    final user = _allUsers.firstWhere((u) => u.uid == userId);
                    return Chip(
                      label: Text(user.name),
                      onDeleted: () {
                        setState(() => _selectedUserIds.remove(userId));
                      },
                      backgroundColor: shared.AppTheme.primaryPurple.withValues(alpha:0.2),
                      deleteIconColor: shared.AppTheme.primaryPurple,
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceChip(String value, String label, IconData icon) {
    final isSelected = _selectedAudience == value;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedAudience = value;
            if (value != 'specific') {
              _selectedUserIds.clear();
            }
          });
        }
      },
      backgroundColor: shared.AppTheme.cardDark,
      selectedColor: shared.AppTheme.primaryPurple.withValues(alpha:0.3),
      checkmarkColor: shared.AppTheme.primaryPurple,
      labelStyle: shared.AppTheme.bodyMedium.copyWith(
        color: isSelected ? shared.AppTheme.primaryPurple : shared.AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      color: shared.AppTheme.cardDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcement Settings',
              style: shared.AppTheme.heading3.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Priority selection
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Priority Level',
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) => setState(() => _selectedPriority = value!),
            ),
            const SizedBox(height: 16),
            
            // Type selection
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'Announcement Type',
              ),
              items: const [
                DropdownMenuItem(value: 'info', child: Text('Information')),
                DropdownMenuItem(value: 'warning', child: Text('Warning')),
                DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'update', child: Text('Update')),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            
            // Expiry toggle
            Row(
              children: [
                Checkbox(
                  value: _hasExpiry,
                  onChanged: (value) {
                    setState(() {
                      _hasExpiry = value ?? false;
                      if (!_hasExpiry) _expiresAt = null;
                    });
                  },
                  activeColor: shared.AppTheme.primaryPurple,
                ),
                Text(
                  'Set expiration date',
                  style: shared.AppTheme.bodyMedium.copyWith(
                    color: shared.AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            
            // Expiry date picker
            if (_hasExpiry) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectExpiryDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: shared.AppTheme.cardLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: shared.AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _expiresAt != null
                            ? 'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                            : 'Select expiry date',
                        style: shared.AppTheme.bodyMedium.copyWith(
                          color: _expiresAt != null 
                              ? shared.AppTheme.textPrimary 
                              : shared.AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

