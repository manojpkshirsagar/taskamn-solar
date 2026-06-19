import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/label_category.dart';
import '../../models/label.dart';
import '../../constants/colors.dart';
import 'package:uuid/uuid.dart';

class AdminLabelsScreen extends StatefulWidget {
  const AdminLabelsScreen({super.key});

  @override
  State<AdminLabelsScreen> createState() => _AdminLabelsScreenState();
}

class _AdminLabelsScreenState extends State<AdminLabelsScreen> {
  List<LabelCategory> _categories = [];
  List<Label> _labels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await SupabaseService.instance.fetchLabelCategories();
    final lbs = await SupabaseService.instance.fetchLabels();
    if (mounted) {
      setState(() {
        _categories = cats;
        _labels = lbs;
        _isLoading = false;
      });
    }
  }

  void _showAddEditLabelDialog([Label? label]) {
    final translator = Provider.of<TranslationProvider>(context, listen: false);
    final nameController = TextEditingController(text: label?.labelName ?? '');
    String? selectedCategoryId = label?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(label == null ? 'Create Label' : 'Edit Label'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Label Name',
                        hintText: 'Enter label name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat.id,
                          child: Text(cat.categoryName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCategoryId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(translator.translate('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySolarOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || selectedCategoryId == null) {
                      return;
                    }

                    final newLabel = Label(
                      id: label?.id ?? const Uuid().v4(),
                      categoryId: selectedCategoryId!,
                      labelName: nameController.text.trim(),
                      isActive: label?.isActive ?? true,
                      createdAt: label?.createdAt ?? DateTime.now(),
                    );

                    await SupabaseService.instance.upsertLabel(newLabel);
                    if (context.mounted) Navigator.pop(context);
                    _loadData();
                  },
                  child: Text(translator.translate('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final translator = Provider.of<TranslationProvider>(context, listen: false);
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Category'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'Enter category name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(translator.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySolarOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final newCat = LabelCategory(
                  id: const Uuid().v4(),
                  categoryName: nameController.text.trim(),
                  createdAt: DateTime.now(),
                );

                await SupabaseService.instance.createLabelCategory(newCat);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: Text(translator.translate('save')),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(LabelCategory category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${category.categoryName}?'),
          content: const Text('Are you sure you want to delete this category? All labels in this category will also be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await SupabaseService.instance.deleteLabelCategory(category.id);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Labels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'category') {
                _showAddCategoryDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'category',
                child: Text('Create Category'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories or labels found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final categoryLabels = _labels
                        .where((l) => l.categoryId == category.id)
                        .toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySolarOrange.withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  category.categoryName.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                    color: AppColors.primarySolarOrange,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${categoryLabels.length} Labels',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLightGray,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                      onPressed: () => _confirmDeleteCategory(category),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (categoryLabels.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No labels in this category',
                                style: TextStyle(color: AppColors.textLightGray, fontSize: 13),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: categoryLabels.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final label = categoryLabels[idx];
                                return ListTile(
                                  title: Text(
                                    label.labelName,
                                    style: TextStyle(
                                      decoration: label.isActive
                                          ? TextDecoration.none
                                          : TextDecoration.lineThrough,
                                      color: label.isActive ? null : AppColors.textLightGray,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showAddEditLabelDialog(label),
                                      ),
                                      Switch(
                                        value: label.isActive,
                                        activeColor: AppColors.primarySolarOrange,
                                        onChanged: (val) async {
                                          final updated = Label(
                                            id: label.id,
                                            categoryId: label.categoryId,
                                            labelName: label.labelName,
                                            isActive: val,
                                            createdAt: label.createdAt,
                                          );
                                          await SupabaseService.instance.upsertLabel(updated);
                                          _loadData();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_labels_fab',
        backgroundColor: AppColors.primarySolarOrange,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditLabelDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
