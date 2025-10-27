import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/booking.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';
import 'rate_provider_screen.dart';

enum PaymentMethod { cash, mobileMoney, card }

class PaymentSimulationScreen extends StatefulWidget {
  final Booking booking;

  const PaymentSimulationScreen({
    super.key,
    required this.booking,
  });

  @override
  State<PaymentSimulationScreen> createState() => _PaymentSimulationScreenState();
}

class _PaymentSimulationScreenState extends State<PaymentSimulationScreen>
    with SingleTickerProviderStateMixin {
  PaymentMethod _selectedMethod = PaymentMethod.mobileMoney;
  bool _isProcessing = false;
  bool _paymentComplete = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  double get _totalAmount => widget.booking.finalPrice > 0
      ? widget.booking.finalPrice
      : widget.booking.estimatedPrice;

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
        title: const Text('Payment'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: _paymentComplete ? _buildSuccessView() : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 20,
          tablet: 24,
          desktop: 32,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Summary Card
          _buildPaymentSummary(),
          const SizedBox(height: 24),

          // Payment Method Selection
          Text(
            'Select Payment Method',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodTile(
            PaymentMethod.mobileMoney,
            'Mobile Money',
            'Airtel Money, MTN, Zamtel',
            Icons.phone_android,
          ),
          const SizedBox(height: 12),
          _buildPaymentMethodTile(
            PaymentMethod.card,
            'Debit/Credit Card',
            'Visa, Mastercard',
            Icons.credit_card,
          ),
          const SizedBox(height: 12),
          _buildPaymentMethodTile(
            PaymentMethod.cash,
            'Cash Payment',
            'Pay provider directly',
            Icons.money,
          ),
          const SizedBox(height: 24),

          // Payment Details Form
          if (_selectedMethod == PaymentMethod.mobileMoney)
            _buildMobileMoneyForm(),
          if (_selectedMethod == PaymentMethod.card) _buildCardForm(),
          if (_selectedMethod == PaymentMethod.cash) _buildCashInfo(),

          const SizedBox(height: 32),

          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: AppTheme.primaryButtonStyle,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pay K${_totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Security Notice
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 16,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Secure payment • Simulation mode',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Summary',
                style: AppTheme.heading3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Service', widget.booking.serviceTitle),
          const SizedBox(height: 8),
          _buildSummaryRow('Provider', widget.booking.providerData?['businessName'] ?? 'Provider'),
          const SizedBox(height: 8),
          _buildSummaryRow('Date', widget.booking.formattedScheduledDate),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'K${_totalAmount.toStringAsFixed(0)}',
                style: AppTheme.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple.withValues(alpha: 0.1) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.cardLight,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryPurple
                    : AppTheme.primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMoneyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Money Details',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: AppTheme.inputDecoration.copyWith(
            labelText: 'Phone Number',
            hintText: '0977 123 456',
            prefixIcon: const Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You\'ll receive a USSD prompt to confirm payment',
                  style: AppTheme.caption.copyWith(color: AppTheme.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Details',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardNumberController,
          decoration: AppTheme.inputDecoration.copyWith(
            labelText: 'Card Number',
            hintText: '1234 5678 9012 3456',
            prefixIcon: const Icon(Icons.credit_card),
          ),
          keyboardType: TextInputType.number,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Expiry',
                  hintText: 'MM/YY',
                ),
                keyboardType: TextInputType.number,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvvController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'CVV',
                  hintText: '123',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warning),
              const SizedBox(width: 12),
              Text(
                'Cash Payment Instructions',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Pay the provider directly when service is completed\n'
            '• Make sure to get a receipt\n'
            '• Confirm the exact amount before payment',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppTheme.success,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Payment Successful!',
              style: AppTheme.heading2.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'K${_totalAmount.toStringAsFixed(0)} paid',
              style: AppTheme.heading3.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transaction ID: ${widget.booking.bookingId.substring(0, 8).toUpperCase()}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _proceedToRating,
                style: AppTheme.primaryButtonStyle,
                icon: const Icon(Icons.star),
                label: const Text(
                  'Rate Your Experience',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Update booking payment status in Firestore
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.bookingId)
          .update({
        'paymentStatus': 'paid',
        'paymentMethod': _selectedMethod.name,
        'paymentId': 'PAY_${DateTime.now().millisecondsSinceEpoch}',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Payment completed for booking: ${widget.booking.bookingId}');

      // Show success animation
      setState(() {
        _isProcessing = false;
        _paymentComplete = true;
      });
      _animationController.forward();
    } catch (e) {
      AppLogger.error('Payment error: $e');
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _proceedToRating() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RateProviderScreen(booking: widget.booking),
      ),
    );
  }
}
