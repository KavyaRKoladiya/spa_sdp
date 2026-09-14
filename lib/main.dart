import 'package:flutter/material.dart';
import 'screens/index_page.dart';

void main() {
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          secondary: const Color(0xFF50E3C2),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default font family
      ),
      // Define a custom initial route mapping to support pushing back to root from Drawer
      initialRoute: '/',
      routes: {
        '/': (context) => const IndexPage(),
      },
    );
  }
}
