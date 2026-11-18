// Shared pieces for the Reminders, Expenses and Support Tickets screens:
// a paged list controller, API response checks, the vehicle list, and the
// search / period / picker / image widgets those screens use.

import 'dart:async';
import 'dart:io';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/VehicleRecordModels.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const kRecordsBlue = Color(0xFF009FE3);

/// Returns `data` from a `{status, data, message}` response, or throws the
/// server message when `status` is false.
Map<String, dynamic> apiData(dio.Response response, {String fallbackError = 'Request failed'}) {
  final body = response.data;
  if (body is! Map) throw fallbackError;
  if (body['status'] == false) {
    final msg = body['message'];
    if (msg is String && msg.isNotEmpty) throw msg;
    if (msg is Map && msg.isNotEmpty) {
      final first = msg.values.first;
      throw first is List && first.isNotEmpty ? first.first.toString() : first.toString();
    }
    throw fallbackError;
  }
  final data = body['data'];
  return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
}

/// The signed-in user's vehicle numbers (from `vehicles`), loaded once per
/// app run and shared by every form that needs a vehicle picker.
class VehicleNumbers {
  static List<String>? _cache;

  static Future<List<String>> load({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    await ensureApiToken();
    final response = await DioClient().get(ApiEndPoints.vehicles);
    final data = apiData(response);
    final list = data['vehicles'];
    final numbers = <String>[];
    if (list is List) {
      for (final v in list.whereType<Map>()) {
        final n = (v['vehicle_number'] ?? '').toString().trim();
        if (n.isNotEmpty && !numbers.contains(n)) numbers.add(n);
      }
    }
    _cache = numbers;
    return numbers;
  }

  static void clear() => _cache = null;
}

/// A searchable, paged list backed by a website list endpoint that takes
/// `keyword`, `page`, `limit` and (optionally) `period` / `from_date` / `to_date`.
abstract class PagedRecordsController<T> extends GetxController {
  static const int pageSize = 20;

  final items = <T>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final error = ''.obs;
  final hasMore = false.obs;
  final total = 0.obs;

  /// '' (all dates), today, yesterday, week, month or custom.
  final period = ''.obs;
  final customFrom = Rxn<DateTime>();
  final customTo = Rxn<DateTime>();

  final searchController = TextEditingController();
  final scrollController = ScrollController();
  String _keyword = '';
  Timer? _debounce;
  int _page = 1;
  int _requestId = 0;

  /// Fetches one page. [query] already holds keyword/page/limit/period.
  /// Returns the parsed rows, pagination and the raw `data` map.
  Future<(List<T>, PageInfo, Map<String, dynamic>)> fetchPage(
    Map<String, dynamic> query,
  );

  /// Called with each page's raw `data` (e.g. to read a total amount).
  void onPageData(Map<String, dynamic> data, {required bool firstPage}) {}

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      final pos = scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) loadMore();
    });
    refreshList();
  }

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final k = value.trim();
      if (k == _keyword) return;
      _keyword = k;
      refreshList();
    });
  }

  /// Tapping the selected chip again clears the date filter.
  void selectPeriod(String value) {
    period.value = period.value == value ? '' : value;
    refreshList();
  }

  void setCustomRange(DateTime from, DateTime to) {
    customFrom.value = from;
    customTo.value = to;
    period.value = 'custom';
    refreshList();
  }

  Map<String, dynamic> _query(int page) {
    final fmt = DateFormat('yyyy-MM-dd');
    final q = <String, dynamic>{
      'page': page,
      'limit': pageSize,
      if (_keyword.isNotEmpty) 'keyword': _keyword,
    };
    if (period.value == 'custom' && customFrom.value != null && customTo.value != null) {
      // The API rejects period=custom; a plain date range filters instead.
      q['from_date'] = fmt.format(customFrom.value!);
      q['to_date'] = fmt.format(customTo.value!);
    } else if (period.value.isNotEmpty) {
      q['period'] = period.value;
    }
    return q;
  }

  Future<void> refreshList() async {
    final id = ++_requestId;
    isLoading.value = true;
    error.value = '';
    try {
      await ensureApiToken();
      final (rows, page, data) = await fetchPage(_query(1));
      if (id != _requestId) return;
      _page = 1;
      items.assignAll(rows);
      hasMore.value = page.hasMore;
      total.value = page.total;
      onPageData(data, firstPage: true);
    } catch (e) {
      if (id != _requestId) return;
      items.clear();
      hasMore.value = false;
      error.value = e.toString();
    } finally {
      if (id == _requestId) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    final id = _requestId;
    isLoadingMore.value = true;
    try {
      final (rows, page, data) = await fetchPage(_query(_page + 1));
      if (id != _requestId) return;
      _page = page.currentPage;
      items.addAll(rows);
      hasMore.value = page.hasMore;
      onPageData(data, firstPage: false);
    } catch (_) {
      // Keep what is shown; scrolling again retries.
    } finally {
      isLoadingMore.value = false;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}

/// Rounded search box used at the top of each list.
class RecordsSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final double radius;

  const RecordsSearchField({
    super.key,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTapOutside: (_) => dismissKeyboard(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          Icon(Icons.search, color: Colors.grey.shade400, size: 28),
        ],
      ),
    );
  }
}

