import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Screens/routes/app_routes.dart';
import 'package:airotrack/Screens/widgets/records_support.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData;

/// Expenses list (`expenses`) with search, period filter, paging, total,
/// details, edit and delete.
class ExpensesController extends PagedRecordsController<ExpenseModel> {
  /// Sum of every expense matching the current filter (server-side).
  final totalAmount = RxNum(0);

  @override
  Future<(List<ExpenseModel>, PageInfo, Map<String, dynamic>)> fetchPage(
    Map<String, dynamic> query,
  ) async {
    final response = await DioClient().get(ApiEndPoints.expenses, query: query);
    final data = apiData(response, fallbackError: 'Could not load expenses');
    final list = data['expenses'];
    final rows = list is List
        ? list.whereType<Map>().map(ExpenseModel.fromJson).toList()
        : <ExpenseModel>[];
    return (rows, PageInfo.fromJson(data['pagination']), data);
  }

  @override
  void onPageData(Map<String, dynamic> data, {required bool firstPage}) {
    final t = data['total_amount'];
    totalAmount.value = t is num ? t : (num.tryParse('${t ?? ''}') ?? 0);
  }

  @override
  Future<void> refreshList() async {
    await super.refreshList();
    if (error.value.isNotEmpty) totalAmount.value = 0;
  }

  /// Fresh copy from `view_expense`, or null (with an error shown).
  Future<ExpenseModel?> fetchExpense(int id) async {
    try {
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.viewExpense, query: {'id': id});
      final e = apiData(response, fallbackError: 'Could not load expense')['expense'];
      return e is Map ? ExpenseModel.fromJson(e) : null;
    } catch (e) {
      showRecordError(e);
      return null;
    }
  }

  Future<void> openAdd() async {
    dismissKeyboard();
    final saved = await Get.toNamed(Routes.ADD_EXPENSE);
    if (saved == true) refreshList();
  }

  Future<void> openEdit(ExpenseModel expense) async {
    dismissKeyboard();
    final saved = await Get.toNamed(Routes.ADD_EXPENSE, arguments: {'expense': expense});
    if (saved == true) refreshList();
  }

  /// Returns true when the expense was deleted.
  Future<bool> delete(ExpenseModel expense) async {
    if (!await confirmDelete('expense')) return false;
    try {
      await ensureApiToken();
      final response = await DioClient().post(
        ApiEndPoints.deleteExpense,
        body: FormData.fromMap({'id': expense.id}),
      );
      apiData(response, fallbackError: 'Could not delete expense');
      showRecordSuccess('Expense deleted');
      refreshList(); // the total changes too
      return true;
    } catch (e) {
      showRecordError(e);
      return false;
    }
  }
}
