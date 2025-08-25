import 'package:flutter/material.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/models/booking.dart';
import 'package:all_server/services/booking_service.dart';
import 'package:all_server/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class BookingPage extends StatefulWidget {
  final Provider provider;
  final ServiceOffering? selectedService;

  const BookingPage({
    super.key,
    required this.provider,
    this.selectedService,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final BookingService _bookingService = BookingService();
  final NotificationService _notificationService = NotificationService();
  
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  ServiceOffering? selectedService;
  String? specialInstructions;
  String? customerAddress;
  double? estimatedCost;
  
  bool isLoading = false;
  bool isSubmitting = false;
  List<TimeSlot> availableTimeSlots = [];
  
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedService = widget.selectedService ?? 
        (widget.provider.services.isNotEmpty ? widget.provider.services.first : null);
    _loadAvailableTimeSlots();
    _calculateEstimatedCost();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (selectedService == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      // Get available time slots for the selected date and service
      if (selectedDate != null) {
        availableTimeSlots = await _getAvailableTimeSlots(selectedDate!);
      }
    } catch (e) {
      debugPrint('Error loading time slots: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<TimeSlot>> _getAvailableTimeSlots(DateTime date) async {
    // This would typically come from the provider's availability
    // For now, we'll generate some sample time slots
    List<TimeSlot> slots = [];
    
    // Business hours: 8 AM to 6 PM
    for (int hour = 8; hour < 18; hour++) {
      slots.add(TimeSlot(
        time: TimeOfDay(hour: hour, minute: 0),
        isAvailable: true,
      ));
      slots.add(TimeSlot(
        time: TimeOfDay(hour: hour, minute: 30),
        isAvailable: true,
      ));
    }
    
    return slots;
  }

  void _calculateEstimatedCost() {
    if (selectedService != null) {
      estimatedCost = selectedService!.price;
      // Add any additional costs based on date/time, location, etc.
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      selectableDayPredicate: (DateTime date) {
        // Exclude weekends if provider doesn't work on weekends
        return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
      });
      await _loadAvailableTimeSlots();
    }
  }

  Future<void> _selectTime() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_validateBooking()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // Create the booking
      final booking = await _bookingService.createBooking(
        providerId: widget.provider.id,
        serviceId: selectedService!.id,
        scheduledDate: selectedDate!,
        scheduledTime: selectedTime!,
        customerAddress: customerAddress ?? _addressController.text,
        specialInstructions: specialInstructions ?? _instructionsController.text,
        estimatedCost: estimatedCost ?? 0.0,
      );

      // Send notification to provider
      await _notificationService.sendNotification(
        userId: widget.provider.id,
        title: 'New Booking Request',
        body: 'You have a new booking request from ${booking.customerName}',
        data: {
          'type': 'new_booking',
          'bookingId': booking.id,
        },
      );

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, booking);
      }
    } catch (e) {
      debugPrint('Error submitting booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  bool _validateBooking() {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return false;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return false;
    }

    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service')),
      );
      return false;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your address')),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                                         CircleAvatar(
                       backgroundImage: widget.provider.profileImageUrl != null
                           ? NetworkImage(widget.provider.profileImageUrl!)
                           : null,
                       radius: 30,
                       child: widget.provider.profileImageUrl == null
                           ? Text(
                               widget.provider.businessName.isNotEmpty
                                   ? widget.provider.businessName[0].toUpperCase()
                                   : 'P',
                               style: const TextStyle(
                                 fontSize: 20,
                                 fontWeight: FontWeight.bold,
                               ),
                             )
                           : null,
                     ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                                     Text(
                             widget.provider.businessName.isNotEmpty
                                 ? widget.provider.businessName
                                 : widget.provider.ownerName ?? 'Provider',
                             style: const TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              RatingBarIndicator(
                                rating: widget.provider.rating,
                                itemBuilder: (context, index) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                itemCount: 5,
                                itemSize: 16.0,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.provider.rating.toStringAsFixed(1)} (${widget.provider.reviewCount})',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
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
            ),
            
            const SizedBox(height: 24),
            
            // Service Selection
            const Text(
              'Select Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (widget.provider.services.isNotEmpty)
              DropdownButtonFormField<ServiceOffering>(
                value: selectedService,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Service',
                ),
                items: widget.provider.services.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Text('${service.name} - \$${service.price.toStringAsFixed(2)}'),
                  );
                }).toList(),
                onChanged: (ServiceOffering? value) {
                  setState(() {
                    selectedService = value;
                  });
                  _calculateEstimatedCost();
                },
              )
            else
              const Text('No services available'),
            
            const SizedBox(height: 24),
            
            // Date Selection
            const Text(
              'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      selectedDate != null
                          ? DateFormat('EEEE, MMMM d, y').format(selectedDate!)
                          : 'Select a date',
                      style: TextStyle(
                        color: selectedDate != null ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Time Selection
            const Text(
              'Select Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 12),
                    Text(
                      selectedTime != null
                          ? selectedTime!.format(context)
                          : 'Select a time',
                      style: TextStyle(
                        color: selectedTime != null ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Address Input
            const Text(
              'Service Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter your address',
                hintText: 'Street address, city, state',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 24),
            
            // Special Instructions
            const Text(
              'Special Instructions (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Any special requirements or notes',
                hintText: 'e.g., Gate code, parking instructions, etc.',
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            
            // Estimated Cost
            if (estimatedCost != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Cost:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${estimatedCost!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Book Service',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Terms and Conditions
            Text(
              'By booking this service, you agree to our terms and conditions.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class TimeSlot {
  final TimeOfDay time;
  final bool isAvailable;

  TimeSlot({
    required this.time,
    required this.isAvailable,
  });
}
