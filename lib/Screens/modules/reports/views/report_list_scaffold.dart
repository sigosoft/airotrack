import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared list shell used by all report screens.
class ReportListScaffold extends StatefulWidget {
  final ReportType type;
  final String title;
  final Widget Function(BuildContext context, ReportItem item, int index)
      itemBuilder;
  final void Function(ReportItem item)? onTap;

  const ReportListScaffold({
    Key? key,
    required this.type,
    required this.title,
    required this.itemBuilder,
    this.onTap,
  }) : super(key: key);

  @override
  State<ReportListScaffold> createState() => _ReportListScaffoldState();
}

class _ReportListScaffoldState extends State<ReportListScaffold> {
  late final ReportsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ReportsController>()
        ? Get.find<ReportsController>()
        : Get.put(ReportsController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.configure(widget.type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 22),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'lib/Asset/Icons/download.png',
              width: 32,
              height: 32,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => controller.searchQuery.value = v,
                      decoration: const InputDecoration(
                        hintText: "Search Vehicles",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        contentPadding: EdgeInsets.only(bottom: 12),
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.grey, size: 24),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Obx(
              () => Row(
                children: [
                  for (final label in [
                    'Today',
                    'Yesterday',
                    'Week',
                    'Month',
                  ]) ...[
                    _buildFilterTab(
                      label,
                      controller.selectedPeriod.value == label,
                      () => controller.setPeriod(label),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Image.asset(
                    'lib/Asset/Icons/Calender.png',
                    height: 28,
                    width: 28,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final list = controller.filteredItems;
              if (controller.isLoading.value && list.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF009FE3)),
                  ),
                );
              }
              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    'No reports found',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.separated(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.31,
                  vertical: 10,
                ),
                itemCount: list.length +
                    (controller.isLoading.value && controller.hasMore.value
                        ? 1
                        : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= list.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF009FE3),
                          ),
                        ),
                      ),
                    );
                  }
                  final item = list[index];
                  return GestureDetector(
                    onTap: widget.onTap == null
                        ? null
                        : () => widget.onTap!(item),
                    child: widget.itemBuilder(context, item, index),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.2,
        height: 26.89,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF009FE3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

String reportDisplay(String value, {String fallback = '—'}) {
  final text = value.trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}
