import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/track_controller.dart';

const Color _blue = Color(0xFF009FE3);

/// One choice in the sheet: how long the shared link keeps working.
class _ShareOption {
  const _ShareOption(this.label, this.hours);
  final String label;
  final int hours; // 0 = only once
}

const List<_ShareOption> _options = [
  _ShareOption('Only Once', 0),
  _ShareOption('1 Hour', 1),
  _ShareOption('1 Day', 24),
  _ShareOption('1 Week', 168),
  _ShareOption('2 Weeks', 336),
];

/// "Share Live Location": pick how long the link works (only once, 1 hour …
/// 2 weeks, or a custom number of hours), then Share asks the server for a
/// live-tracking link and opens the phone's share sheet with it.
class ShareLiveLocationSheet extends StatefulWidget {
  const ShareLiveLocationSheet({super.key, required this.controller});

  final TrackController controller;

  static Future<void> show(BuildContext context, TrackController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareLiveLocationSheet(controller: controller),
    );
  }

  @override
  State<ShareLiveLocationSheet> createState() => _ShareLiveLocationSheetState();
}

class _ShareLiveLocationSheetState extends State<ShareLiveLocationSheet> {
  /// Index into [_options]; [_custom] when Custom Hours is chosen.
  static const int _custom = -1;
  int _selected = 0;

  final _customText = TextEditingController();
  final _customFocus = FocusNode();
  String? _customError;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _customFocus.addListener(() {
      if (_customFocus.hasFocus) {
        setState(() => _selected = _custom);
      }
      // Pause the car animation behind the sheet while typing, as the
      // other input sheets on Track do, so the keyboard opens smoothly.
      widget.controller.setInputSheetOpen(_customFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    if (_customFocus.hasFocus) widget.controller.setInputSheetOpen(false);
    _customText.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _customError = null;
    });
    if (index == _custom) {
      _customFocus.requestFocus();
    } else {
      _customFocus.unfocus();
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    int hours;
    if (_selected == _custom) {
      final value = int.tryParse(_customText.text.trim());
      if (value == null || value < 1) {
        setState(() => _customError = 'Enter the number of hours (1 or more)');
        _customFocus.requestFocus();
        return;
      }
      hours = value;
    } else {
      hours = _options[_selected].hours;
    }
    _customFocus.unfocus();
    setState(() => _sharing = true);
    final shared = await widget.controller.shareLiveLocation(hours);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (shared) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      // Keep the sheet above the keyboard while typing custom hours.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + media.padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 4),
              Text(
                widget.controller.displayPlate,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _options.length; i++)
                _optionRow(
                  selected: _selected == i,
                  onTap: () => _select(i),
                  child: Text(
                    _options[i].label,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
              _optionRow(
                selected: _selected == _custom,
                onTap: () => _select(_custom),
                child: TextField(
                  controller: _customText,
                  focusNode: _customFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  // Rebuild so the "hours" label follows the text and any
                  // error clears as soon as a number is typed.
                  onChanged: (_) => setState(() => _customError = null),
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Custom Hours',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    suffixText: _customText.text.isEmpty ? null : 'hours',
                    suffixStyle:
                        TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ),
              if (_customError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    _customError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _button(
                      'Cancel',
                      filled: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _button(
                      'Share',
                      filled: true,
                      busy: _sharing,
                      onTap: _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left, size: 30),
              color: Colors.black,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Text(
            'Share Live Location',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFE8F6FD) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _blue : Colors.grey.shade300,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: child),
                const SizedBox(width: 12),
                _radio(selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _blue, width: 1.5),
      ),
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _blue,
              ),
            )
          : null,
    );
  }

  Widget _button(
    String label, {
    required bool filled,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return SizedBox(
      height: 48,
      child: Material(
        color: filled ? _blue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: busy ? null : onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: filled ? null : Border.all(color: Colors.grey.shade300),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: filled ? Colors.white : Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
