import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/booking.dart';
import '../../services/enhanced_booking_service.dart';
import '../../utils/responsive_utils.dart';
import 'booking_status_screen.dart';
import 'customer_home_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
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
    final authService = Provider.of<shared.AuthService>(context);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: Text(
            'Please log in to view your bookings',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Safely navigate back to home, handle case where there's no previous route
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // If can't pop (no previous route), navigate to customer home screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CustomerHomeScreen(),
                ),
              );
            }
          },
          color: AppTheme.textPrimary,
        ),
        title: Text(
          'My Bookings',
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
        elevation: 0,
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
            Tab(text: 'Pending'),
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
    final authService = Provider.of<shared.AuthService>(context);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please log in to view your bookings',
          style: TextStyle(color: AppTheme.textPrimary),
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
        userId: currentUser.uid,
        userType: UserType.customer,
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
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookingStatusScreen(bookingId: booking.bookingId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
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
        return AppTheme.info;
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