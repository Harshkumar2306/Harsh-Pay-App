import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'core/db/hive_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for offline-first architecture
  await HiveSetup.init();
  
  runApp(const HarshPayApp());
}

class HarshPayApp extends StatelessWidget {
  const HarshPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Harsh Pay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}