/// Today / Yesterday / Week / Month chips plus the calendar (custom range).
class PeriodFilterRow extends StatelessWidget {
  final PagedRecordsController controller;
  const PeriodFilterRow({super.key, required this.controller});

  static const _chips = [
    ('Today', 'today'),
    ('Yesterday', 'yesterday'),
    ('Week', 'week'),
    ('Month', 'month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.period.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (label, value) in _chips)
            _chip(label, selected == value, () => controller.selectPeriod(value)),
          GestureDetector(
            onTap: () => _pickRange(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: selected == 'custom'
                  ? BoxDecoration(
                      border: Border.all(color: kRecordsBlue),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Image.asset('lib/Asset/Icons/Calender.png', width: 25, height: 25),
            ),
          ),
        ],
      );
    });
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.2,
        height: 26.89,
        decoration: BoxDecoration(
          color: isSelected ? kRecordsBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? kRecordsBlue : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    dismissKeyboard();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = controller.customFrom.value;
    final to = controller.customTo.value;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : DateTimeRange(start: today, end: today),
      builder: _blueTheme,
    );
    if (picked == null) return;
    controller.setCustomRange(picked.start, picked.end);
  }
}

Widget _blueTheme(BuildContext context, Widget? child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: kRecordsBlue),
      ),
      child: child!,
    );

/// Date picker in the app's blue.
Future<DateTime?> pickRecordDate(BuildContext context, DateTime initial) {
  dismissKeyboard();
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? now : initial,
    firstDate: DateTime(now.year - 5),
    lastDate: now,
    builder: _blueTheme,
  );
}

/// Loading / error-with-retry / empty states around a list.
class RecordsListBody<T> extends StatelessWidget {
  final PagedRecordsController<T> controller;
  final String emptyText;
  final Widget Function(BuildContext, T) itemBuilder;
  final EdgeInsets padding;
  final double spacing;

  const RecordsListBody({
    super.key,
    required this.controller,
    required this.emptyText,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.items.isEmpty) {
        return const Center(child: _Spinner());
      }
      if (controller.error.value.isNotEmpty && controller.items.isEmpty) {
        return _message(
          controller.error.value,
          action: TextButton(
            onPressed: controller.refreshList,
            child: const Text('Retry', style: TextStyle(color: kRecordsBlue)),
          ),
        );
      }
      final count = controller.items.length;
      final extra = controller.isLoadingMore.value ? 1 : 0;
      return RefreshIndicator(
        color: kRecordsBlue,
        onRefresh: controller.refreshList,
        child: count == 0
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [const SizedBox(height: 120), _message(emptyText)],
              )
            : ListView.builder(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                itemCount: count + extra,
                itemBuilder: (context, index) {
                  if (index >= count) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: _Spinner()),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: itemBuilder(context, controller.items[index]),
                  );
                },
              ),
      );
    });
  }

  Widget _message(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(kRecordsBlue),
      );
}

/// Bottom sheet listing [options]; returns the tapped one.
Future<T?> showOptionSheet<T>({
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  bool searchable = false,
}) {
  // Otherwise the last text field gets focus back (and the keyboard
  // reopens) when the sheet closes.
  dismissKeyboard();
  return Get.bottomSheet<T>(
    _OptionSheet<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      selected: selected,
      searchable: searchable,
    ),
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  );
}

class _OptionSheet<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final bool searchable;
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
    this.searchable = false,
  });

  @override
  State<_OptionSheet<T>> createState() => _OptionSheetState<T>();
}

