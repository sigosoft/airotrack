import 'package:flutter/material.dart';
import '../../Utils/app_assets.dart';
import '../../Utils/app_styles.dart';

class AuthLogo extends StatelessWidget {
  const AuthLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppStyles.logoTop),
      child: Center(
        child: Image.asset(
          AppAssets.logo,
          width: AppStyles.logoWidth,
          height: AppStyles.logoHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
