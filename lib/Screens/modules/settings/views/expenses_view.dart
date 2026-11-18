import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/expenses_controller.dart';

class ExpensesView extends GetView<ExpensesController> {
  const ExpensesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Expenses',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 20),
            child: Obx(
              () => RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    const TextSpan(text: 'Total: ', style: TextStyle(fontSize: 14)),
                    TextSpan(
                      text: '${formatAmount(controller.totalAmount.value)} INR',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 15),
                RecordsSearchField(
                  hint: 'Search Vehicles',
                  controller: controller.searchController,
                  onChanged: controller.onSearchChanged,
                ),
                const SizedBox(height: 20),
                PeriodFilterRow(controller: controller),
                const SizedBox(height: 25),
                Expanded(
                  child: RecordsListBody<ExpenseModel>(
                    controller: controller,
                    emptyText: 'No expenses found.\nTap + to add one.',
                    padding: const EdgeInsets.only(bottom: 90),
                    spacing: 12,
                    itemBuilder: (context, e) => ExpenseTile(
                      expense: e,
                      onTap: () => _showDetails(e),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 16.5,
            child: FloatingActionButton(
              onPressed: controller.openAdd,
              backgroundColor: kRecordsBlue,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  /// Details from `view_expense`, with Edit and Delete.
  Future<void> _showDetails(ExpenseModel fromList) async {
    dismissKeyboard();
    Get.bottomSheet(
      _ExpenseDetailsSheet(controller: controller, initial: fromList),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  const ExpenseTile({super.key, required this.expense, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final imageUrl = e.image.isEmpty ? '' : storageFileUrl(e.image);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.vehicleNumber,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1EFFF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          e.expenseTypeLabel,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatAmount(e.amount)} INR'
                    '${e.quantity != null ? '  ·  Qty ${formatAmount(e.quantity!)}' : ''}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.expenseDate == null ? '' : recordDateFmt.format(e.expenseDate!),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      children: [
                        const TextSpan(text: 'Payment: '),
                        TextSpan(
                          text: e.paymentMethodLabel,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 55.32,
              height: 76.95,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
              child: imageUrl.isEmpty
                  ? Image.asset('lib/Asset/Icons/Expenses.png', fit: BoxFit.cover)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('lib/Asset/Icons/Expenses.png', fit: BoxFit.cover),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailsSheet extends StatefulWidget {
  final ExpensesController controller;
  final ExpenseModel initial;
  const _ExpenseDetailsSheet({required this.controller, required this.initial});

  @override
  State<_ExpenseDetailsSheet> createState() => _ExpenseDetailsSheetState();
}

class _ExpenseDetailsSheetState extends State<_ExpenseDetailsSheet> {
  late ExpenseModel e = widget.initial;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.fetchExpense(e.id).then((fresh) {
      if (!mounted) return;
      setState(() {
        if (fresh != null) e = fresh;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = e.image.isEmpty ? '' : storageFileUrl(e.image);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Expense Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kRecordsBlue),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _row('Vehicle', e.vehicleNumber),
            _row('Date', e.expenseDate == null ? '-' : recordDateFmt.format(e.expenseDate!)),
            _row('Type', e.expenseTypeLabel),
            _row('Amount', '${formatAmount(e.amount)} INR'),
            if (e.quantity != null) _row('Quantity', formatAmount(e.quantity!)),
            _row('Payment', e.paymentMethodLabel),
            if (e.description.isNotEmpty) _row('Description', e.description),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => openImageViewer(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl,
                      width: 160,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      if (await widget.controller.delete(e)) nav.pop();
                    },
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRecordsBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.controller.openEdit(e);
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
