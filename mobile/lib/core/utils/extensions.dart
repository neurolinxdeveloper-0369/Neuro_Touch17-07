import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

extension BuildContextExtensions on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  bool get isLandscape => MediaQuery.orientationOf(this) == Orientation.landscape;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  void showSnackBar(String message, {Color? backgroundColor, IconData? icon}) {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ??
            (isDark ? AppColors.cardBackground(true) : Colors.grey[900]),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showErrorSnackBar(String message) => showSnackBar(
        message,
        backgroundColor: AppColors.error,
        icon: Icons.error_outline_rounded,
      );

  void showSuccessSnackBar(String message) => showSnackBar(
        message,
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      );

  void showInfoSnackBar(String message) => showSnackBar(
        message,
        backgroundColor: AppColors.info,
        icon: Icons.info_outline_rounded,
      );
}

extension StringExtensions on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  bool get isValidEmail =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(this);

  bool get isValidPhone =>
      RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(replaceAll(' ', ''));

  String truncate(int length) =>
      this.length <= length ? this : '${substring(0, length)}...';

  String get initials {
    final parts = trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String get toTitleCase => split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '$day/$month/$year';
  }

  String get formatDateTime {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year '
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String get formatDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$day ${months[month - 1]} $year';
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  String get greeting {
    final h = hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

extension DoubleExtensions on double {
  String get toKwhString => '${toStringAsFixed(2)} kWh';

  String get toWattsString =>
      this >= 1000 ? '${(this / 1000).toStringAsFixed(2)} kW' : '${toStringAsFixed(1)} W';

  String get toVoltageString => '${toStringAsFixed(1)} V';

  String get toCurrentString => '${toStringAsFixed(2)} A';

  String get toPfString => toStringAsFixed(2);

  String get toTempString => '${toStringAsFixed(1)}°C';

  String get toHumidityString => '${toStringAsFixed(1)}%';
}

extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
