import 'package:flutter/material.dart';

class AssignCategoryDropdown extends StatefulWidget {
  final List<String> categories;
  final List<String> current;
  final void Function(List<String>) onChanged;

  const AssignCategoryDropdown({
    super.key,
    required this.categories,
    required this.current,
    required this.onChanged,
  });

  @override
  State<AssignCategoryDropdown> createState() => _AssignCategoryDropdownState();
}

class _AssignCategoryDropdownState extends State<AssignCategoryDropdown> {
  String? selected;
  bool isDropdownVisible = false;

  @override
  void initState() {
    super.initState();
    selected = widget.current.isNotEmpty ? widget.current.first : null;
  }

  @override
  void didUpdateWidget(covariant AssignCategoryDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current) {
      setState(() {
        selected = widget.current.isNotEmpty ? widget.current.first : null;
        isDropdownVisible = widget.current.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.categories
        .where((c) => c != 'Favourites' && c != 'Translated' && c != 'All')
        .toList();

    if (!isDropdownVisible &&
        (selected == null || !filtered.contains(selected))) {
      return IconButton(
        icon: const Icon(Icons.add_circle_outline, size: 20),
        tooltip: 'Assign category',
        onPressed: () {
          setState(() => isDropdownVisible = true);
        },
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: filtered.contains(selected) ? selected : null,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          dropdownColor: Colors.white,
          hint: const Text("Select", style: TextStyle(fontSize: 12)),
          items: filtered
              .map(
                (cat) => DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selected = value;
                isDropdownVisible = true;
              });
              widget.onChanged([value]);
            }
          },
        ),
      ),
    );
  }
}
