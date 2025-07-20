import 'package:flutter/material.dart';

typedef AssignCategoriesCallback = void Function(List<String> selected);

class AssignCategoriesDialog extends StatefulWidget {
  final List<String> allCategories;
  final List<String> initialSelection;
  final AssignCategoriesCallback onConfirm;

  const AssignCategoriesDialog({
    super.key,
    required this.allCategories,
    required this.initialSelection,
    required this.onConfirm,
  });

  @override
  State<AssignCategoriesDialog> createState() => _AssignCategoriesDialogState();
}

class _AssignCategoriesDialogState extends State<AssignCategoriesDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.allCategories
        .where((c) => c != 'Favourites' && c != 'Translated' && c != 'All')
        .toList();

    return AlertDialog(
      title: const Text('Assign Categories'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filteredCategories.map((cat) {
            return CheckboxListTile(
              value: _selected.contains(cat),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(cat);
                  } else {
                    _selected.remove(cat);
                  }
                });
              },
              title: Text(cat),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_selected.toList());
            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
