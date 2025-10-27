import 'package:flutter/material.dart';
import 'package:shared/shared.dart' as shared;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  String _searchQuery = '';
  shared.BookingStatus? _selectedStatus;
  String? _selectedProviderId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'scheduledAt';
  bool _sortAscending = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Management',
                    style: shared.AppTheme.heading1.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor and manage all bookings across the platform',
                    style: shared.AppTheme.bodyLarge.copyWith(
                      color: shared.AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              _buildExportButton(),
            ],
          ),
          const SizedBox(height: 24),

          // Statistics Cards
          _buildStatisticsCards(),
          const SizedBox(height: 24),

          // Filters Section
          _buildFiltersSection(),
          const SizedBox(height: 16),

          // Bookings List
          Expanded(
            child: _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final bookings = snapshot.data!.docs;
        final totalBookings = bookings.length;
        final pendingBookings = bookings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).length;
        final completedBookings = bookings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'completed';
        }).length;
        final inProgressBookings = bookings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'inProgress';
        }).length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Bookings',
                value: totalBookings.toString(),
                icon: Icons.event_note,
                color: shared.AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Pending',
                value: pendingBookings.toString(),
                icon: Icons.pending_actions,
                color: shared.AppTheme.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'In Progress',
                value: inProgressBookings.toString(),
                icon: Icons.hourglass_top,
                color: shared.AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Completed',
                value: completedBookings.toString(),
                icon: Icons.check_circle,
                color: shared.AppTheme.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: shared.AppTheme.cardDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.trending_up, color: shared.AppTheme.success, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: shared.AppTheme.heading2.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: shared.AppTheme.caption.copyWith(
                color: shared.AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shared.AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shared.AppTheme.cardLight),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: shared.AppTheme.inputDecoration.copyWith(
              labelText: 'Search by customer name, provider, or service...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
            style: shared.AppTheme.bodyMedium.copyWith(
              color: shared.AppTheme.textPrimary,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<shared.BookingStatus?>(
                  value: _selectedStatus,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Status',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Statuses')),
                    ...shared.BookingStatus.values.map((status) => 
                      DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),
              ),
              const SizedBox(width: 16),

              // Date Range Filter
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  child: InputDecorator(
                    decoration: shared.AppTheme.inputDecoration.copyWith(
                      labelText: 'Date Range',
                      suffixIcon: _startDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _startDate = null;
                                _endDate = null;
                              }),
                            )
                          : const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _startDate != null
                          ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                          : 'All Dates',
                      style: shared.AppTheme.bodyMedium.copyWith(
                        color: shared.AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Sort By Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: shared.AppTheme.inputDecoration.copyWith(
                    labelText: 'Sort By',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'scheduledAt', child: Text('Scheduled Date')),
                    DropdownMenuItem(value: 'createdAt', child: Text('Created Date')),
                    DropdownMenuItem(value: 'status', child: Text('Status')),
                    DropdownMenuItem(value: 'estimatedPrice', child: Text('Price')),
                  ],
                  onChanged: (value) => setState(() => _sortBy = value!),
                ),
              ),
              const SizedBox(width: 16),

              // Sort Direction
              IconButton(
                onPressed: () => setState(() => _sortAscending = !_sortAscending),
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                style: IconButton.styleFrom(
                  backgroundColor: shared.AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildBookingsQuery(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bookings: ${snapshot.error}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.error,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: shared.AppTheme.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookings found',
                  style: shared.AppTheme.heading3.copyWith(
                    color: shared.AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter by search query (client-side filtering for complex fields)
        List<DocumentSnapshot> filteredDocs = docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final customerName = (data['customerData']?['name'] ?? '').toString().toLowerCase();
            final providerName = (data['providerData']?['businessName'] ?? '').toString().toLowerCase();
            final serviceTitle = (data['serviceTitle'] ?? '').toString().toLowerCase();
            final searchLower = _searchQuery.toLowerCase();
            
            return customerName.contains(searchLower) ||
                   providerName.contains(searchLower) ||
                   serviceTitle.contains(searchLower);
          }).toList();
        }

        return Card(
          color: shared.AppTheme.cardDark,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: shared.AppTheme.cardLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    _buildHeaderCell('Booking ID', flex: 2),
                    _buildHeaderCell('Customer', flex: 2),
                    _buildHeaderCell('Provider', flex: 2),
                    _buildHeaderCell('Service', flex: 2),
                    _buildHeaderCell('Scheduled', flex: 2),
                    _buildHeaderCell('Status', flex: 1),
                    _buildHeaderCell('Price', flex: 1),
                    _buildHeaderCell('Actions', flex: 1),
                  ],
                ),
              ),

              // Table Rows
              Expanded(
                child: ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final booking = shared.Booking.fromFirestore(filteredDocs[index]);
                    return _buildBookingRow(booking);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: shared.AppTheme.bodyMedium.copyWith(
          color: shared.AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBookingRow(shared.Booking booking) {
    return InkWell(
      onTap: () => _showBookingDetails(booking),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: shared.AppTheme.cardLight, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Booking ID
            Expanded(
              flex: 2,
              child: Text(
                booking.bookingId.substring(0, 8),
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.primaryPurple,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Customer
            Expanded(
              flex: 2,
              child: Text(
                booking.customerData?['name'] ?? 'Unknown',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textPrimary,
                ),
              ),
            ),

            // Provider
            Expanded(
              flex: 2,
              child: Text(
                booking.providerData?['businessName'] ?? 'Unknown',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textPrimary,
                ),
              ),
            ),

            // Service
            Expanded(
              flex: 2,
              child: Text(
                booking.serviceTitle,
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Scheduled Date
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(booking.scheduledAt),
                    style: shared.AppTheme.bodyMedium.copyWith(
                      color: shared.AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(booking.scheduledAt),
                    style: shared.AppTheme.caption.copyWith(
                      color: shared.AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Status
            Expanded(
              flex: 1,
              child: _buildStatusBadge(booking.status),
            ),

            // Price
            Expanded(
              flex: 1,
              child: Text(
                'K${booking.finalPrice > 0 ? booking.finalPrice.toStringAsFixed(0) : booking.estimatedPrice.toStringAsFixed(0)}',
                style: shared.AppTheme.bodyMedium.copyWith(
                  color: shared.AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Actions
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: shared.AppTheme.textSecondary),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'override', child: Text('Override Status')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel Booking')),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      _showBookingDetails(booking);
                      break;
                    case 'override':
                      _showStatusOverrideDialog(booking);
                      break;
                    case 'cancel':
                      _cancelBooking(booking);
                      break;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(shared.BookingStatus status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case shared.BookingStatus.pending:
        bgColor = shared.AppTheme.warning.withValues(alpha: 0.2);
        textColor = shared.AppTheme.warning;
        break;
      case shared.BookingStatus.accepted:
        bgColor = shared.AppTheme.primaryBlue.withValues(alpha: 0.2);
        textColor = shared.AppTheme.primaryBlue;
        break;
      case shared.BookingStatus.inProgress:
        bgColor = shared.AppTheme.primaryPurple.withValues(alpha: 0.2);
        textColor = shared.AppTheme.primaryPurple;
        break;
      case shared.BookingStatus.pendingCustomerConfirmation:
        bgColor = shared.AppTheme.info.withValues(alpha: 0.2);
        textColor = shared.AppTheme.info;
        break;
      case shared.BookingStatus.completed:
        bgColor = shared.AppTheme.success.withValues(alpha: 0.2);
        textColor = shared.AppTheme.success;
        break;
      case shared.BookingStatus.cancelled:
      case shared.BookingStatus.rejected:
        bgColor = shared.AppTheme.error.withValues(alpha: 0.2);
        textColor = shared.AppTheme.error;
        break;
      case shared.BookingStatus.rescheduled:
        bgColor = shared.AppTheme.warning.withValues(alpha: 0.2);
        textColor = shared.AppTheme.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatStatus(status),
        style: shared.AppTheme.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: _exportBookings,
      icon: const Icon(Icons.download),
      label: const Text('Export CSV'),
      style: ElevatedButton.styleFrom(
        backgroundColor: shared.AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Stream<QuerySnapshot> _buildBookingsQuery() {
    Query query = _firestore.collection('bookings');

    // Apply status filter
    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus!.name);
    }

    // Apply date range filter
    if (_startDate != null && _endDate != null) {
      query = query
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
    }

    // Apply sorting
    query = query.orderBy(_sortBy, descending: !_sortAscending);

    return query.snapshots();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showBookingDetails(shared.Booking booking) {
    showDialog(
      context: context,
      builder: (context) => BookingDetailsDialog(booking: booking),
    );
  }

  Future<void> _showStatusOverrideDialog(shared.Booking booking) async {
    shared.BookingStatus? newStatus;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(
          'Override Booking Status',
          style: shared.AppTheme.heading3.copyWith(
            color: shared.AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status: ${_formatStatus(booking.status)}',
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<shared.BookingStatus>(
              decoration: shared.AppTheme.inputDecoration.copyWith(
                labelText: 'New Status',
              ),
              items: shared.BookingStatus.values
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      ))
                  .toList(),
              onChanged: (value) => newStatus = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newStatus != null) {
                await _overrideBookingStatus(booking, newStatus!);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: shared.AppTheme.primaryPurple,
            ),
            child: const Text('Override'),
          ),
        ],
      ),
    );
  }

  Future<void> _overrideBookingStatus(
    shared.Booking booking,
    shared.BookingStatus newStatus,
  ) async {
    try {
      await _firestore.collection('bookings').doc(booking.bookingId).update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'providerNotes': 'Status overridden by admin',
      });

      // Send notification to customer and provider
      await shared.NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: 'Booking Status Updated',
        body: 'Your booking status has been updated to ${_formatStatus(newStatus)}',
        data: {'type': 'booking_status_update', 'bookingId': booking.bookingId},
      );

      await shared.NotificationService.sendNotificationToUser(
        userId: booking.providerId,
        title: 'Booking Status Updated',
        body: 'Booking status has been updated to ${_formatStatus(newStatus)} by admin',
        data: {'type': 'booking_status_update', 'bookingId': booking.bookingId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(shared.Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: shared.AppTheme.cardDark,
        title: Text(
          'Cancel Booking',
          style: shared.AppTheme.heading3.copyWith(
            color: shared.AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: shared.AppTheme.bodyMedium.copyWith(
            color: shared.AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: shared.AppTheme.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _overrideBookingStatus(booking, shared.BookingStatus.cancelled);
    }
  }

  Future<void> _exportBookings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatStatus(shared.BookingStatus status) {
    switch (status) {
      case shared.BookingStatus.inProgress:
        return 'In Progress';
      default:
        return status.name[0].toUpperCase() + status.name.substring(1);
    }
  }
}

class BookingDetailsDialog extends StatelessWidget {
  final shared.Booking booking;

  const BookingDetailsDialog({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: shared.AppTheme.cardDark,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Details',
                  style: shared.AppTheme.heading2.copyWith(
                    color: shared.AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            _buildDetailRow('Booking ID', booking.bookingId),
            _buildDetailRow('Customer', booking.customerData?['name'] ?? 'Unknown'),
            _buildDetailRow('Provider', booking.providerData?['businessName'] ?? 'Unknown'),
            _buildDetailRow('Service', booking.serviceTitle),
            _buildDetailRow('Category', booking.serviceCategory),
            _buildDetailRow(
              'Scheduled',
              DateFormat('MMM dd, yyyy hh:mm a').format(booking.scheduledAt),
            ),
            _buildDetailRow('Duration', '${booking.durationMinutes} minutes'),
            _buildDetailRow('Estimated Price', 'K${booking.estimatedPrice.toStringAsFixed(0)}'),
            if (booking.finalPrice > 0)
              _buildDetailRow('Final Price', 'K${booking.finalPrice.toStringAsFixed(0)}'),
            _buildDetailRow('Address', booking.address['address'] ?? 'N/A'),
            _buildDetailRow('Status', _formatStatus(booking.status)),
            if (booking.customerNotes != null)
              _buildDetailRow('Customer Notes', booking.customerNotes!),
            if (booking.providerNotes != null)
              _buildDetailRow('Provider Notes', booking.providerNotes!),
            if (booking.cancellationReason != null)
              _buildDetailRow('Cancellation Reason', booking.cancellationReason!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: shared.AppTheme.bodyMedium.copyWith(
                color: shared.AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(shared.BookingStatus status) {
    switch (status) {
      case shared.BookingStatus.inProgress:
        return 'In Progress';
      default:
        return status.name[0].toUpperCase() + status.name.substring(1);
    }
  }
}
