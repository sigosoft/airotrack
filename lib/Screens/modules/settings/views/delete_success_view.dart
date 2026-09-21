import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class DeleteSuccessView extends StatefulWidget {
  const DeleteSuccessView({Key? key}) : super(key: key);

  @override
  State<DeleteSuccessView> createState() => _DeleteSuccessViewState();
}

class _DeleteSuccessViewState extends State<DeleteSuccessView> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Get.offAllNamed(Routes.LOGIN);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your account has been successfully deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Image.asset(
              'lib/Asset/Icons/Success.png',
              width: 156.02,
              height: 156.02,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
