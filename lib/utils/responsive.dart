import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
/// Supports mobile, tablet, and web/desktop layouts
class ResponsiveHelper {
  /// Screen size breakpoints
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
    } else if (width < desktopBreakpoint) {
      return ScreenType.desktop;
    } else {
      return ScreenType.largeDesktop;
    }
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if current screen is desktop or larger
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive value based on screen size
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= tabletBreakpoint && desktop != null) {
      return desktop;
    } else if (width >= mobileBreakpoint && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  /// Get responsive horizontal padding
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 16),
      tablet: const EdgeInsets.symmetric(horizontal: 32),
      desktop: const EdgeInsets.symmetric(horizontal: 48),
    );
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      desktop: desktop ?? mobile * 1.2,
    );
  }

  /// Get responsive grid column count
  static int getGridColumnCount(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
  }

  /// Get max content width for centered layout (useful for web)
  static double getMaxContentWidth(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: double.infinity,
      tablet: 800,
      desktop: 1200,
    );
  }

  /// Wrap widget with max width constraint (for web/desktop)
  static Widget constrainedContent(
    BuildContext context, {
    required Widget child,
    double? maxWidth,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = maxWidth ?? getMaxContentWidth(context);
    
    if (screenWidth > effectiveMaxWidth) {
      return Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: child,
        ),
      );
    }
    
    return child;
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
  }

  /// Get responsive card elevation
  static double getResponsiveElevation(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 2.0,
      tablet: 3.0,
      desktop: 4.0,
    );
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: kToolbarHeight,
      tablet: kToolbarHeight + 8,
      desktop: kToolbarHeight + 16,
    );
  }

  /// Get responsive dialog width
  static double? getDialogWidth(BuildContext context) {
    return getResponsiveValue<double?>(
      context,
      mobile: null, // Full width on mobile
      tablet: 600,
      desktop: 700,
    );
  }

  /// Get responsive image height
  static double getResponsiveImageHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 200.0,
      tablet: 250.0,
      desktop: 300.0,
    );
  }

  /// Get responsive card width for grid
  static double getResponsiveCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = getGridColumnCount(context);
    final spacing = getResponsiveSpacing(context);
    final padding = getResponsivePadding(context).horizontal;
    
    return (screenWidth - padding - (spacing * (columns - 1))) / columns;
  }

  /// Get cross axis count for grid view
  static int getCrossAxisCount(BuildContext context, {
    int? mobileCount,
    int? tabletCount,
    int? desktopCount,
  }) {
    return getResponsiveValue(
      context,
      mobile: mobileCount ?? 2,
      tablet: tabletCount ?? 3,
      desktop: desktopCount ?? 4,
    );
  }

  /// Get aspect ratio for cards/images
  static double getAspectRatio(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 0.85,
      tablet: 0.9,
      desktop: 1.0,
    );
  }
}

/// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Extension on BuildContext for easy access to responsive helpers
extension ResponsiveContext on BuildContext {
  /// Check if mobile
  bool get isMobile => ResponsiveHelper.isMobile(this);
  
  /// Check if tablet
  bool get isTablet => ResponsiveHelper.isTablet(this);
  
  /// Check if desktop
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  
  /// Get screen type
  ScreenType get screenType => ResponsiveHelper.getScreenType(this);
  
  /// Get responsive padding
  EdgeInsets get responsivePadding => ResponsiveHelper.getResponsivePadding(this);
  
  /// Get responsive spacing
  double get responsiveSpacing => ResponsiveHelper.getResponsiveSpacing(this);
  
  /// Get max content width
  double get maxContentWidth => ResponsiveHelper.getMaxContentWidth(this);
  
  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;
}
