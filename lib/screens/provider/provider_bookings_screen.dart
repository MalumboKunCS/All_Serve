import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/booking.dart';
import '../../services/enhanced_booking_service.dart';

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
        title: const Text('Manage Bookings'),
        backgroundColor: AppTheme.surfaceDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
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
          padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.serviceCategory,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.statusDisplayName,
                    style: AppTheme.caption.copyWith(
                      color: _getStatusColor(booking.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  booking.formattedScheduledDate,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  booking.formattedScheduledTime,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'K${booking.totalPrice.toStringAsFixed(0)}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (booking.canBeAccepted)
                  ElevatedButton(
                    onPressed: () => _acceptBooking(booking),
                    style: AppTheme.primaryButtonStyle.copyWith(
                      minimumSize: MaterialStateProperty.all(const Size(80, 32)),
                    ),
                    child: const Text('Accept'),
                  ),
                if (booking.canBeRejected)
                  OutlinedButton(
                    onPressed: () => _rejectBooking(booking),
                    style: AppTheme.outlineButtonStyle.copyWith(
                      minimumSize: MaterialStateProperty.all(const Size(80, 32)),
                    ),
                    child: const Text('Reject'),
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
      final success = await EnhancedBookingService.updateBookingStatus(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.accepted,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking accepted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept booking'),
            backgroundColor: AppTheme.error,
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
      final success = await EnhancedBookingService.updateBookingStatus(
        bookingId: booking.bookingId,
        newStatus: BookingStatus.rejected,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking rejected successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject booking'),
            backgroundColor: AppTheme.error,
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