import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Отримуємо або генеруємо анонімний ID
  final prefs = await SharedPreferences.getInstance();
  String? anonymousUserId = prefs.getString('anonymous_user_id');
  if (anonymousUserId == null) {
    anonymousUserId = const Uuid().v4();
    await prefs.setString('anonymous_user_id', anonymousUserId);
  }

  // Ініціалізація Supabase
  await Supabase.initialize(
    url: 'https://wcczieoznbopcafdatpk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjY3ppZW96bmJvcGNhZmRhdHBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTU4OTg3NDgsImV4cCI6MjAxMTQ3NDc0OH0.GR35fGZMd98ZJyHxFJUQOvfNKJXbqZYTvN4r_cj_YyE',
    headers: {'x-anon-user-id': anonymousUserId},
    // інші опції, якщо були
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        // Замінено на Scaffold
        appBar: AppBar(title: const Text('Flutter App')), // Додано AppBar
        body: const Center(child: Text('Hello Flutter!')), // Додано Body
      ),
    );
  }
}
