import 'package:airotrack/Services/FcmService.dart';
import 'package:airotrack/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'Screens/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Suppress flutter_map OSM tile usage warning to reduce console clutter
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        (message.contains('flutter_map') && message.contains('tile') ||
            message.contains('OpenStreetMap') ||
            message.contains('osmfoundation.org') ||
            message.contains('fleaflet.dev/osm-warn') ||
            message.contains('NOT free to use by everyone'))) {
      return;
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  try {
    await Hive.initFlutter();
    await Hive.openBox('userBox');
  } catch (e) {
    debugPrint('Error initializing Hive: $e');
    debugPrint(
      'If you see MissingPluginException, please fully restart the app to link native plugins.',
    );
  }

  await FcmService.instance.init();

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
