import 'package:flutter/material.dart';

/// Responsive design utilities for different screen sizes
class ResponsiveUtils {
  // Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get screen type based on width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(16);
      case ScreenType.tablet:
        return const EdgeInsets.all(24);
      case ScreenType.desktop:
        return const EdgeInsets.all(32);
    }
  }

  /// Get responsive horizontal padding
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(horizontal: 24);
      case ScreenType.desktop:
        return const EdgeInsets.symmetric(horizontal: 32);
    }
  }

  /// Get responsive vertical padding
  static EdgeInsets getResponsiveVerticalPadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.symmetric(vertical: 16);
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(vertical: 20);
      case ScreenType.desktop:
        return const EdgeInsets.symmetric(vertical: 24);
    }
  }

  /// Get responsive grid cross axis count
  static int getResponsiveGridCrossAxisCount(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 3;
      case ScreenType.desktop:
        return 4;
    }
  }

  /// Get responsive grid child aspect ratio
  static double getResponsiveGridChildAspectRatio(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 1.0;
      case ScreenType.tablet:
        return 1.1;
      case ScreenType.desktop:
        return 1.2;
    }
  }

  /// Get responsive grid spacing
  static double getResponsiveGridSpacing(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 16;
      case ScreenType.tablet:
        return 20;
      case ScreenType.desktop:
        return 24;
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.1;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.2;
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.2;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.4;
    }
  }

  /// Get responsive container width
  static double getResponsiveContainerWidth(BuildContext context, {
    double mobileRatio = 1.0,
    double tabletRatio = 0.8,
    double desktopRatio = 0.6,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return screenWidth * mobileRatio;
      case ScreenType.tablet:
        return screenWidth * tabletRatio;
      case ScreenType.desktop:
        return screenWidth * desktopRatio;
    }
  }

  /// Get responsive max width for content
  static double getResponsiveMaxWidth(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return 800;
      case ScreenType.desktop:
        return 1200;
    }
  }

  /// Get responsive column count for lists
  static int getResponsiveColumnCount(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 1;
      case ScreenType.tablet:
        return 2;
      case ScreenType.desktop:
        return 3;
    }
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.2;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.4;
    }
  }
}

/// Screen type enumeration
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// Responsive widget that adapts its child based on screen size
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Responsive layout builder
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveUtils.getScreenType(context);
    return builder(context, screenType);
  }
}

/// Responsive grid view
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final EdgeInsets? padding;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(context),
      childAspectRatio: childAspectRatio ?? 
          ResponsiveUtils.getResponsiveGridChildAspectRatio(context),
      crossAxisSpacing: crossAxisSpacing ?? 
          ResponsiveUtils.getResponsiveGridSpacing(context),
      mainAxisSpacing: mainAxisSpacing ?? 
          ResponsiveUtils.getResponsiveGridSpacing(context),
      padding: padding ?? ResponsiveUtils.getResponsivePadding(context),
      children: children,
    );
  }
}

/// Responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final BoxDecoration? decoration;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: ResponsiveUtils.getResponsiveMaxWidth(context),
      ),
      padding: padding ?? ResponsiveUtils.getResponsivePadding(context),
      color: color,
      decoration: decoration,
      child: child,
    );
  }
}
