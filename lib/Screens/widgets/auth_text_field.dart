import 'package:flutter/material.dart';
import '../../Utils/app_styles.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String errorText;

  const AuthTextField({
    Key? key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.errorText = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width < AppStyles.inputWidth + 32
              ? MediaQuery.of(context).size.width - 32
              : AppStyles.inputWidth,
          height: AppStyles.inputHeight,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppStyles.inputRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              border: InputBorder.none,
              isCollapsed: true,
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 5),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
