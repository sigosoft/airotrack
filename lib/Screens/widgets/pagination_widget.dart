import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationWidget({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildArrowButton(
            Icons.chevron_left,
            currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          const SizedBox(width: 12),
          ..._buildPageNumbers(),
          const SizedBox(width: 12),
          _buildArrowButton(
            Icons.chevron_right,
            currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> widgets = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= currentPage - 1 && i <= currentPage + 1)) {
        widgets.add(_buildPageButton(i));
        if (i < totalPages &&
            (i == 1 && currentPage > 3 ||
                i == currentPage + 1 && currentPage < totalPages - 2)) {
          widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
        }
      }
    }
    return widgets;
  }

  Widget _buildPageButton(int page) {
    bool isSelected = page == currentPage;
    return GestureDetector(
      onTap: () => onPageChanged(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF009FE3) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF009FE3) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            page.toString(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? Colors.grey : Colors.black,
        ),
      ),
    );
  }
}
