import 'package:flutter/material.dart';

class HistorySectionDivider extends StatelessWidget {
  const HistorySectionDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
