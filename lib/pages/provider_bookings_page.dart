import 'package:flutter/material.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/models/booking.dart';
import 'package:all_server/services/provider_service.dart';

class ProviderBookingsPage extends StatefulWidget {
  final Provider provider;

  const ProviderBookingsPage({super.key, required this.provider});

  @override
  State<ProviderBookingsPage> createState() => _ProviderBookingsPageState();
}

class _ProviderBookingsPageState extends State<ProviderBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProviderService _providerService = ProviderService();
  final BookingService _bookingService = BookingService();

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

  Future<void> _updateBookingStatus(
    String bookingId,
    BookingStatus status,
    String? notes,
    double? finalPrice,
  ) async {
    final success = await _bookingService.updateBookingStatus(
      bookingId: bookingId,
      status: status,
      providerNotes: notes,
      finalPrice: finalPrice,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking ${status.name} successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update booking status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBookingDetails(Booking booking) {
    showDialog(
      context: context,
      builder: (context) => _BookingDetailsDialog(
        booking: booking,
        onUpdateStatus: _updateBookingStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade600,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade600,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(BookingStatus.pending),
          _buildBookingsList(BookingStatus.accepted),
          _buildBookingsList(BookingStatus.inProgress),
          _buildBookingsList(BookingStatus.completed),
        ],
      ),
    );
  }

  Widget _buildBookingsList(BookingStatus status) {
    return StreamBuilder<List<Booking>>(
      stream: _providerService.getProviderBookings(widget.provider.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allBookings = snapshot.data ?? [];
        final filteredBookings = allBookings
            .where((booking) => booking.status == status)
            .toList();

        if (filteredBookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${status.name} bookings',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            final booking = filteredBookings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(status),
                  child: Icon(
                    _getStatusIcon(status),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  booking.serviceType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Requested: ${_formatDate(booking.requestedDate)}'),
                    if (booking.timeSlot != null)
                      Text('Time: ${booking.timeSlot}'),
                    if (booking.estimatedPrice != null)
                      Text(
                        'Price: K${booking.estimatedPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == BookingStatus.pending) ...[
                      IconButton(
                        onPressed: () => _updateBookingStatus(
                          booking.id,
                          BookingStatus.rejected,
                          null,
                          null,
                        ),
                        icon: const Icon(Icons.close),
                        color: Colors.red,
                        tooltip: 'Reject',
                      ),
                      IconButton(
                        onPressed: () => _updateBookingStatus(
                          booking.id,
                          BookingStatus.accepted,
                          null,
                          null,
                        ),
                        icon: const Icon(Icons.check),
                        color: Colors.green,
                        tooltip: 'Accept',
                      ),
                    ],
                    IconButton(
                      onPressed: () => _showBookingDetails(booking),
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'View Details',
                    ),
                  ],
                ),
                onTap: () => _showBookingDetails(booking),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.accepted:
        return Icons.check_circle;
      case BookingStatus.inProgress:
        return Icons.work;
      case BookingStatus.completed:
        return Icons.task_alt;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.blue;
      case BookingStatus.inProgress:
        return Colors.purple;
      case BookingStatus.completed:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _BookingDetailsDialog extends StatefulWidget {
  final Booking booking;
  final Function(String, BookingStatus, String?, double?) onUpdateStatus;

  const _BookingDetailsDialog({
    required this.booking,
    required this.onUpdateStatus,
  });

  @override
  State<_BookingDetailsDialog> createState() => _BookingDetailsDialogState();
}

class _BookingDetailsDialogState extends State<_BookingDetailsDialog> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.booking.providerNotes ?? '';
    _priceController.text = widget.booking.finalPrice?.toString() ?? 
                           widget.booking.estimatedPrice?.toString() ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Booking Details - ${widget.booking.serviceType}'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Service', widget.booking.serviceType),
              if (widget.booking.serviceDescription != null)
                _buildDetailRow('Description', widget.booking.serviceDescription!),
              _buildDetailRow('Requested Date', 
                  '${widget.booking.requestedDate.day}/${widget.booking.requestedDate.month}/${widget.booking.requestedDate.year}'),
              if (widget.booking.timeSlot != null)
                _buildDetailRow('Time Slot', widget.booking.timeSlot!),
              if (widget.booking.userAddress != null)
                _buildDetailRow('Address', widget.booking.userAddress!),
              if (widget.booking.userNotes != null)
                _buildDetailRow('Customer Notes', widget.booking.userNotes!),
              _buildDetailRow('Status', widget.booking.status.name.toUpperCase()),
              _buildDetailRow('Created', 
                  '${widget.booking.createdAt.day}/${widget.booking.createdAt.month}/${widget.booking.createdAt.year}'),
              
              const SizedBox(height: 20),
              const Text(
                'Provider Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add notes for the customer...',
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Final Price (K):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: 'K ',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.booking.status == BookingStatus.pending) ...[
          ElevatedButton(
            onPressed: () {
              widget.onUpdateStatus(
                widget.booking.id,
                BookingStatus.rejected,
                _notesController.text.trim().isNotEmpty 
                    ? _notesController.text.trim() 
                    : null,
                null,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onUpdateStatus(
                widget.booking.id,
                BookingStatus.accepted,
                _notesController.text.trim().isNotEmpty 
                    ? _notesController.text.trim() 
                    : null,
                double.tryParse(_priceController.text),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
        if (widget.booking.status == BookingStatus.accepted)
          ElevatedButton(
            onPressed: () {
              widget.onUpdateStatus(
                widget.booking.id,
                BookingStatus.inProgress,
                _notesController.text.trim().isNotEmpty 
                    ? _notesController.text.trim() 
                    : null,
                double.tryParse(_priceController.text),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Start Job'),
          ),
        if (widget.booking.status == BookingStatus.inProgress)
          ElevatedButton(
            onPressed: () {
              widget.onUpdateStatus(
                widget.booking.id,
                BookingStatus.completed,
                _notesController.text.trim().isNotEmpty 
                    ? _notesController.text.trim() 
                    : null,
                double.tryParse(_priceController.text),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Mark Complete'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}



