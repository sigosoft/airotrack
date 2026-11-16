import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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
          // Every report is for one vehicle: pick which one here.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GestureDetector(
              onTap: _showVehiclePicker,
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.directions_car,
                      color: Color(0xFF009FE3),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Obx(() {
                        final hasVehicle =
                            controller.selectedImei.value.trim().isNotEmpty;
                        return Text(
                          hasVehicle
                              ? controller.selectedPlate.value
                              : 'Select vehicle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasVehicle ? Colors.black : Colors.grey,
                            fontSize: 14,
                            fontWeight:
                                hasVehicle ? FontWeight.w600 : FontWeight.w400,
                          ),
                        );
                      }),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF009FE3),
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
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
                  GestureDetector(
                    onTap: _pickCustomRange,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: controller.selectedPeriod.value == 'Custom'
                              ? const Color(0xFF009FE3)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Image.asset(
                        'lib/Asset/Icons/Calender.png',
                        height: 28,
                        width: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(() {
            final from = controller.customFrom.value;
            final to = controller.customTo.value;
            if (controller.selectedPeriod.value != 'Custom' ||
                from == null ||
                to == null) {
              return const SizedBox.shrink();
            }
            final fmt = DateFormat('dd MMM yyyy');
            final text = DateUtils.isSameDay(from, to)
                ? fmt.format(from)
                : '${fmt.format(from)} – ${fmt.format(to)}';
            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF009FE3),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
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
              final error = controller.loadError.value;
              if (list.isEmpty && error.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => controller.loadItems(reset: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF009FE3),
                            side: const BorderSide(color: Color(0xFF009FE3)),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
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

  /// Searchable list of the fleet; picking one reloads this report for it.
  void _showVehiclePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    final vehicles = controller.vehicles
        .where((v) => v.deviceId.trim().isNotEmpty)
        .toList();
    var query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final q = query.trim().toLowerCase();
            final shown = q.isEmpty
                ? vehicles
                : vehicles
                    .where(
                      (v) =>
                          v.plateNumber.toLowerCase().contains(q) ||
                          v.deviceId.toLowerCase().contains(q),
                    )
                    .toList();
            final selectedImei = controller.selectedImei.value.trim();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Select vehicle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          onChanged: (v) => setSheetState(() => query = v),
                          decoration: InputDecoration(
                            hintText: 'Search vehicles',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No vehicles found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: shown.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final v = shown[i];
                              final imei = v.deviceId.trim();
                              final active = imei == selectedImei;
                              return ListTile(
                                title: Text(
                                  v.plateNumber.isEmpty ? imei : v.plateNumber,
                                  style: TextStyle(
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(imei),
                                trailing: active
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF009FE3),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  if (active) return;
                                  controller.selectVehicle(
                                    imei: imei,
                                    plate: v.plateNumber.isEmpty
                                        ? imei
                                        : v.plateNumber,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = controller.customFrom.value;
    final to = controller.customTo.value;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : DateTimeRange(start: today, end: today),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF009FE3),
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    controller.setCustomRange(picked.start, picked.end);
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
