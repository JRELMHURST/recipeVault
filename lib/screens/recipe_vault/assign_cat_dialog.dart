import 'package:flutter/material.dart';

class AssignCategoriesDialog extends StatefulWidget {
  final List<String> categories;
  final List<String> current;
  final void Function(List<String>) onConfirm;

  const AssignCategoriesDialog({
    super.key,
    required this.categories,
    required this.current,
    required this.onConfirm,
  });

  @override
  State<AssignCategoriesDialog> createState() => _AssignCategoriesDialogState();
}

class _AssignCategoriesDialogState extends State<AssignCategoriesDialog> {
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.current.isNotEmpty ? widget.current.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.categories.where(
      (c) => c != 'Favourites' && c != 'Translated' && c != 'All',
    );

    return AlertDialog(
      title: const Text('Assign Category'),
      content: SingleChildScrollView(
        child: Column(
          children: filtered.map((cat) {
            return RadioListTile<String>(
              title: Text(cat),
              value: cat,
              groupValue: selected,
              onChanged: (value) => setState(() => selected = value),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(selected != null ? [selected!] : []);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
