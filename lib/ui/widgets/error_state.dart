import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ErrorState extends StatelessWidget {
  final String message;
  const ErrorState({super.key, this.message = 'حدث خطأ'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}
