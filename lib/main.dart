import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'Screens/routes/app_pages.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    await Hive.openBox('userBox');
  } catch (e) {
    print('Error initializing Hive: $e');
    print(
      'If you see MissingPluginException, please fully restart the app to link native plugins.',
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Airotrack',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF009FE3)),
        useMaterial3: true,
      ),
    );
  }
}
