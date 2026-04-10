import os
import re

main_dart_path = r"c:\Expense-Auditor\lib\main.dart"
screens_dir = r"c:\Expense-Auditor\lib\screens"

if not os.path.exists(screens_dir):
    os.makedirs(screens_dir)

with open(main_dart_path, 'r', encoding='utf-8') as f:
    content = f.read()

def extract_class(class_name, content):
    pattern = r'(class\s+' + class_name + r'\b.*?^})'
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""

# Extract parts
login_page = extract_class("LoginPage", content)
login_page_state = extract_class("_LoginPageState", content)
employee_dash = extract_class("EmployeeDashboard", content)
employee_dash_state = extract_class("_EmployeeDashboardState", content)
auditor_dash = extract_class("AuditorDashboard", content)
auditor_dash_state = extract_class("_AuditorDashboardState", content)
audit_detail = extract_class("AuditDetailView", content)

# Write login_page.dart
login_page_content = f"""import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'employee_dashboard.dart';
import 'auditor_dashboard.dart';

{login_page}

{login_page_state}
"""
with open(os.path.join(screens_dir, 'login_page.dart'), 'w', encoding='utf-8') as f:
    f.write(login_page_content)

# Write employee_dashboard.dart
employee_dashboard_content = f"""import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import '../policy_data.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

{employee_dash}

{employee_dash_state}
"""
with open(os.path.join(screens_dir, 'employee_dashboard.dart'), 'w', encoding='utf-8') as f:
    f.write(employee_dashboard_content)

# Write auditor_dashboard.dart
auditor_dashboard_content = f"""import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../components/sidebar.dart';
import '../components/header.dart';
import '../components/stats_card.dart';
import 'login_page.dart';

{auditor_dash}

{auditor_dash_state}

{audit_detail}
"""
with open(os.path.join(screens_dir, 'auditor_dashboard.dart'), 'w', encoding='utf-8') as f:
    f.write(auditor_dashboard_content)

# Write new main.dart
new_main = content[:re.search(r'// --- 1. LOGIN SCREEN ---', content).start()]
new_main_content = f"""import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/login_page.dart';

void main() async {{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}}

class MyApp extends StatelessWidget {{
  const MyApp({{super.key}});

  @override
  Widget build(BuildContext context) {{
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aetheris Expense Auditor',
      theme: AppTheme.darkTheme,
      home: const LoginPage(),
    );
  }}
}}
"""
with open(main_dart_path, 'w', encoding='utf-8') as f:
    f.write(new_main_content)

print("Split completed successfully!")
