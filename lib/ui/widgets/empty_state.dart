import 'package:flutter/material.dart';
import '../../config/theme.dart';

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState({super.key, this.message = 'لا توجد بيانات'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: AppTheme.textSecondaryColor),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppTheme.textSecondaryColor)),
        ],
      ),
    );
  }
}
