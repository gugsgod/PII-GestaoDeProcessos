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
    // A cor original (branco com transparência)
    const filterBackgroundColor = Color.fromARGB(209, 255, 255, 255);

    return Row(
      children: [
        // --- CAMPO DE BUSCA ---
        Expanded(
          child: SizedBox(
            height: 48, 
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                filled: true,
                fillColor: filterBackgroundColor,
                contentPadding: EdgeInsets.zero, // Centraliza o texto verticalmente
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // --- DROPDOWN DE CATEGORIA ---
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: filterBackgroundColor, // Cor restaurada
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true, // Isso estabiliza a largura do menu
              child: DropdownButton<String>(
                value: categories.contains(selectedCategory) ? selectedCategory : null,
                isExpanded: false, 
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                dropdownColor: filterBackgroundColor, // Cor do menu restaurada
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: onCategoryChanged,
                items: categories.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                // O selectedItemBuilder garante que o texto no botão seja renderizado corretamente
                selectedItemBuilder: (BuildContext context) {
                  return categories.map<Widget>((String value) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    );
                  }).toList();
                },
                hint: const Text("Filtrar", style: TextStyle(color: Colors.black54)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}