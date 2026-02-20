import 'package:flutter/material.dart';

class HistorySideButton extends StatelessWidget {
  final String? assetPath;
  final String? text;
  final Color? textColor;

  const HistorySideButton({
    Key? key,
    this.assetPath,
    this.text,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: assetPath != null
            ? Image.asset(assetPath!, width: 20, height: 20)
            : Text(
                text ?? "",
                style: TextStyle(
                  color: textColor ?? Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
