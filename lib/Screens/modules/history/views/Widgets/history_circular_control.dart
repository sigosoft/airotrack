import 'package:flutter/material.dart';

class HistoryCircularControl extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const HistoryCircularControl({
    Key? key,
    required this.child,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        width: 35,
        height: 35,
        color: Colors.transparent,
        child: Center(child: child),
      ),
    );
  }
}
