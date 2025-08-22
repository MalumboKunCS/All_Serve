import 'package:flutter/material.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/provider_service.dart';

class ProviderEarningsPage extends StatefulWidget {
  final Provider provider;

  const ProviderEarningsPage({super.key, required this.provider});

  @override
  State<ProviderEarningsPage> createState() => _ProviderEarningsPageState();
}

class _ProviderEarningsPageState extends State<ProviderEarningsPage> {
  final ProviderService _providerService = ProviderService();
  Map<String, dynamic>? _earnings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    final earnings = await _providerService.getProviderEarnings(widget.provider.id);
    setState(() {
      _earnings = earnings;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Payments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadEarnings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.5,
              children: [
                _buildEarningsCard(
                  'Total Earnings',
                  'K${(_earnings?['totalEarnings'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildEarningsCard(
                  'Completed Jobs',
                  '${_earnings?['completedJobs'] ?? 0}',
                  Icons.task_alt,
                  Colors.blue,
                ),
                _buildEarningsCard(
                  'Average Job Value',
                  'K${(_earnings?['averageJobValue'] ?? 0.0).toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Monthly Earnings Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Earnings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_earnings?['monthlyEarnings'] != null)
                      _buildMonthlyEarningsChart()
                    else
                      const Center(
                        child: Text('No earnings data available'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Payment Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPaymentInfo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyEarningsChart() {
    final monthlyEarnings = _earnings!['monthlyEarnings'] as Map<String, double>;
    
    if (monthlyEarnings.isEmpty) {
      return const Center(
        child: Text('No monthly earnings data available'),
      );
    }

    // Get the last 6 months of data
    final sortedEntries = monthlyEarnings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final last6Months = sortedEntries.length > 6 
        ? sortedEntries.sublist(sortedEntries.length - 6)
        : sortedEntries;

    final maxEarning = last6Months.isEmpty 
        ? 0.0 
        : last6Months.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: last6Months.map((entry) {
          final percentage = maxEarning > 0 ? entry.value / maxEarning : 0.0;
          final monthName = _getMonthName(entry.key);
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'K${entry.value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: (percentage * 120).clamp(4.0, 120.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                monthName,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Column(
      children: [
        _buildInfoRow('Payment Method', 'Bank Transfer'),
        _buildInfoRow('Payment Frequency', 'Weekly'),
        _buildInfoRow('Next Payment', 'Friday, ${_getNextFriday()}'),
        _buildInfoRow('Commission Rate', '10%'),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Payments are processed weekly on Fridays. A 10% commission is deducted from each completed job. Ensure your bank details are up to date in your profile.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to payment settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment settings will be available soon'),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('Payment Settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(String monthKey) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final monthIndex = int.tryParse(parts[1]);
      if (monthIndex != null && monthIndex >= 1 && monthIndex <= 12) {
        return months[monthIndex - 1];
      }
    }
    return monthKey;
  }

  String _getNextFriday() {
    final now = DateTime.now();
    final daysUntilFriday = (5 - now.weekday) % 7;
    final nextFriday = now.add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));
    return '${nextFriday.day}/${nextFriday.month}/${nextFriday.year}';
  }
}



