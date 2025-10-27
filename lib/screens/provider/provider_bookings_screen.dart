import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/booking.dart';
import '../../services/enhanced_booking_service.dart';
import '../../services/atomic_booking_service.dart';
import '../../services/notification_service.dart';
import '../../utils/responsive_utils.dart';

class ProviderBookingsScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderBookingsScreen({
    super.key,
    this.provider,
  });

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('Bookings'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: const Center(
          child: Text(
            'No provider data available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Manage Bookings',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              mobile: 12,
              tablet: 14,
              desktop: 16,
            ),
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              mobile: 12,
              tablet: 14,
              desktop: 16,
            ),
          ),
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Accepted'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(['pending']),
          _buildBookingsList(['accepted']),
          _buildBookingsList(['completed']),
          _buildBookingsList(['pending', 'accepted', 'rejected', 'completed', 'cancelled']),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<String> statuses) {
    if (widget.provider == null) {
      return const Center(
        child: Text(
          'No provider data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Convert string statuses to BookingStatus enum
    final bookingStatuses = statuses.map((status) {
      return BookingStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => BookingStatus.pending,
      );
    }).toList();

    return StreamBuilder<List<Booking>>(
      stream: EnhancedBookingService.getBookingsStream(
        userId: widget.provider!.providerId,
        userType: UserType.provider,
        status: bookingStatuses.length == 1 ? bookingStatuses.first : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bookings: ${snapshot.error}',
              style: const TextStyle(color: AppTheme.error),
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookings found',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  'Your bookings will appear here',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: ResponsiveUtils.getResponsivePadding(context),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _buildBookingCard(booking);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      color: AppTheme.cardDark,
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                        booking.serviceTitle,
                        style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 16,
                                  tablet: 18,
                                  desktop: 20,
                                ),
                              ),
                            ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 4,
                        tablet: 6,
                        desktop: 8,
                      )),
                            Text(
                        booking.serviceCategory,
                        style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 15,
                                  desktop: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    ),
                    vertical: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 4,
                      tablet: 5,
                      desktop: 6,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.statusDisplayName,
                    style: AppTheme.caption.copyWith(
                      color: _getStatusColor(booking.status),
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 11,
                        tablet: 12,
                        desktop: 13,
                      ),
                    ),
                      ),
                    ),
                  ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 12,
              tablet: 14,
              desktop: 16,
            )),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                Text(
                  booking.formattedScheduledDate,
                  style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 13,
                        tablet: 14,
                        desktop: 15,
                      ),
                    ),
                  ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                )),
                Icon(
                  Icons.access_time,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                Text(
                  booking.formattedScheduledTime,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 13,
                      tablet: 14,
                      desktop: 15,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            )),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  color: AppTheme.success,
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                )),
                Text(
                  'K${booking.totalPrice.toStringAsFixed(0)}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 12,
              tablet: 14,
              desktop: 16,
            )),
            // Customer Notes Section (Issue 3: Show customer notes)
            if (booking.customerNotes != null && booking.customerNotes!.isNotEmpty ||
                booking.additionalNotes != null && booking.additionalNotes!.isNotEmpty) ...[
              Container(
                padding: ResponsiveUtils.getResponsivePadding(context).copyWith(
                  top: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                  bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                          color: AppTheme.info,
                        ),
                        SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        )),
                        Text(
                          'Customer Notes',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.info,
                            fontWeight: FontWeight.w600,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 14,
                              tablet: 15,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    )),
                    if (booking.customerNotes != null && booking.customerNotes!.isNotEmpty)
                      Text(
                        booking.customerNotes!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 13,
                            tablet: 14,
                            desktop: 15,
                          ),
                        ),
                      ),
                    if (booking.additionalNotes != null && booking.additionalNotes!.isNotEmpty) ...[
                      if (booking.customerNotes != null && booking.customerNotes!.isNotEmpty)
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        )),
                      Text(
                        booking.additionalNotes!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 13,
                            tablet: 14,
                            desktop: 15,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 12,
                tablet: 14,
                desktop: 16,
              )),
            ],
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Accept/Reject for pending bookings
                if (booking.canBeAccepted) ...[
                  OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: AppTheme.outlineButtonStyle.copyWith(
                      minimumSize: MaterialStateProperty.all(
                        Size(
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 80,
                            tablet: 90,
                            desktop: 100,
                          ),
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 32,
                            tablet: 36,
                            desktop: 40,
                          ),
                        ),
                      ),
                      side: MaterialStateProperty.all(BorderSide(color: AppTheme.error)),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  )),
                  ElevatedButton(
                    onPressed: () => _acceptBooking(booking),
                    style: AppTheme.primaryButtonStyle.copyWith(
                      minimumSize: MaterialStateProperty.all(
                        Size(
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 80,
                            tablet: 90,
                            desktop: 100,
                          ),
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 32,
                            tablet: 36,
                            desktop: 40,
                          ),
                        ),
                      ),
                    ),
                    child: Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Start Service for accepted bookings
                if (booking.canBeStarted)
                  ElevatedButton.icon(
                    onPressed: () => _startBooking(booking),
                    style: AppTheme.primaryButtonStyle.copyWith(
                      minimumSize: MaterialStateProperty.all(
                        Size(
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 120,
                            tablet: 135,
                            desktop: 150,
                          ),
                          ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.play_arrow,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                    ),
                    label: Text(
                      'Start Service',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                      ),
                    ),
                  ),
                
                // Mark Complete for in-progress bookings
                if (booking.canBeCompleted)
                  ElevatedButton.icon(
                    onPressed: () => _completeBooking(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 120,
                          tablet: 135,
                          desktop: 150,
                        ),
                        ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 36,
                          tablet: 40,
                          desktop: 44,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.check_circle,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                    ),
                    label: Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptBooking(Booking booking) async {
    try {
      await AtomicBookingService.updateBookingStatusAtomic(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.accepted,
        userId: widget.provider!.providerId,
        providerNotes: 'Booking accepted',
      );

      // Send notification to customer
      await NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: 'Booking Accepted',
        body: 'Your booking with ${widget.provider!.businessName} has been accepted! Scheduled for ${booking.formattedScheduledDate} at ${booking.formattedScheduledTime}',
        data: {
          'type': NotificationType.bookingAccepted,
          'bookingId': booking.bookingId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking accepted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting booking: $e'),
            backgroundColor: AppTheme.error,
        ),
      );
    }
    }
  }

  Future<void> _rejectBooking(Booking booking) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      await AtomicBookingService.updateBookingStatusAtomic(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.rejected,
        userId: widget.provider!.providerId,
        providerNotes: reason,
      );

      // Send notification to customer
      await NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: 'Booking Declined',
        body: 'Your booking with ${widget.provider!.businessName} was declined. Reason: $reason',
        data: {
          'type': NotificationType.bookingRejected,
          'bookingId': booking.bookingId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking rejected successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting booking: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _startBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Start Service'),
        content: const Text('Mark this booking as in progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle,
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AtomicBookingService.updateBookingStatusAtomic(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.inProgress,
        userId: widget.provider!.providerId,
        providerNotes: 'Service started',
      );

      // Send notification to customer
      await NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: 'Service Started',
        body: '${widget.provider!.businessName} has started working on your booking',
        data: {
          'type': 'booking_in_progress',
          'bookingId': booking.bookingId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking marked as in progress'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting booking: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _completeBooking(Booking booking) async {
    final finalPriceController = TextEditingController(
      text: booking.estimatedPrice.toStringAsFixed(0),
    );
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Complete Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: finalPriceController,
              decoration: InputDecoration(
                labelText: 'Final Price (K)',
                hintText: 'Enter final amount',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Completion Notes (Optional)',
                hintText: 'Any notes about the completed service...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final finalPrice = double.tryParse(finalPriceController.text) ?? booking.estimatedPrice;

      // Provider marks as complete, but requires customer confirmation
      await AtomicBookingService.updateBookingStatusAtomic(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.pendingCustomerConfirmation,  // Changed from completed
        userId: widget.provider!.providerId,
        providerNotes: notesController.text.trim().isEmpty 
            ? 'Service completed, awaiting customer confirmation' 
            : notesController.text.trim(),
        finalPrice: finalPrice,
      );

      // Send notification to customer for confirmation
      await NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: 'Service Completed - Confirmation Required',
        body: '${widget.provider!.businessName} has marked your service as completed (K${finalPrice.toStringAsFixed(0)}). Please confirm completion.',
        data: {
          'type': 'booking_pending_confirmation',
          'bookingId': booking.bookingId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service marked as complete. Awaiting customer confirmation.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing booking: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this booking:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(reasonController.text.trim());
              }
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.accepted:
        return AppTheme.success;
      case BookingStatus.inProgress:
        return AppTheme.primaryPurple;
      case BookingStatus.pendingCustomerConfirmation:
        return AppTheme.info;  // NEW: Blue color for pending confirmation
      case BookingStatus.completed:
        return AppTheme.success;
      case BookingStatus.cancelled:
        return AppTheme.error;
      case BookingStatus.rejected:
        return AppTheme.error;
      case BookingStatus.rescheduled:
        return AppTheme.warning;
    }
  }
}