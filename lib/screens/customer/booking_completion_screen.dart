import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import 'payment_simulation_screen.dart';

class BookingCompletionScreen extends StatefulWidget {
  final Booking booking;

  const BookingCompletionScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingCompletionScreen> createState() =>
      _BookingCompletionScreenState();
}

class _BookingCompletionScreenState extends State<BookingCompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _proceedToPayment() {
    if (_hasNavigated) return;
    setState(() => _hasNavigated = true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSimulationScreen(booking: widget.booking),
      ),
    );
  }

  void _reportIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Report an Issue',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This feature will allow you to report problems with the completed service. Would you like to proceed?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue reporting feature coming soon'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.white),
            ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppTheme.textPrimary,
        ),
        title: const Text('Service Completed'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCompletionBanner(),
                  const SizedBox(height: 24),
                  _buildServiceSummaryCard(),
                  const SizedBox(height: 24),
                  _buildAmountDueCard(),
                  const SizedBox(height: 24),
                  _buildNextStepsCard(),
                  const SizedBox(height: 32),
                  _buildProceedButton(),
                  const SizedBox(height: 12),
                  _buildReportIssueButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.2),
            Colors.green.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Service Completed!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The provider has marked your booking as completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cleaning_services,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Service Details',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppTheme.cardLight),
          const SizedBox(height: 16),
          _buildDetailRow('Service', widget.booking.serviceTitle),
          const SizedBox(height: 12),
          _buildDetailRow('Provider', widget.booking.providerData?['name'] ?? 'Provider'),
          const SizedBox(height: 12),
          _buildDetailRow('Date', _formatDate(widget.booking.scheduledAt.toIso8601String())),
          const SizedBox(height: 12),
          _buildDetailRow('Time', widget.booking.timeSlot ?? widget.booking.formattedScheduledTime),
          const SizedBox(height: 12),
          _buildDetailRow('Location', widget.booking.address['address']?.toString() ?? 'Not specified'),
          if (widget.booking.additionalNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Notes', widget.booking.additionalNotes!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountDueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.15),
            AppTheme.accent.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount Due',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'K ${widget.booking.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payments,
              color: AppTheme.primaryPurple,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Next Steps',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepItem(
            1,
            'Complete Payment',
            'Choose your preferred payment method and complete the transaction',
          ),
          const SizedBox(height: 12),
          _buildStepItem(
            2,
            'Rate the Service',
            'Share your experience and help others make informed decisions',
          ),
          const SizedBox(height: 12),
          _buildStepItem(
            3,
            'Done!',
            'Your booking will be complete and the review will be published',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNumber, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryPurple,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: AppTheme.primaryPurple,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProceedButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _hasNavigated ? null : _proceedToPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          disabledBackgroundColor: AppTheme.primaryPurple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Proceed to Payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportIssueButton() {
    return OutlinedButton(
      onPressed: _reportIssue,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.orange.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem_outlined,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Report an Issue',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
