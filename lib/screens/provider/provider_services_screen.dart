import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import 'enhanced_service_dialog.dart';

class ProviderServicesScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderServicesScreen({
    super.key,
    this.provider,
  });

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  List<app_provider.Service> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _loadServices() {
    if (widget.provider != null) {
      setState(() {
        _services = List.from(widget.provider!.services);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServices() async {
    if (widget.provider == null) return;

    try {
      final servicesData = _services.map((service) => service.toMap()).toList();
      
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.provider!.providerId)
          .update({'services': servicesData});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Services updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update services: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => EnhancedServiceDialog(
        onSave: (service) {
          setState(() {
            _services.add(service);
          });
          _saveServices();
        },
      ),
    );
  }

  void _showEditServiceDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => EnhancedServiceDialog(
        service: _services[index],
        onSave: (service) {
          setState(() {
            _services[index] = service;
          });
          _saveServices();
        },
      ),
    );
  }

  void _deleteService(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Delete Service',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${_services[index].title}"?',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _services.removeAt(index);
              });
              _saveServices();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Manage Services'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Services (${_services.length})',
                          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddServiceDialog,
                        style: AppTheme.primaryButtonStyle,
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Add Service'),
                      ),
                    ],
                  ),
                ),

                // Services List
                Expanded(
                  child: _services.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            return _buildServiceCard(service, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Services Added',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first service to start receiving bookings',
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddServiceDialog,
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.add_circle),
            label: const Text('Add New Service'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(app_provider.Service service, int index) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Service Image
                if (service.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      service.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image,
                          color: AppTheme.primary,
                          size: 30,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service.category.toUpperCase(),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  color: AppTheme.surfaceDark,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppTheme.textPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      onTap: () => _showEditServiceDialog(index),
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ],
                      ),
                      onTap: () => _deleteService(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Description
            if (service.description != null && service.description!.isNotEmpty) ...[
              Text(
                service.description!,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            
            // Price and Duration
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'K${service.priceFrom.toStringAsFixed(0)} - K${service.priceTo.toStringAsFixed(0)}',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${service.durationMin} minutes',
                  style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            
            // Availability
            if (service.availability.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: service.availability.map((day) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      day.isNotEmpty 
                        ? day.substring(0, 1).toUpperCase() + (day.length > 1 ? day.substring(1) : '')
                        : day,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  final app_provider.Service? service;
  final Function(app_provider.Service) onSave;

  const _ServiceDialog({
    super.key,
    this.service,
    required this.onSave,
  });

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _titleController.text = widget.service!.title;
      _priceFromController.text = widget.service!.priceFrom.toString();
      _priceToController.text = widget.service!.priceTo.toString();
      _durationController.text = widget.service!.durationMin.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final service = app_provider.Service(
      serviceId: widget.service?.serviceId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      category: 'general',
      priceFrom: double.parse(_priceFromController.text),
      priceTo: double.parse(_priceToController.text),
      durationMin: int.parse(_durationController.text),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(service);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(
        widget.service != null ? 'Edit Service' : 'Add Service',
        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Service Title',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter service title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceFromController,
                      decoration: AppTheme.inputDecoration.copyWith(
                        labelText: 'Price From (K)',
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceToController,
                      decoration: AppTheme.inputDecoration.copyWith(
                        labelText: 'Price To (K)',
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null) {
                          return 'Invalid price';
                        }
                        final fromPrice = double.tryParse(_priceFromController.text);
                        if (fromPrice != null && price < fromPrice) {
                          return 'Must be >= from price';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Duration (minutes)',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter duration';
                  }
                  final duration = int.tryParse(value);
                  if (duration == null || duration <= 0) {
                    return 'Enter valid duration';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: AppTheme.primaryButtonStyle,
          child: Text(widget.service != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
