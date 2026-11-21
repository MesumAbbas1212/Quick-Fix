import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_catalog_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminCatalogScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AdminCatalogService? catalogService;
  const AdminCatalogScreen({super.key, required this.user, this.authService, this.catalogService});
  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  late final AdminCatalogService _service = widget.catalogService ?? AdminCatalogService();
  bool _languages = false;
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: SegmentedButton<bool>(key: const Key('admin-catalog-segment'),
      segments: const [ButtonSegment(value: false, label: Text('Categories')), ButtonSegment(value: true, label: Text('Languages'))], selected: {_languages}, onSelectionChanged: (value) => setState(() => _languages = value.first))),
    Expanded(child: _languages ? _languageList() : _categoryList()),
    Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: ElevatedButton.icon(key: const Key('admin-catalog-add'), onPressed: () => _languages ? _addLanguage() : _editCategory(), icon: const Icon(Icons.add), label: Text(_languages ? 'Add language' : 'Add category'))),
  ]);

  Widget _categoryList() => StreamBuilder<List<ServiceCategory>>(stream: _service.watchCategories(), builder: (context, snapshot) {
    if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
    if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 5);
    final categories = snapshot.data ?? const <ServiceCategory>[];
    if (categories.isEmpty) return const AdminEmpty(title: 'No categories', message: 'Add a valid JobCategory to make it available for jobs.');
    return ListView(padding: const EdgeInsets.all(14), children: categories.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AdminCard(child: ListTile(
      key: Key('admin-category-${item.id}'), leading: const Icon(Icons.category_outlined, color: AppTheme.brandBlue),
      title: Text(item.name), subtitle: Text(item.isActive ? 'Active · ${item.category.name}' : 'Inactive · ${item.category.name}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Rename category', onPressed: () => _editCategory(item), icon: const Icon(Icons.edit_outlined)), Switch(value: item.isActive, onChanged: (active) => _setCategoryActive(item, active))]),
    )))).toList());
  });

  Widget _languageList() => StreamBuilder<List<AppLanguage>>(stream: _service.watchLanguages(), builder: (context, snapshot) {
    if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
    if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 5);
    final languages = snapshot.data ?? const <AppLanguage>[];
    if (languages.isEmpty) return const AdminEmpty(title: 'No languages', message: 'Add a BCP-47 language code. Existing preferred languages are never deleted.');
    return ListView(padding: const EdgeInsets.all(14), children: languages.map((language) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AdminCard(child: SwitchListTile(
      key: Key('admin-language-${language.code}'), contentPadding: EdgeInsets.zero, value: language.isActive,
      title: Text('${language.nativeName} · ${language.englishName}'), subtitle: Text(language.code),
      onChanged: (active) => _setLanguageActive(language, active),
    )))).toList());
  });

  Future<void> _setCategoryActive(ServiceCategory category, bool active) async {
    final action = active ? 'Activate' : 'Deactivate';
    final confirmed = await _confirm('$action ${category.name}?', active ? 'This category will become selectable for new jobs.' : 'This category will no longer be selectable for new jobs.');
    if (confirmed != true) return;
    try { await _service.setCategoryActive(category.id, active); } catch (error) { _showError(error); }
  }

  Future<void> _setLanguageActive(AppLanguage language, bool active) async {
    final action = active ? 'Activate' : 'Deactivate';
    final confirmed = await _confirm('$action ${language.englishName}?', active ? 'This language will become available for future preferences.' : 'Existing preferredLanguage values stay valid, but this option will no longer be offered.');
    if (confirmed != true) return;
    try { await _service.setLanguageActive(language.code, active); } catch (error) { _showError(error); }
  }

  Future<void> _editCategory([ServiceCategory? existing]) async {
    var categoryName = existing?.category.name ?? '';
    var iconValue = existing?.iconPath ?? '';
    var isActive = existing?.isActive ?? true;
    String? error;
    final result = await showDialog<({String name, String icon, bool active})>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text(existing == null ? 'Add category' : 'Edit category'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(key: const Key('admin-category-name'), initialValue: categoryName, onChanged: (value) => categoryName = value, decoration: const InputDecoration(labelText: 'JobCategory value', hintText: 'applianceRepair')),
        TextFormField(initialValue: iconValue, onChanged: (value) => iconValue = value, decoration: const InputDecoration(labelText: 'Icon identifier (optional)')),
        SwitchListTile(value: isActive, title: const Text('Active'), onChanged: (value) => setDialog(() => isActive = value)),
        if (error != null) Text(error!, style: const TextStyle(color: AppTheme.dangerRed)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), ElevatedButton(key: const Key('admin-category-save'), onPressed: () {
        final value = categoryName.trim();
        if (!const {'cleaning','plumbing','electrical','carpentry','painting','gardening','moving','applianceRepair','tutoring','beauty','other'}.contains(value)) { setDialog(() => error = 'Use one of the exact JobCategory enum values.'); return; }
        Navigator.pop(dialogContext, (name: value, icon: iconValue, active: isActive));
      }, child: const Text('Save'))],
    )));
    if (result == null) return;
    try {
      if (existing != null && existing.category.name != result.name) {
        final affected = await _service.jobCountForCategory(existing.category.name);
        final warning = affected > 0
            ? '$affected jobs reference ${existing.category.name}. Historical jobs will keep the old value and will not be rewritten.'
            : 'The existing category ID will be replaced. This does not rewrite historical job values.';
        if (await _confirm('Rename category?', warning) != true) return;
        await _service.renameCategory(from: existing.category.name, to: result.name);
      }
      await _service.saveCategory(name: result.name, icon: result.icon, isActive: result.active);
    } catch (error) { _showError(error); }
  }

  Future<void> _addLanguage() async {
    var codeValue = '';
    var nativeValue = '';
    var englishValue = '';
    String? error;
    final result = await showDialog<({String code, String native, String english})>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Add language'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('admin-language-code'), onChanged: (value) => codeValue = value, decoration: const InputDecoration(labelText: 'BCP-47 code', hintText: 'en or pt-BR')),
        TextField(onChanged: (value) => nativeValue = value, decoration: const InputDecoration(labelText: 'Native name')),
        TextField(onChanged: (value) => englishValue = value, decoration: const InputDecoration(labelText: 'English name')),
        if (error != null) Text(error!, style: const TextStyle(color: AppTheme.dangerRed)),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), ElevatedButton(key: const Key('admin-language-save'), onPressed: () {
        if (!RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$').hasMatch(codeValue.trim())) { setDialog(() => error = 'Use a BCP-47 code such as en or pt-BR.'); return; }
        if (nativeValue.trim().isEmpty || englishValue.trim().isEmpty) { setDialog(() => error = 'Enter both language names.'); return; }
        Navigator.pop(dialogContext, (code: codeValue.trim(), native: nativeValue, english: englishValue));
      }, child: const Text('Save'))],
    )));
    if (result == null) return;
    try { await _service.saveLanguage(code: result.code, nativeName: result.native, englishName: result.english); } catch (error) { _showError(error); }
  }

  Future<bool?> _confirm(String title, String consequence) => showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(consequence), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))]));
  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
}
