import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/login_page.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    print("Running without local .env file");
    // The app will now fallback to environment variables 
    // or system defaults instead of crashing.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aetheris Expense Auditor',
      theme: AppTheme.darkTheme,
      home: const LoginPage(),
    );
  }
}
