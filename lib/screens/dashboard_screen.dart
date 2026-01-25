import 'package:flutter/material.dart';
import 'users_screen.dart';
import 'courses_screen.dart';
import 'attendance_screen.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apollo Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text('Apollo Admin', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Courses'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Attendance'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reports'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Stats Row
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCard(title: 'Total Students', value: '0'), // Placeholder
                _StatCard(title: 'Courses', value: '0'), // Placeholder
                _StatCard(title: 'Today Attendance', value: '0%'), // Placeholder
              ],
            ),
            const SizedBox(height: 32),
            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())), 
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Student') // Ideally opens a dialog directly, but screen for now
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesScreen())), 
                  icon: const Icon(Icons.library_add),
                  label: const Text('Add Course')
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())), 
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Attendance')
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
