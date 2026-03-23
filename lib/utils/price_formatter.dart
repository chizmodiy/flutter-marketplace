import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PriceFormatter {
  PriceFormatter._();

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('uk');

  static String formatCurrency(num value, {String? currency}) {
    final symbol = _currencySymbol(currency);
    final formattedNumber = formatNumber(value);
    // UAH symbol goes to the right, others to the left.
    final normalized = currency?.trim().toLowerCase();
    final isUah =
        normalized == 'uah' ||
        normalized == '₴' ||
        normalized == null ||
        normalized.isEmpty;
    return isUah ? '$formattedNumber $symbol' : '$symbol$formattedNumber';
  }

  static String formatNumber(num value) {
    final intValue = value is int ? value : value.toInt();
    final formatted = _numberFormat.format(intValue);
    // Use spaces as thousands separator instead of whatever the locale defaults to if it's not a space
    return formatted
        .replaceAll(',', ' ')
        .replaceAll('.', ' ')
        .replaceAll('\u00A0', ' ');
  }

  static String _currencySymbol(String? currency) {
    final normalized = currency?.trim().toLowerCase();
    switch (normalized) {
      case 'uah':
      case '₴':
        return 'грн';
      case 'usd':
      case '\$':
      case 'dollar':
        return '\$';
      case 'eur':
      case '€':
      case 'euro':
        return '€';
      default:
        return 'грн';
    }
  }
}

class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && (digitsOnly.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formattedString = buffer.toString();

    return TextEditingValue(
      text: formattedString,
      selection: TextSelection.collapsed(offset: formattedString.length),
    );
  }
}
