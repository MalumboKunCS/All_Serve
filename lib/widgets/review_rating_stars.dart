import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReviewRatingStars extends StatelessWidget {
  final double rating;
  final double? size;
  final Color? color;
  final bool allowInteraction;
  final ValueChanged<double>? onRatingChanged;
  final int maxRating;

  const ReviewRatingStars({
    super.key,
    required this.rating,
    this.size,
    this.color,
    this.allowInteraction = false,
    this.onRatingChanged,
    this.maxRating = 5,
  });

  @override
  Widget build(BuildContext context) {
    final starSize = size ?? 20.0;
    final starColor = color ?? AppTheme.warning;

    if (allowInteraction && onRatingChanged != null) {
      return _buildInteractiveStars(starSize, starColor);
    } else {
      return _buildDisplayStars(starSize, starColor);
    }
  }

  Widget _buildInteractiveStars(double starSize, Color starColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starIndex = index + 1;
        final isSelected = starIndex <= rating;
        final isHalfSelected = starIndex - 0.5 <= rating && starIndex > rating;

        return GestureDetector(
          onTap: () => onRatingChanged!(starIndex.toDouble()),
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isSelected
                  ? Icons.star
                  : isHalfSelected
                      ? Icons.star_half
                      : Icons.star_border,
              size: starSize,
              color: starColor,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDisplayStars(double starSize, Color starColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starIndex = index + 1;
        final isSelected = starIndex <= rating;
        final isHalfSelected = starIndex - 0.5 <= rating && starIndex > rating;

        return Icon(
          isSelected
              ? Icons.star
              : isHalfSelected
                  ? Icons.star_half
                  : Icons.star_border,
          size: starSize,
          color: starColor,
        );
      }),
    );
  }
}

class ReviewRatingInput extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double> onRatingChanged;
  final String? label;

  const ReviewRatingInput({
    super.key,
    this.initialRating = 5.0,
    required this.onRatingChanged,
    this.label,
  });

  @override
  State<ReviewRatingInput> createState() => _ReviewRatingInputState();
}

class _ReviewRatingInputState extends State<ReviewRatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            ReviewRatingStars(
              rating: _currentRating,
              size: 32,
              allowInteraction: true,
              onRatingChanged: (rating) {
                setState(() {
                  _currentRating = rating;
                });
                widget.onRatingChanged(rating);
              },
            ),
            const SizedBox(width: 12),
            Text(
              _getRatingText(_currentRating),
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent';
    if (rating >= 4) return 'Good';
    if (rating >= 3) return 'Average';
    if (rating >= 2) return 'Poor';
    return 'Very Poor';
  }
}

