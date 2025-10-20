import 'package:fixitzed_app/services/category_service.dart';
import 'package:flutter/material.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final service = CategoryService();
  List<dynamic> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  void loadCategories() async {
    try {
      final data = await service.getCategories();
      setState(() {
        categories = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      body: isLoading
          ? const CategoriesSkeleton()
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  title: Text(category['name']),
                  subtitle: Text(category['description'] ?? ''),
                );
              },
            ),
    );
  }
}
