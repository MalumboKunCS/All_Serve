import 'package:flutter/material.dart';

import 'advanced_search_screen.dart';

/// Simple search screen that redirects to the comprehensive AdvancedSearchScreen
class SearchScreen extends StatelessWidget {
  final String? initialQuery;
  final String? categoryId;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    // Immediately redirect to the advanced search screen
    // This maintains backward compatibility while using the advanced features
    return AdvancedSearchScreen(
      initialQuery: initialQuery,
      categoryId: categoryId,
    );
  }
}

