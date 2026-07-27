import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final Function(String) onChanged;

  const SearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'بحث...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
