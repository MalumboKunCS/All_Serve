import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../utils/firestore_debug_utils.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';
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
        title: Text(
          'Manage Services',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 22,
            ),
          ),
        ),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : ResponsiveLayoutBuilder(
              builder: (context, screenType) {
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: ResponsiveUtils.getResponsivePadding(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Your Services (${_services.length})',
                              style: AppTheme.heading3.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 18,
                                  tablet: 20,
                                  desktop: 22,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: AppTheme.spacingSm,
                            tablet: AppTheme.spacingMd,
                            desktop: AppTheme.spacingLg,
                          )),
                          ElevatedButton.icon(
                            onPressed: _showAddServiceDialog,
                            style: AppTheme.primaryButtonStyle,
                            icon: Icon(
                              Icons.add,
                              size: ResponsiveUtils.getResponsiveIconSize(
                                context,
                                mobile: 18,
                                tablet: 20,
                                desktop: 22,
                              ),
                            ),
                            label: Text(
                              'Add Service',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 16,
                                  desktop: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Services List
                    Expanded(
                      child: _services.isEmpty
                          ? _buildEmptyState()
                          : ResponsiveContainer(
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.getResponsiveSpacing(
                                    context,
                                    mobile: AppTheme.spacingMd,
                                    tablet: AppTheme.spacingLg,
                                    desktop: AppTheme.spacingXl,
                                  ),
                                ),
                                itemCount: _services.length,
                                itemBuilder: (context, index) {
                                  final service = _services[index];
                                  return _buildServiceCard(service, index);
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
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
            size: ResponsiveUtils.getResponsiveIconSize(
              context,
              mobile: 56,
              tablet: 64,
              desktop: 72,
            ),
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: AppTheme.spacingMd,
            tablet: AppTheme.spacingLg,
            desktop: AppTheme.spacingXl,
          )),
          Text(
            'No Services Added',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 20,
                tablet: 22,
                desktop: 24,
              ),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: AppTheme.spacingSm,
            tablet: AppTheme.spacingMd,
            desktop: AppTheme.spacingLg,
          )),
          Text(
            'Add your first service to start receiving bookings',
            style: AppTheme.bodyText.copyWith(
              color: AppTheme.textSecondary,
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: AppTheme.spacingLg,
            tablet: AppTheme.spacingXl,
            desktop: AppTheme.spacingXxl,
          )),
          ElevatedButton.icon(
            onPressed: _showAddServiceDialog,
            style: AppTheme.primaryButtonStyle,
            icon: Icon(
              Icons.add,
              size: ResponsiveUtils.getResponsiveIconSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
            ),
            label: Text(
              'Add Service',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(app_provider.Service service, int index) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(
        context,
        mobile: AppTheme.spacingMd,
        tablet: AppTheme.spacingLg,
        desktop: AppTheme.spacingXl,
      )),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.textSecondary,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
                  color: AppTheme.surfaceDark,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: AppTheme.textPrimary,
                            size: ResponsiveUtils.getResponsiveIconSize(
                              context,
                              mobile: 18,
                              tablet: 20,
                              desktop: 22,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: AppTheme.spacingSm,
                            tablet: AppTheme.spacingMd,
                            desktop: AppTheme.spacingLg,
                          )),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 16,
                                desktop: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showEditServiceDialog(index),
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: AppTheme.error,
                            size: ResponsiveUtils.getResponsiveIconSize(
                              context,
                              mobile: 18,
                              tablet: 20,
                              desktop: 22,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: AppTheme.spacingSm,
                            tablet: AppTheme.spacingMd,
                            desktop: AppTheme.spacingLg,
                          )),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 16,
                                desktop: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _deleteService(index),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: AppTheme.spacingMd,
              tablet: AppTheme.spacingLg,
              desktop: AppTheme.spacingXl,
            )),
            Row(
              children: [
                if (service.type == 'priced') ...[
                  Icon(
                    Icons.attach_money,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: AppTheme.success,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingXs,
                    tablet: AppTheme.spacingSm,
                    desktop: AppTheme.spacingMd,
                  )),
                  Text(
                    service.priceFrom != null && service.priceTo != null
                        ? 'K${service.priceFrom!.toStringAsFixed(0)} - K${service.priceTo!.toStringAsFixed(0)}'
                        : 'Pricing not set',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingMd,
                    tablet: AppTheme.spacingLg,
                    desktop: AppTheme.spacingXl,
                  )),
                  Icon(
                    Icons.schedule,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingXs,
                    tablet: AppTheme.spacingSm,
                    desktop: AppTheme.spacingMd,
                  )),
                  Text(
                    service.duration ?? 'Duration not set',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                    ),
                  ),
                ] else if (service.type == 'negotiable') ...[
                  Icon(
                    Icons.handshake,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: AppTheme.warning,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingXs,
                    tablet: AppTheme.spacingSm,
                    desktop: AppTheme.spacingMd,
                  )),
                  Text(
                    'Price negotiable',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                    ),
                  ),
                ] else if (service.type == 'free') ...[
                  Icon(
                    Icons.volunteer_activism,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    color: AppTheme.info,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: AppTheme.spacingXs,
                    tablet: AppTheme.spacingSm,
                    desktop: AppTheme.spacingMd,
                  )),
                  Text(
                    'Free service',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.info,
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
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
