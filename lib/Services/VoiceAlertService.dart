import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads push notifications aloud ("TCP TSAIRO RINO. Overspeed. Near
/// Vaikom") with the phone's text-to-speech voice.
///
/// Works while the app is open or in the background, and usually when it
/// is closed (Android runs the push handler, which calls [speakAlert]).
/// iPhone doesn't let apps speak from a push unless the app is open.
class VoiceAlertService {
  VoiceAlertService._();
  static final VoiceAlertService instance = VoiceAlertService._();

  /// Stored setting: voice alerts on (default) or off. Read from storage so
  /// the push handler in the background isolate sees it too.
  static const String prefKey = 'set_voice_alerts';

  FlutterTts? _tts;
  Future<void> _queue = Future.value();

  static Future<bool> enabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, on);
    if (!on) await instance._tts?.stop();
  }

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    // Wait for each alert to finish: in the background the push handler
    // must not return (and Android stop the app) mid-sentence.
    await tts.awaitSpeakCompletion(true);
    // Indian English when the phone has it; otherwise the phone's default.
    try {
      if (await tts.isLanguageAvailable('en-IN') == true) {
        await tts.setLanguage('en-IN');
      }
    } catch (_) {}
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
    _tts = tts;
    return tts;
  }

  /// Speaks one alert built from the notification's parts. Alerts arriving
  /// together are spoken one after another, never over each other.
  Future<void> speakAlert({
    String? vehicle,
    String? type,
    String? address,
    String? title,
    String? body,
  }) {
    final text = _sentence(
      vehicle: vehicle,
      type: type,
      address: address,
      title: title,
      body: body,
    );
    if (text.isEmpty) return Future.value();
    final next = _queue.then((_) => _speak(text));
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _speak(String text) async {
    if (!await enabled()) return;
    try {
      final tts = await _engine();
      debugPrint('[Voice] speaking: $text');
      await tts.speak(text);
      debugPrint('[Voice] spoken');
    } catch (e) {
      debugPrint('[Voice] text-to-speech failed: $e');
    }
  }

  /// "TCP TSAIRO RINO. Overspeed. Near Vaikom, Kottayam." Only the first
  /// two parts of the address are read: the full one (with district, state,
  /// PIN and country) is too long to listen to.
  static String _sentence({
    String? vehicle,
    String? type,
    String? address,
    String? title,
    String? body,
  }) {
    final parts = <String>[];
    void add(String? s) {
      final t = s?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
    }

    if ((vehicle ?? '').trim().isNotEmpty || (type ?? '').trim().isNotEmpty) {
      add(vehicle);
      add(type);
      final place = (address ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !RegExp(r'^\d+$').hasMatch(s))
          .take(2)
          .join(', ');
      if (place.isNotEmpty) add('Near $place');
    } else {
      add(title);
      // Body lines: the alert, then the address (shortened as above).
      final lines = (body ?? '').split('\n');
      if (lines.isNotEmpty) add(lines.first);
      if (lines.length > 1) {
        final place = lines
            .skip(1)
            .join(', ')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !RegExp(r'^\d+$').hasMatch(s))
            .take(2)
            .join(', ');
        if (place.isNotEmpty) add('Near $place');
      }
    }
    return parts.join('. ');
  }
}
