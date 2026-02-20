import 'package:flutter/material.dart';

class HistoryDashedLine extends StatelessWidget {
  final int segmentCount;

  const HistoryDashedLine({Key? key, this.segmentCount = 40}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        segmentCount,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade400,
            height: 1,
          ),
        ),
      ),
    );
  }
}
