import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Simple in-memory log buffer that captures all `print` output and `debugPrint`.
/// Keeps last [maxEntries] lines and can copy them to clipboard for easy sharing.
class AppLogger {
  AppLogger._();

  static final List<String> _buffer = [];
  static const int maxEntries = 500;
  static bool _installed = false;
  static void Function(String? message, {int? wrapWidth})? _originalDebugPrint;

  /// Installs global capture for print/debugPrint. Should be called before runApp.
  static void install() {
    if (_installed) return;
    _installed = true;

    _originalDebugPrint ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _add(message);
      _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
    };
  }

  /// Wraps body into a zone that intercepts `print`.
  static void runWithPrintCapture(void Function() body) {
    runZonedGuarded<void>(
      body,
      (error, stackTrace) {
        _add('UNCAUGHT ERROR: $error');
        _add(stackTrace.toString());
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          _add(line);
          parent.print(zone, line);
        },
      ),
    );
  }

  static void _add(String? message) {
    final text = (message ?? '').trimRight();
    if (text.isEmpty) return;
    final ts = DateTime.now().toIso8601String();
    _buffer.add('[$ts] $text');
    if (_buffer.length > maxEntries) {
      _buffer.removeRange(0, _buffer.length - maxEntries);
    }
  }

  static Future<void> copyToClipboard() async {
    final data = _buffer.join('\n');
    await Clipboard.setData(ClipboardData(text: data));
  }

  static List<String> get logs => List.unmodifiable(_buffer);
}
