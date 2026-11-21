import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_catalog_service.dart';
import 'package:quickfix/services/auth_service.dart';
class AdminCatalogScreen extends StatelessWidget {
  final UserModel user; final AuthService? authService; final AdminCatalogService? catalogService;
  const AdminCatalogScreen({super.key, required this.user, this.authService, this.catalogService});
  @override Widget build(BuildContext context) => const Center(child: Text('Catalog'));
}
