import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../utils/firestore_debug_utils.dart';
import '../../utils/app_logger.dart';
import 'enhanced_service_dialog.dart';

class ProviderServicesScreen extends StatefulWidget {
  final app_provider.Provider? provider;
  final VoidCallback? onServiceUpdated;

  const ProviderServicesScreen({
    super.key,
    this.provider,
    this.onServiceUpdated,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload services when the tab becomes visible
    if (widget.provider != null) {
      _loadServices();
    }
  }

  void _loadServices() {
    if (widget.provider != null) {
      AppLogger.debug('ProviderServicesScreen: Loading services from provider object: ${widget.provider!.services.length} services');
      
      // Debug the provider document structure
      FirestoreDebugUtils.debugProviderDocument(widget.provider!.providerId);
      
      setState(() {
        _services = List.from(widget.provider!.services);
        _isLoading = false;
      });
      AppLogger.debug('ProviderServicesScreen: Loaded ${_services.length} services into local state');
    } else {
      AppLogger.debug('ProviderServicesScreen: No provider object available');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServices() async {
    if (widget.provider == null) return;

    try {
      final servicesData = _services.map((service) => service.toMap()).toList();
      AppLogger.debug('ProviderServicesScreen: Saving ${_services.length} services to Firestore');
      AppLogger.debug('ProviderServicesScreen: Services data to save: $servicesData');
      
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.provider!.providerId)
          .update({'services': servicesData});

      if (mounted) {
        AppLogger.debug('ProviderServicesScreen: Services saved successfully, reloading from Firestore');
        // Reload services from Firestore to ensure consistency
        await _loadServicesFromFirestore();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Services updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        
        // Notify parent widget to reload data
        if (widget.onServiceUpdated != null) {
          AppLogger.debug('ProviderServicesScreen: Calling onServiceUpdated callback');
          widget.onServiceUpdated!();
        }
      }
    } catch (e) {
      AppLogger.debug('ProviderServicesScreen: Error saving services: $e');
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

  Future<void> _loadServicesFromFirestore() async {
    if (widget.provider == null) return;

    try {
      AppLogger.debug('ProviderServicesScreen: Loading services from Firestore for provider: ${widget.provider!.providerId}');
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.provider!.providerId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        AppLogger.debug('ProviderServicesScreen: Provider document exists, data keys: ${data?.keys.toList()}');
        if (data != null && data['services'] != null) {
          final servicesList = data['services'] as List<dynamic>;
          AppLogger.debug('ProviderServicesScreen: Found ${servicesList.length} services in Firestore');
          setState(() {
            _services = servicesList.map((serviceData) {
              return app_provider.Service.fromMap(serviceData as Map<String, dynamic>);
            }).toList();
          });
          AppLogger.debug('ProviderServicesScreen: Loaded ${_services.length} services into local state');
        } else {
          AppLogger.debug('ProviderServicesScreen: No services field found in provider document');
        }
      } else {
        AppLogger.debug('ProviderServicesScreen: Provider document does not exist in Firestore');
      }
    } catch (e) {
      AppLogger.debug('Error loading services from Firestore: $e');
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
                        icon: const Icon(Icons.add),
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
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
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
                Expanded(
                  child: Text(
                    service.title,
                    style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
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
            Row(
              children: [
                if (service.type == 'priced') ...[
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    service.priceFrom != null && service.priceTo != null
                        ? 'K${service.priceFrom!.toStringAsFixed(0)} - K${service.priceTo!.toStringAsFixed(0)}'
                        : 'Pricing not set',
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
                    service.duration ?? 'Duration not set',
                    style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                  ),
                ] else if (service.type == 'negotiable') ...[
                  Icon(
                    Icons.handshake,
                    size: 16,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Price negotiable',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (service.type == 'free') ...[
                  Icon(
                    Icons.volunteer_activism,
                    size: 16,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free service',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Using EnhancedServiceDialog instead of the simple _ServiceDialog
