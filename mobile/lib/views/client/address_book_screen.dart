import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/models/saved_address.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/location_picker_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

class AddressBookScreen extends StatefulWidget {
  final String userId;
  final bool selecting;
  final ProfileService? profileService;
  final LocationService? locationService;
  final UrlLauncher? urlLauncher;
  const AddressBookScreen({super.key, required this.userId, this.selecting = false, this.profileService, this.locationService, this.urlLauncher});
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}
class _AddressBookScreenState extends State<AddressBookScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Stream<List<SavedAddress>> _stream = _watch();
  bool _busy = false;
  Stream<List<SavedAddress>> _watch() { try { return _profiles.watchAddresses(widget.userId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  Future<void> _edit([SavedAddress? existing]) async {
    if (_busy) { return; }
    setState(() { _busy = true; });
    try {
      var label = existing?.label ?? '';
      final form = GlobalKey<FormState>();
      final selectedLabel = await showDialog<String>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text(existing == null ? 'Add an address' : 'Edit address'),
        content: SingleChildScrollView(child: Form(key: form, child: TextFormField(key: const Key('address-label'), initialValue: label, maxLength: 40,
          textDirection: contentDirection(label), decoration: const InputDecoration(labelText: 'Label', hintText: 'Home, office or a custom name'),
          onChanged: (value) => update(() { label = value; }), validator: (value) => value == null || value.trim().isEmpty ? 'Add a label.' : null))),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(key: const Key('address-label-next'), onPressed: () { if (form.currentState!.validate()) { Navigator.of(dialogContext).pop(label.trim()); } }, child: const Text('Choose pin'))],
      )));
      if (selectedLabel == null || !mounted) { return; }
      final selected = await Navigator.of(context).push<LocationSelection>(MaterialPageRoute(builder: (_) => LocationPickerScreen(
        initialLocation: existing?.location, initialAddress: existing?.address ?? '', locationService: widget.locationService, urlLauncher: widget.urlLauncher)));
      if (selected == null || !mounted) { return; }
      await _profiles.saveAddress(widget.userId, SavedAddress(id: existing?.id ?? '', label: selectedLabel, address: selected.address, location: selected.location));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved'))); }
    } catch (_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the address. Check your connection and retry.'))); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<void> _delete(SavedAddress address) async {
    if (_busy) { return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete saved address?'),
      content: Text(address.label, textDirection: contentDirection(address.label)), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')),
        TextButton(key: const Key('address-delete-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete'))]));
    if (confirmed != true || !mounted) { return; }
    setState(() { _busy = true; });
    try { await _profiles.deleteAddress(widget.userId, address.id); }
    catch (_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this address. Please retry.'))); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  void _use(SavedAddress address) {
    if (widget.selecting) { Navigator.of(context).pop(address); }
    else { Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostJobScreen(userId: widget.userId, initialLocation: address.selection, profileService: widget.profileService))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Address book'), actions: [IconButton(key: const Key('address-book-retry'), tooltip: 'Refresh saved addresses', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        const Text('Saved pins are private to your account and admins. A chosen pin is copied into a posted job only when you submit it.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 10), ElevatedButton.icon(key: const Key('address-book-add'), onPressed: _busy ? null : () => _edit(), icon: const Icon(Icons.add_location_alt_outlined), label: Text(_busy ? 'Address action in progress…' : 'Add address')),
      ])),
      Expanded(child: StreamBuilder<List<SavedAddress>>(stream: _stream, builder: (context, snapshot) {
        if (snapshot.hasError) { return ErrorState(message: 'Could not load your private address book. Reconnect and retry.', onRetry: _retry); }
        if (!snapshot.hasData) { return const SingleChildScrollView(child: LoadingList()); }
        final addresses = snapshot.data!;
        if (addresses.isEmpty) { return SingleChildScrollView(child: EmptyState(icon: Icons.location_on_outlined, title: 'No saved addresses yet', message: 'Save a location once and choose it for your next job.',
          action: OutlinedButton(key: const Key('address-book-first'), onPressed: _busy ? null : () => _edit(), child: const Text('Add your first address')))); }
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: addresses.length, itemBuilder: (context, index) {
          final address = addresses[index];
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(address.label, textDirection: contentDirection(address.label), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
            Text(address.address, textDirection: contentDirection(address.address), style: const TextStyle(fontSize: 13)), const SizedBox(height: 8),
            Text('${address.location.latitude.toStringAsFixed(5)}, ${address.location.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            Wrap(spacing: 8, children: [TextButton(key: Key('address-use-${address.id}'), onPressed: _busy ? null : () => _use(address), child: Text(widget.selecting ? 'Use this' : 'Use in a new job')),
              IconButton(key: Key('address-edit-${address.id}'), tooltip: 'Edit saved address', onPressed: _busy ? null : () => _edit(address), icon: const Icon(Icons.edit_outlined)),
              IconButton(key: Key('address-delete-${address.id}'), tooltip: 'Delete saved address', onPressed: _busy ? null : () => _delete(address), icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed))]),
          ])));
        });
      })),
    ])),
  );
}
