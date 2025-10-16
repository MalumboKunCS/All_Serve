import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import 'package:shared/shared.dart' as shared;
import '../../services/enhanced_booking_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/contact_info_section.dart';
import 'service_selection_dialog.dart';
import 'location_picker_screen.dart';
import 'booking_status_screen.dart';

class BookingScreen extends StatefulWidget {
  final app_provider.Provider provider;
  final app_provider.Service? selectedService;

  const BookingScreen({
    super.key,
    required this.provider,
    this.selectedService,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Customer contact information controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  app_provider.Service? _selectedService;
  bool _isLoading = false;
  Map<String, dynamic>? _currentLocation;
  List<String> _availableTimeSlots = [];
  bool _isCheckingAvailability = false;
  String? _selectedTimeSlot;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.selectedService;
    _loadUserDefaultAddress();
    _loadUserContactInfo();
  }

  Future<void> _loadUserDefaultAddress() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user?.defaultAddress != null) {
        final address = user!.defaultAddress!;
        _addressController.text = address['address'] ?? '';
      }
    } catch (e) {
      AppLogger.debug('Error loading default address: $e');
    }
  }

  Future<void> _loadUserContactInfo() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        _fullNameController.text = user.name;
        _phoneController.text = user.phone;
        _emailController.text = user.email;
      }
    } catch (e) {
      AppLogger.debug('Error loading user contact info: $e');
    }
  }

  Future<void> _selectService() async {
    final selectedService = await showDialog<app_provider.Service>(
      context: context,
      builder: (context) => ServiceSelectionDialog(
        provider: widget.provider,
        selectedService: _selectedService,
      ),
    );

    if (selectedService != null) {
      setState(() {
        _selectedService = selectedService;
        _selectedDate = null;
        _selectedTime = null;
        _selectedTimeSlot = null;
        _availableTimeSlots.clear();
      });
      
      // If it's a contact service, show contact info dialog
      if (selectedService.serviceType == 'contact') {
        _showContactInfoDialog(selectedService);
      }
    }
  }

  Future<void> _checkAvailability() async {
    if (_selectedService == null || _selectedDate == null) return;

    setState(() {
      _isCheckingAvailability = true;
    });

    try {
      final timeSlots = await EnhancedBookingService.getAvailableTimeSlots(
        providerId: widget.provider.providerId,
        date: _selectedDate!,
        durationMinutes: _getDurationInMinutes(_selectedService!.duration),
      );

      setState(() {
        _availableTimeSlots = timeSlots.map((slot) => slot.formattedTime).toList();
        _isCheckingAvailability = false;
      });

      if (_availableTimeSlots.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No available time slots for the selected date'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isCheckingAvailability = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking availability: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }



  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  int _getDurationInMinutes(String? duration) {
    if (duration == null || duration.isEmpty) return 60; // Default to 1 hour
    
    // Parse duration string like "60 minutes", "2 hours", "1.5 hours", etc.
    final durationLower = duration.toLowerCase();
    
    if (durationLower.contains('hour')) {
      final hourMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(duration);
      if (hourMatch != null) {
        final hours = double.parse(hourMatch.group(1)!);
        return (hours * 60).round();
      }
    } else if (durationLower.contains('minute')) {
      final minuteMatch = RegExp(r'(\d+)').firstMatch(duration);
      if (minuteMatch != null) {
        return int.parse(minuteMatch.group(1)!);
      }
    } else {
      // Try to parse as number (assume minutes)
      final numberMatch = RegExp(r'(\d+)').firstMatch(duration);
      if (numberMatch != null) {
        return int.parse(numberMatch.group(1)!);
      }
    }
    
    return 60; // Default fallback
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _currentLocation,
          initialAddress: _addressController.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentLocation = result;
        _addressController.text = result['address'] ?? '';
      });
      AppLogger.info('Location selected: ${result['lat']}, ${result['lng']}');
    }
  }

  void _showContactInfoDialog(app_provider.Service service) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
          ),
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
                    Icon(Icons.contact_phone, color: AppTheme.primaryPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Provider',
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            service.title,
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
              // Contact Info
              Flexible(
                child: SingleChildScrollView(
                  child: ContactInfoSection(service: service),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.cardDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
        _selectedTimeSlot = null;
        _availableTimeSlots.clear();
      });
      
      // Check availability for the selected date
      if (_selectedService != null) {
        _checkAvailability();
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.cardDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service and date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If time slots are available, require selection
    if (_availableTimeSlots.isNotEmpty && _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available time slot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<shared.AuthService>();
      final user = authService.currentUser;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Determine scheduled time
      DateTime scheduledAt;
      if (_selectedTimeSlot != null) {
        // Use selected time slot
        final timeParts = _selectedTimeSlot!.split(' - ')[0].split(':');
        scheduledAt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      } else if (_selectedTime != null) {
        // Use manually selected time
        scheduledAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      } else {
        throw Exception('Please select a time');
      }

      // Prepare address
      Map<String, dynamic> address;
      if (_currentLocation != null) {
        address = _currentLocation!;
        AppLogger.debug('Using location data: ${address['lat']}, ${address['lng']}');
      } else {
        // Fallback to text address with default coordinates
        address = {
          'address': _addressController.text.trim(),
          'lat': -15.3875, // Default to Lusaka
          'lng': 28.3228,
        };
        AppLogger.warning('No location data available, using text address with default coordinates');
      }

      // Create booking using enhanced service
      final bookingId = await EnhancedBookingService.createBooking(
        customerId: user.uid,
        providerId: widget.provider.providerId,
        serviceId: _selectedService!.serviceId,
        serviceTitle: _selectedService!.title,
        serviceCategory: _selectedService!.category,
        estimatedPrice: _selectedService!.priceFrom ?? 0.0,
        durationMinutes: _getDurationInMinutes(_selectedService!.duration),
        scheduledAt: scheduledAt,
        address: address,
        customerNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        timeSlot: _selectedTimeSlot,
        customerFullName: _fullNameController.text.trim(),
        customerPhoneNumber: _phoneController.text.trim(),
        customerEmailAddress: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        additionalNotes: _additionalNotesController.text.trim().isNotEmpty ? _additionalNotesController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking submitted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );

        // Navigate to booking status screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingStatusScreen(bookingId: bookingId!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e'),
            backgroundColor: AppTheme.error,
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Book Service'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Info Card
              Card(
                color: AppTheme.cardDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: (widget.provider.logoUrl != null && widget.provider.logoUrl!.isNotEmpty)
                            ? NetworkImage(widget.provider.logoUrl!)
                            : null,
                        child: (widget.provider.logoUrl == null || widget.provider.logoUrl!.isEmpty)
                            ? Icon(
                                Icons.business,
                                size: 25,
                                color: AppTheme.primaryPurple,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.provider.businessName,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.provider.description,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Service Selection
              Text(
                'Select Service',
                style: AppTheme.heading3.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedService != null
                        ? AppTheme.primaryPurple
                        : AppTheme.textTertiary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedService != null) ...[
                      Text(
                        _selectedService!.title,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${_selectedService!.duration ?? 'Not specified'}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedService!.type == 'priced' && _selectedService!.priceFrom != null && _selectedService!.priceTo != null)
                        Text(
                          'Price: K${_selectedService!.priceFrom!.toStringAsFixed(0)} - K${_selectedService!.priceTo!.toStringAsFixed(0)}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (_selectedService!.type == 'negotiable')
                        Text(
                          'Price: Negotiable',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (_selectedService!.type == 'free')
                        Text(
                          'Price: Free',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ] else ...[
                      Text(
                        'No service selected',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _selectService,
                      style: AppTheme.outlineButtonStyle,
                      child: Text(
                        _selectedService != null ? 'Change Service' : 'Select Service',
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Conditional rendering based on service type
              if (_selectedService?.serviceType == 'bookable') ...[
                // Date and Time Selection
                Text(
                  'Schedule',
                  style: AppTheme.heading3.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              const SizedBox(height: 16),
              
              // Date Selection
              InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedDate != null
                                ? AppTheme.primaryPurple
                                : AppTheme.textTertiary,
                          ),
                        ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _selectedDate != null
                            ? AppTheme.primaryPurple
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Select Date',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _selectedDate != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedDate != null)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),

              // Time Slot Selection (if available)
              if (_selectedDate != null && _selectedService != null) ...[
                const SizedBox(height: 16),
                
                if (_isCheckingAvailability)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Checking availability...',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_availableTimeSlots.isNotEmpty) ...[
                  Text(
                    'Available Time Slots',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTimeSlots.map((slot) {
                      final isSelected = _selectedTimeSlot == slot;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTimeSlot = slot;
                            _selectedTime = null; // Clear manual time selection
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppTheme.primaryPurple 
                                : AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected 
                                  ? AppTheme.primaryPurple 
                                  : AppTheme.textTertiary,
                            ),
                          ),
                          child: Text(
                            slot,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isSelected 
                                  ? Colors.white 
                                  : AppTheme.textPrimary,
                              fontWeight: isSelected 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                      ),
                    ),
                  ),
                      );
                    }).toList(),
                  ),
                ] else if (_availableTimeSlots.isEmpty && !_isCheckingAvailability) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warning.withValues(alpha:0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: AppTheme.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                  Expanded(
                          child: Text(
                            'No available time slots for this date. Please select another date.',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // Manual Time Selection (fallback)
              if (_selectedDate != null && _availableTimeSlots.isEmpty && !_isCheckingAvailability) ...[
                const SizedBox(height: 16),
                InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedTime != null
                                ? AppTheme.primaryPurple
                                : AppTheme.textTertiary,
                          ),
                        ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: _selectedTime != null
                              ? AppTheme.primaryPurple
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Select Time',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _selectedTime != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        ),
                        if (_selectedTime != null)
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryPurple,
                            size: 20,
                          ),
                      ],
                      ),
                    ),
                  ),
                ],
              
              const SizedBox(height: 24),
              
              // Address
              Text(
                'Service Address',
                style: AppTheme.heading3.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Location picker button
              InkWell(
                onTap: _selectLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppTheme.primaryPurple,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service Location',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _addressController.text.isEmpty 
                                  ? 'Tap to select location on map'
                                  : _addressController.text,
                              style: AppTheme.bodyMedium.copyWith(
                                color: _addressController.text.isEmpty 
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Customer Contact Information Section
              Text(
                'Contact Information',
                style: AppTheme.heading3.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Full Name (Required)
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter your full name',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  prefixIcon: Icon(Icons.person, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  if (RegExp(r'\d').hasMatch(value.trim())) {
                    return 'Name cannot contain numbers';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: 16),
              
              // Phone Number (Required)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+260 97 123 4567',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  prefixIcon: Icon(Icons.phone, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  // Zambian phone number validation
                  final phoneRegex = RegExp(r'^(\+260|0)?[0-9]{9}$');
                  final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                  if (!phoneRegex.hasMatch(cleanPhone)) {
                    return 'Please enter a valid Zambian phone number';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: 16),
              
              // Email Address (Optional)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'your.email@example.com',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  prefixIcon: Icon(Icons.email, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: 24),
              
              // Notes
              Text(
                'Additional Notes (Optional)',
                style: AppTheme.heading3.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any special requirements or notes...',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  prefixIcon: Icon(Icons.note, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: AppTheme.primaryButtonStyle,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(_selectedService?.serviceType == 'contact' ? 'Contact Provider' : 'Submit Booking'),
                ),
              ),
              ] else if (_selectedService?.serviceType == 'contact') ...[
                // Contact service info
                ContactInfoSection(service: _selectedService!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

