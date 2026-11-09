import '../constants/app_constants.dart';

class Formatters {
  static String formatCurrency(double amount) {
    return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
  }
}
