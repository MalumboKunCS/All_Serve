import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/service_category.dart';

class ServiceSelectionDialog extends StatefulWidget {
  final app_provider.Provider provider;
  final app_provider.Service? selectedService;

  const ServiceSelectionDialog({
    super.key,
    required this.provider,
    this.selectedService,
  });

  @override
  State<ServiceSelectionDialog> createState() => _ServiceSelectionDialogState();
}

class _ServiceSelectionDialogState extends State<ServiceSelectionDialog> {
  app_provider.Service? _selectedService;
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  List<app_provider.Service> _filteredServices = [];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.selectedService;
    _filteredServices = widget.provider.services;
    _searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterServices() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredServices = widget.provider.services.where((service) {
        final matchesSearch = service.title.toLowerCase().contains(query) ||
            (service.description?.toLowerCase().contains(query) ?? false);
        final matchesCategory = _selectedCategory == 'all' || 
            service.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _selectService(app_provider.Service service) {
    setState(() {
      _selectedService = service;
    });
  }

  void _confirmSelection() {
    if (_selectedService != null) {
      Navigator.of(context).pop(_selectedService);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.provider.logoUrl != null
                        ? (widget.provider.logoUrl != null && widget.provider.logoUrl!.isNotEmpty)
                          ? NetworkImage(widget.provider.logoUrl!)
                          : null
                        : null,
                    child: widget.provider.logoUrl == null
                        ? Icon(Icons.business, color: AppTheme.primaryPurple)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Service',
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          widget.provider.businessName,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            // Search and Filter
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search services...',
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Category Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('all', 'All Services'),
                        const SizedBox(width: 8),
                        ...ServiceCategories.defaultCategories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryChip(category.id, category.name),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Services List
            Expanded(
              child: _filteredServices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No services found',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            'Try adjusting your search or filter',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredServices.length,
                      itemBuilder: (context, index) {
                        final service = _filteredServices[index];
                        final isSelected = _selectedService?.serviceId == service.serviceId;
                        
                        return _buildServiceCard(service, isSelected);
                      },
                    ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: AppTheme.outlineButtonStyle,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedService != null ? _confirmSelection : null,
                      style: AppTheme.primaryButtonStyle,
                      child: Text(_selectedService?.serviceType == 'contact' ? 'Contact Provider' : 'Select Service'),
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

  Widget _buildCategoryChip(String categoryId, String categoryName) {
    final isSelected = _selectedCategory == categoryId;
    
    return FilterChip(
      label: Text(categoryName),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? categoryId : 'all';
          _filterServices();
        });
      },
      selectedColor: AppTheme.primaryPurple.withValues(alpha:0.3),
      checkmarkColor: AppTheme.textPrimary,
      labelStyle: AppTheme.bodyMedium.copyWith(
        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
      ),
      backgroundColor: AppTheme.cardDark,
    );
  }

  Widget _buildServiceCard(app_provider.Service service, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryPurple.withValues(alpha:0.1) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.textTertiary.withValues(alpha:0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectService(service),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Service Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: service.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            service.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.miscellaneous_services,
                              color: AppTheme.primaryPurple,
                              size: 30,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.miscellaneous_services,
                          color: AppTheme.primaryPurple,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),

                // Service Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.category.toUpperCase(),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Service Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: service.serviceType == 'bookable' 
                              ? AppTheme.success.withValues(alpha: 0.2)
                              : AppTheme.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.serviceType == 'bookable' ? 'BOOKABLE' : 'CONTACT',
                          style: AppTheme.caption.copyWith(
                            color: service.serviceType == 'bookable' 
                                ? AppTheme.success
                                : AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      if (service.description != null && service.description!.isNotEmpty)
                        Text(
                          service.description!,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 8),

                      // Price and Duration
                      Row(
                        children: [
                          if (service.type == 'priced' && service.priceFrom != null && service.priceTo != null) ...[
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'K${service.priceFrom!.toStringAsFixed(0)} - K${service.priceTo!.toStringAsFixed(0)}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (service.type == 'negotiable') ...[
                            Icon(
                              Icons.handshake,
                              size: 16,
                              color: AppTheme.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Negotiable',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (service.type == 'free') ...[
                            Icon(
                              Icons.volunteer_activism,
                              size: 16,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Free',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            service.duration ?? 'Not specified',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Availability
                      if (service.availability.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: service.availability.take(3).map((day) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                day.isNotEmpty 
                                  ? day.substring(0, 1).toUpperCase() + (day.length > 1 ? day.substring(1) : '')
                                  : day,
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.primaryPurple,
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

                // Selection Indicator
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



