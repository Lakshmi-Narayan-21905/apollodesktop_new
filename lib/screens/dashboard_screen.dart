import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import 'students_screen.dart';
import 'faculty_screen.dart';
import 'courses_screen.dart';
import 'attendance_screen.dart';
import 'reports_screen.dart';
import 'classroom_screen.dart';
import 'assignments_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Stream<List<UserModel>> _studentsStream;
  late Stream<List<CourseModel>> _coursesStream;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<FirestoreService>(context, listen: false);
    _studentsStream = service.getStudents();
    _coursesStream = service.getCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apollo Dashboard'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.school, size: 32, color: Colors.deepPurple)),
                  SizedBox(height: 16),
                  Text('Apollo Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('admin@apollo.com', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              selected: true,
              selectedColor: Colors.deepPurple,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Students'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Faculty'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Courses'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.class_outlined),
              title: const Text('Classroom'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassroomScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Assignments'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentsScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Attendance'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
             ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Reports'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {}, 
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 24),
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<UserModel>>(
                    stream: _studentsStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _StatCard(title: 'Total Students', value: count.toString(), icon: Icons.school, color: Colors.blue);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<List<CourseModel>>(
                    stream: _coursesStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _StatCard(title: 'Active Courses', value: count.toString(), icon: Icons.library_books, color: Colors.orange);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<List<CourseModel>>(
                    stream: _coursesStream,
                    builder: (context, courseSnapshot) {
                      return StreamBuilder<List<UserModel>>(
                        stream: _studentsStream,
                        builder: (context, studentSnapshot) {
                          double revenue = 0;
                          if (courseSnapshot.hasData && studentSnapshot.hasData) {
                             final courses = courseSnapshot.data!;
                             final students = studentSnapshot.data!;
                             
                             // Map course ID to fees for O(1) lookup
                             final courseFees = {for (var c in courses) c.id: c.fees};
                             
                             for (var student in students) {
                               for (var enrolledId in student.enrolledCourseIds) {
                                  revenue += courseFees[enrolledId] ?? 0;
                               }
                             }
                          }
                          return _StatCard(title: 'Revenue', value: '₹${revenue.toStringAsFixed(0)}', icon: Icons.currency_rupee, color: Colors.green);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Quick Actions
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _QuickActionButton(
                  icon: Icons.person_add,
                  label: 'Add Student',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsScreen())),
                ),
                 _QuickActionButton(
                  icon: Icons.person_add_alt_1,
                  label: 'Add Faculty',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyScreen())),
                ),
                _QuickActionButton(
                  icon: Icons.library_add,
                  label: 'Add Course',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoursesScreen())),
                ),
                _QuickActionButton(
                  icon: Icons.class_,
                  label: 'Classroom',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassroomScreen())),
                ),
                _QuickActionButton(
                  icon: Icons.assignment_add,
                  label: 'Assignments',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentsScreen())),
                ),
                _QuickActionButton(
                  icon: Icons.assignment_turned_in,
                  label: 'Mark Attendance',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
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
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple)),
          ],
        ),
      ),
    );
  }
}
