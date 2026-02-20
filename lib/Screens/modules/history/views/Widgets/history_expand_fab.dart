import 'package:flutter/material.dart';

class HistoryExpandFab extends StatelessWidget {
  final VoidCallback onTap;

  const HistoryExpandFab({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: const Icon(
          Icons.keyboard_arrow_up,
          color: Colors.black,
        ),
      ),
    );
  }
}
