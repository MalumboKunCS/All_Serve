import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/provider.dart' as app_provider;
import 'my_bookings_screen.dart';
import 'review_screen.dart';

class BookingStatusScreen extends StatefulWidget {
  final String bookingId;

  const BookingStatusScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  late Stream<DocumentSnapshot> _bookingStream;
  app_provider.Provider? _provider;

  @override
  void initState() {
    super.initState();
    _bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      // Get booking to find provider
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();
      
      if (bookingDoc.exists) {
        final booking = Booking.fromFirestore(bookingDoc);
        
        // Get provider data
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(booking.providerId)
            .get();
        
        if (providerDoc.exists && mounted) {
          setState(() {
            _provider = app_provider.Provider.fromFirestore(providerDoc);
          });
        }
      }
    } catch (e) {
      print('Error loading provider data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Booking Status'),
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            (route) => route.settings.name == '/',
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _bookingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading booking status',
                    style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Booking not found',
                    style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            );
          }

          final booking = Booking.fromFirestore(snapshot.data!);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Success/Status Card
                _buildStatusCard(booking),
                
                const SizedBox(height: 24),
                
                // Booking Details Card
                _buildBookingDetailsCard(booking),
                
                const SizedBox(height: 24),
                
                // Provider Details Card
                if (_provider != null) _buildProviderCard(_provider!),
                
                const SizedBox(height: 24),
                
                // Status Timeline
                _buildStatusTimeline(booking),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                _buildActionButtons(booking),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(Booking booking) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;
    String statusSubtitle;

    switch (booking.status.toLowerCase()) {
      case 'requested':
        statusColor = AppTheme.warning;
        statusIcon = Icons.schedule;
        statusMessage = 'Booking Requested';
        statusSubtitle = 'Waiting for provider confirmation';
        break;
      case 'accepted':
        statusColor = AppTheme.info;
        statusIcon = Icons.check_circle;
        statusMessage = 'Booking Confirmed';
        statusSubtitle = 'Provider has accepted your booking';
        break;
      case 'completed':
        statusColor = AppTheme.success;
        statusIcon = Icons.task_alt;
        statusMessage = 'Service Completed';
        statusSubtitle = 'How was your experience?';
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        statusMessage = 'Booking Rejected';
        statusSubtitle = 'Provider is not available';
        break;
      case 'cancelled':
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.block;
        statusMessage = 'Booking Cancelled';
        statusSubtitle = 'This booking was cancelled';
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help;
        statusMessage = 'Unknown Status';
        statusSubtitle = '';
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                statusIcon,
                size: 40,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusMessage,
              style: AppTheme.heading2.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusSubtitle,
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetailsCard(Booking booking) {
    return Card(
      color: AppTheme.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Details',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Booking ID', '#${booking.bookingId.substring(0, 8)}'),
            _buildDetailRow('Scheduled Date', _formatDateTime(booking.scheduledAt)),
            _buildDetailRow('Requested On', _formatDateTime(booking.requestedAt)),
            _buildDetailRow('Service Location', booking.address['address'] ?? 'Not specified'),
            if (booking.notes?.isNotEmpty ?? false)
              _buildDetailRow('Notes', booking.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(app_provider.Provider provider) {
    return Card(
      color: AppTheme.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider Information',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primary,
                  backgroundImage: (provider.logoUrl?.isNotEmpty ?? false)
                      ? NetworkImage(provider.logoUrl!)
                      : null,
                  child: (provider.logoUrl?.isEmpty ?? true)
                      ? const Icon(Icons.business, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.businessName,
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (provider.verified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.success),
                              ),
                              child: Text(
                                'VERIFIED',
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.ratingAvg.toStringAsFixed(1)} (${provider.ratingCount} reviews)',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(Booking booking) {
    final statuses = [
      {'status': 'requested', 'title': 'Booking Requested', 'time': booking.requestedAt},
      if (booking.isAccepted || booking.isCompleted) 
        {'status': 'accepted', 'title': 'Booking Accepted', 'time': booking.requestedAt}, // TODO: Add acceptedAt field
      if (booking.isCompleted) 
        {'status': 'completed', 'title': 'Service Completed', 'time': booking.requestedAt}, // TODO: Add completedAt field
      if (booking.isRejected) 
        {'status': 'rejected', 'title': 'Booking Rejected', 'time': booking.requestedAt},
      if (booking.isCancelled) 
        {'status': 'cancelled', 'title': 'Booking Cancelled', 'time': booking.requestedAt},
    ];

    return Card(
      color: AppTheme.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            ...statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isLast = index == statuses.length - 1;
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status['title'] as String,
                          style: AppTheme.bodyText.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDateTime(status['time'] as DateTime),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Booking booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booking.isRequested)
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement cancel booking
            },
            style: AppTheme.outlineButtonStyle.copyWith(
              foregroundColor: MaterialStateProperty.all(AppTheme.error),
              side: MaterialStateProperty.all(BorderSide(color: AppTheme.error)),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Booking'),
          ),
        
        if (booking.isCompleted)
          ElevatedButton.icon(
            onPressed: () {
              if (_provider != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      booking: booking,
                      provider: _provider!,
                    ),
                  ),
                );
              }
            },
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.rate_review),
            label: const Text('Leave Review'),
          ),
        
        const SizedBox(height: 12),
        
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
              (route) => route.settings.name == '/',
            );
          },
          style: AppTheme.secondaryButtonStyle,
          icon: const Icon(Icons.list),
          label: const Text('View All Bookings'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