class _OptionSheetState<T> extends State<_OptionSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final shown = widget.options
        .where((o) => widget.labelOf(o).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            Flexible(
              child: shown.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nothing to show', textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, i) {
                        final o = shown[i];
                        final isSel = o == widget.selected;
                        return ListTile(
                          title: Text(widget.labelOf(o),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? kRecordsBlue : Colors.black87,
                              )),
                          trailing: isSel ? const Icon(Icons.check, color: kRecordsBlue) : null,
                          onTap: () => Get.back(result: o),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Field that looks like a dropdown and opens a picker on tap.
class PickerField extends StatelessWidget {
  final String hint;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PickerField({
    super.key,
    required this.hint,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 13,
                ),
              ),
            ),
            trailing ??
                Image.asset(
                  'lib/Asset/Icons/Down arrow.png',
                  width: 15,
                  height: 10,
                  color: Colors.blue.shade700,
                ),
          ],
        ),
      ),
    );
  }
}

/// Red helper text under a field, shown only when [error] is not empty.
class FieldError extends StatelessWidget {
  final RxString error;
  const FieldError(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => error.value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(error.value, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ));
  }
}

/// Lets the user pick a photo from the camera or gallery.
Future<File?> pickRecordImage() async {
  final source = await showOptionSheet<ImageSource>(
    title: 'Add Image',
    options: const [ImageSource.camera, ImageSource.gallery],
    labelOf: (s) => s == ImageSource.camera ? 'Take Photo' : 'Choose from Gallery',
  );
  if (source == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1600);
    return x == null ? null : File(x.path);
  } catch (e) {
    Get.snackbar('Image', 'Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}',
        snackPosition: SnackPosition.BOTTOM);
    return null;
  }
}

/// The "Upload Image" box: shows the picked file, else the saved image URL,
/// else the upload prompt. Tap to pick, the x clears a newly picked file.
class ImageUploadBox extends StatelessWidget {
  final Rxn<File> file;
  final String existingUrl;

  const ImageUploadBox({super.key, required this.file, this.existingUrl = ''});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final f = file.value;
      Widget content;
      if (f != null) {
        content = Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } else if (existingUrl.isNotEmpty) {
        content = Image.network(existingUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _prompt());
      } else {
        content = _prompt();
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await pickRecordImage();
              if (picked != null) file.value = picked;
            },
            child: Container(
              width: 107.25,
              height: 111.8,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: content,
            ),
          ),
          if (f != null)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => file.value = null,
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _prompt() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 30, color: Colors.blue.shade300),
          const SizedBox(height: 8),
          const Text('Upload Image', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      );
}

/// Adds [file] as the multipart `image` field.
Future<void> addImageField(dio.FormData form, File? file) async {
  if (file == null) return;
  form.files.add(MapEntry(
    'image',
    await dio.MultipartFile.fromFile(file.path, filename: file.path.split(RegExp(r'[\\/]')).last),
  ));
}

/// Asks before deleting. Returns true on "Delete".
Future<bool> confirmDelete(String what) async {
  final ok = await Get.dialog<bool>(
    AlertDialog(
      title: Text('Delete $what?'),
      content: Text('This $what will be removed.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Closes the keyboard so it does not pop back up when the user returns
/// from a pushed page or a sheet.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Clears [error] as soon as the user edits [field], so a "required"
/// message does not linger after the value has been typed.
void clearErrorOnEdit(TextEditingController field, RxString error) {
  field.addListener(() {
    if (error.value.isNotEmpty) error.value = '';
  });
}

/// Digits with at most one decimal point (amounts, odometer, quantity).
final decimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
];

void showRecordSuccess(String message) {
  Get.snackbar('Success', message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white);
}

void showRecordError(Object error) {
  Get.snackbar('Error', error.toString(),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white);
}

/// Full-screen viewer for an uploaded image URL.
void openImageViewer(String url) {
  Get.dialog(
    GestureDetector(
      onTap: Get.back,
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: InteractiveViewer(
          child: Image.network(url,
              errorBuilder: (_, __, ___) =>
                  const Text('Image not available', style: TextStyle(color: Colors.white))),
        ),
      ),
    ),
  );
}

final recordDateFmt = DateFormat('dd-MM-yyyy');
final recordDateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

/// "3,500" without trailing ".0".
String formatAmount(num v) {
  final f = NumberFormat('#,##0.##');
  return f.format(v);
}
