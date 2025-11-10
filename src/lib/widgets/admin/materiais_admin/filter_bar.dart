import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final List<String> categories;
  final String searchHint;

  const FilterBar({
    super.key,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.categories,
    this.searchHint = 'Buscar...',
  });

  @override
  Widget build(BuildContext context) {
    const filterBackgroundColor = Color.fromARGB(209, 255, 255, 255);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              filled: true,
              fillColor: filterBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 16),

        // Dropdown fixo com posição estável
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: filterBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: false,
              value: selectedCategory,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
              dropdownColor: filterBackgroundColor,
              onChanged: onCategoryChanged,
              items: categories.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(color: Colors.black87)),
                );
              }).toList(),
              menuMaxHeight: 250, // evita que o menu estoure a tela
              alignment: AlignmentDirectional.bottomStart, // 🔧 mantém o menu fixo
            ),
          ),
        ),
      ],
    );
  }
}
