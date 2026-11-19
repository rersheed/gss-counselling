import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'inbox_screen.dart';
import 'manage_appointments_screen.dart';
import 'students_screen.dart';

class CounsellorShell extends StatefulWidget {
  const CounsellorShell({super.key});
  @override
  State<CounsellorShell> createState() => _CounsellorShellState();
}

class _CounsellorShellState extends State<CounsellorShell> {
  int _tab = 0;
  int _refresh = 0;

  void go(int tab) => setState(() {
        _tab = tab;
        _refresh++;
      });

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(key: ValueKey('dash$_refresh'), onGoTab: go),
      InboxScreen(key: ValueKey('inbox$_refresh')),
      ManageAppointmentsScreen(key: ValueKey('appts$_refresh')),
      const StudentsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: 'Sessions'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Students'),
        ],
      ),
    );
  }
}
