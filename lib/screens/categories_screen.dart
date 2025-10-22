import 'package:fixitzed_app/services/home_service.dart';
import 'package:flutter/material.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final service = HomeService();
  List<dynamic> subcategories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  void loadCategories() async {
    try {
      final data = await service.fetchSubcategories();
      setState(() {
        subcategories = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subcategories')),
      body: isLoading
          ? const CategoriesSkeleton()
          : ListView.builder(
              itemCount: subcategories.length,
              itemBuilder: (context, index) {
                final category = subcategories[index] as Map? ?? {};
                return ListTile(
                  title: Text(
                    (category['name'] ?? category['title'] ?? 'Subcategory')
                        .toString(),
                  ),
                  subtitle: Text(
                    (category['description'] ?? '').toString(),
                  ),
                );
              },
            ),
    );
  }
}
