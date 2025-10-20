import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  // const FilterBar({
  //   super.key,
  //   required this.selectedCategory,
  //   required this.onCategoryChanged, required void Function(String query) onSearchChanged, required TextEditingController searchController,
  // });

  const FilterBar({
    super.key,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filterBackgroundColor =  Color.fromARGB(209, 255, 255, 255);

    return Row(
      children: [
        // Campo de Busca
        Expanded(
          child: TextField(
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou código...',
              hintStyle: TextStyle(color: Color.fromARGB(255, 44, 44, 44)),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              filled: true,
              fillColor: filterBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Dropdown de Categorias
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: filterBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: selectedCategory,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),

            borderRadius: BorderRadius.circular(8.0),
            dropdownColor: filterBackgroundColor,

            onChanged: onCategoryChanged,
            items: <String>['Todas as Categorias', 'Cabos', 'Relés', 'Conectores', 'EPIs', 'Ferramentas', 'Peças']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(color: Colors.black87)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}