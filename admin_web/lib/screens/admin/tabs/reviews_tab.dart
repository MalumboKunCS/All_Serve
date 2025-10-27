import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared/shared.dart';

class ReviewsTab extends StatelessWidget {
  const ReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews Management',
            style: AppTheme.heading1.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Moderate and manage customer reviews',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Placeholder content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reviews Management',
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This section will show flagged reviews and moderation tools',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}














