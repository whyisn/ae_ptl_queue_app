import 'package:flutter/material.dart';

class PTLSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final String? hintText;
  const PTLSearchBar({super.key, this.onChanged, this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hintText ?? 'Cari…',
        filled: true,
      ),
    );
  }
}
