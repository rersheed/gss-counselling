import 'package:flutter/material.dart';

import 'my_cases_screen.dart';
import 'student_appointments_screen.dart';
import 'student_home.dart';
import 'tips_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _tab = 0;
  // Bumped to make tabs reload when something changes elsewhere.
  int _refresh = 0;

  void go(int tab) => setState(() {
        _tab = tab;
        _refresh++;
      });

  @override
  Widget build(BuildContext context) {
    final pages = [
      StudentHome(key: ValueKey('home$_refresh'), onGoTab: go),
      MyCasesScreen(key: ValueKey('cases$_refresh')),
      StudentAppointmentsScreen(key: ValueKey('appts$_refresh')),
      const TipsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: 'Sessions'),
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline_rounded), selectedIcon: Icon(Icons.lightbulb_rounded), label: 'Tips'),
        ],
      ),
    );
  }
}
