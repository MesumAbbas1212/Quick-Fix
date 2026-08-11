import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PostJobScreen extends StatefulWidget {
  final String? prefilledImageUrl;
  final JobCategory? suggestedCategory;
  final String? suggestedDescription;
  final String? suggestedAddress;
  final double? suggestedBudget;
  final String userId;
  final LocationService? locationService;
  final List<XFile>? prefilledImages;

  const PostJobScreen({
    super.key,
    this.prefilledImageUrl,
    this.suggestedCategory,
    this.suggestedDescription,
    this.suggestedAddress,
    this.suggestedBudget,
    this.userId = 'user-1',
    this.locationService,
    this.prefilledImages,
  });

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _budgetController = TextEditingController();
  
  JobCategory _selectedCategory = JobCategory.other;
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _preferredTime;
  final List<XFile> _images = [];
  bool _isLoading = false;

  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  @override
  void initState() {
    super.initState();
    if (widget.suggestedCategory != null) {
      _selectedCategory = widget.suggestedCategory!;
    }
    if (widget.suggestedDescription != null) {
      _descriptionController.text = widget.suggestedDescription!;
    }
    if (widget.suggestedAddress != null) {
      _addressController.text = widget.suggestedAddress!;
    }
    if (widget.suggestedBudget != null) {
      _budgetController.text = widget.suggestedBudget!.toStringAsFixed(0);
    }
    final prefilled = widget.prefilledImages;
    if (prefilled != null && prefilled.isNotEmpty) {
      _images.addAll(prefilled.take(5));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.take(5 - _images.length));
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.ctaOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.ctaOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredTime = picked);
  }

  Future<void> _handlePostJob() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to post a job. '
              'Please enable it in app settings and try again.',
            ),
          ),
        );
        return;
      }

      // Save picked photos to local app storage (Firebase Storage needs a
      // billing plan, so local paths are stored on the job record for now).
      final store = LocalImageStore();
      final localPaths = await store.saveImages([for (final x in _images) x]);

      final budget = double.tryParse(_budgetController.text.trim());
      if (budget == null) {
        throw Exception('Invalid budget');
      }

      await JobService().createJob(
        userId: widget.userId,
        title: _descriptionController.text.trim().split('\n').first,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        address: _addressController.text.trim(),
        location: location,
        budgetMin: budget,
        budgetMax: budget,
        preferredDate: _preferredDate,
        preferredTime: _preferredTime != null
            ? DateTime(_preferredDate.year, _preferredDate.month,
                _preferredDate.day, _preferredTime!.hour, _preferredTime!.minute)
            : null,
        images: localPaths,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: _PhoneFrame(child: _buildPhoneScreen()),
    );
  }

  Widget _buildPhoneScreen() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(38),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageContainer(),
                    const SizedBox(height: 14),
                    _buildFormCard(),
                    const SizedBox(height: 20),
                    _buildPostButton(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          const Text(
            'Post a Job',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer() {
    return Container(
      height: 176,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.borderGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: _images.isEmpty
          ? _buildImagePlaceholder()
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: _images.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(_images[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (_images.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _images.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == 0
                                ? AppTheme.ctaOrange
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      onPressed: _images.length < 5 ? _pickImages : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImagePlaceholder() {
    return InkWell(
      onTap: _pickImages,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo, color: AppTheme.brandBlue, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add Photos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Up to 5 images',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.suggestedCategory != null) ...[
            Row(
              children: [
                const Text(
                  'Suggested: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  _formatCategory(widget.suggestedCategory!),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _buildFormField(
            label: 'Description:',
            hint: 'Describe the job...',
            controller: _descriptionController,
            maxLines: 2,
            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          _buildFormField(
            label: 'Location:',
            hint: 'Enter address',
            controller: _addressController,
            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          _buildCategoryDropdown(),
          const SizedBox(height: 10),
          _buildDateTimeRow(),
          const SizedBox(height: 10),
          _buildBudgetField(),
        ],
      ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.bgLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<JobCategory>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.bgLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
          items: JobCategory.values.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(_formatCategory(cat), style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDateTimeField(
            label: 'Date',
            value: _formatDate(_preferredDate),
            onTap: _selectDate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDateTimeField(
            label: 'Time',
            value: _preferredTime?.format(context) ?? 'Optional',
            onTap: _selectTime,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: value == 'Optional'
                          ? AppTheme.textMuted
                          : AppTheme.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Budget: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const Text(
              'PKR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.brandBlue),
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
          decoration: InputDecoration(
            hintText: '2500',
            hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.bgLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePostJob,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.ctaOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          shadowColor: AppTheme.ctaOrange.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : const Text(
                'Post Job',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
      ),
    );
  }

  String _formatCategory(JobCategory cat) {
    return cat.name[0].toUpperCase() + cat.name.substring(1).replaceAll('_', ' ');
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 680,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: const Color(0xFF1E293B), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 112,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1B4B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 3,
            right: 3,
            bottom: 3,
            child: ClipRRect(borderRadius: BorderRadius.circular(38), child: child),
          ),
        ],
      ),
    );
  }
}