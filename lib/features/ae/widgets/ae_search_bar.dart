import 'package:flutter/material.dart';

class AESearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final String? hintText;

  const AESearchBar({super.key, this.onChanged, this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hintText ?? 'Cari...',
        filled: true,
      ),
    );
  }
}
