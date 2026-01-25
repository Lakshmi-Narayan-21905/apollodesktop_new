import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/course_model.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? startDate;
  DateTime? endDate;
  CourseModel? selectedCourse;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, 1, 1); // Default to start of current year
    endDate = now;
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: (startDate != null && endDate != null)
                    ? DateTimeRange(start: startDate!, end: endDate!)
                    : null,
              );
              if (picked != null) {
                setState(() {
                  startDate = picked.start;
                  endDate = picked.end;
                });
              }
            },
            tooltip: 'Filter by Date Range',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: firestoreService.getCourses(),
        builder: (context, courseSnapshot) {
          return StreamBuilder<List<UserModel>>(
            stream: firestoreService.getStudents(),
            builder: (context, studentSnapshot) {
              return StreamBuilder<List<UserModel>>(
                stream: firestoreService.getFaculty(),
                builder: (context, facultySnapshot) {
                  if (!courseSnapshot.hasData || !studentSnapshot.hasData || !facultySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allCourses = courseSnapshot.data!;
                  final allStudents = studentSnapshot.data!;
                  final allFaculty = facultySnapshot.data!;

                  // ---------------- FILTERS ----------------
                  // Filter Courses
                  var filteredCourses = allCourses;
                  if (selectedCourse != null) {
                    filteredCourses = allCourses.where((c) => c.id == selectedCourse!.id).toList();
                  }
                  // Further filter courses by creation date if needed (optional based on requirements, lets keep courses global typically)

                  // Filter Students by Admission Date
                  var filteredStudents = allStudents;
                  if (startDate != null && endDate != null) {
                    filteredStudents = allStudents.where((s) {
                      if (s.dateOfAdmission == null) return false;
                      return s.dateOfAdmission!.isAfter(startDate!) && s.dateOfAdmission!.isBefore(endDate!.add(const Duration(days: 1)));
                    }).toList();
                  }

                  // ---------------- CALCULATIONS ----------------
                  
                  // KPI 1: Total Students (Filtered)
                  final totalStudents = filteredStudents.length;

                  // KPI 2: Total Courses (Global/Filtered)
                  final totalCourses = filteredCourses.length;

                  // KPI 3: Total Faculty
                  final totalFaculty = allFaculty.length;

                  // KPI 4: Total Revenue
                  // Logic: Sum of fees for every filtered student's enrolled courses
                  // Constraint: Only count courses that are in 'filteredCourses' list (if course filter selected)
                  double totalRevenue = 0;
                  final courseMap = {for (var c in allCourses) c.id: c};
                  final filteredCourseIds = filteredCourses.map((c) => c.id).toSet();

                  for (var student in filteredStudents) {
                    for (var courseId in student.enrolledCourseIds) {
                       if (filteredCourseIds.contains(courseId) && courseMap.containsKey(courseId)) {
                         totalRevenue += courseMap[courseId]!.fees;
                       }
                    }
                  }


                  // CHART 1: Course Enrollment (Bar) - Top 5
                  final courseEnrollmentMap = <String, int>{};
                  for (var course in filteredCourses) {
                    // Count filtered students enrolled in this course
                    int count = 0;
                     for (var student in filteredStudents) {
                       if (student.enrolledCourseIds.contains(course.id)) {
                         count++;
                       }
                     }
                    if (count > 0) courseEnrollmentMap[course.title] = count;
                  }
                  final sortedEnrollment = courseEnrollmentMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final topEnrollments = sortedEnrollment.take(5).toList();


                  // CHART 2: Course Revenue (Bar) - Top 5
                  final courseRevenueMap = <String, double>{};
                  for (var course in filteredCourses) {
                     // Revenue = filtered students * fee
                     int count = 0;
                     for (var student in filteredStudents) {
                       if (student.enrolledCourseIds.contains(course.id)) {
                         count++;
                       }
                     }
                     if (count > 0) courseRevenueMap[course.title] = count * course.fees;
                  }
                   final sortedRevenue = courseRevenueMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final topRevenue = sortedRevenue.take(5).toList();


                  // CHART 3: Student Admission Trend (Line)
                  // Group filtered students by Month/Year
                   final admissionTrendMap = <DateTime, int>{};
                   for (var student in filteredStudents) {
                     if (student.dateOfAdmission != null) {
                       final date = student.dateOfAdmission!;
                       final key = DateTime(date.year, date.month);
                       admissionTrendMap[key] = (admissionTrendMap[key] ?? 0) + 1;
                     }
                   }
                   final sortedAdmissionDates = admissionTrendMap.keys.toList()..sort();
                   

                  // CHART 4: Monthly Revenue Trend (Line)
                  final revenueTrendMap = <DateTime, double>{};
                  for (var student in filteredStudents) {
                     if (student.dateOfAdmission != null) {
                       final date = student.dateOfAdmission!;
                       final key = DateTime(date.year, date.month);
                       
                       double studentRevenue = 0;
                       for (var id in student.enrolledCourseIds) {
                         // Only if course is in filtered list
                         if (filteredCourseIds.contains(id) && courseMap.containsKey(id)) {
                            studentRevenue += courseMap[id]!.fees;
                         }
                       }
                       revenueTrendMap[key] = (revenueTrendMap[key] ?? 0) + studentRevenue;
                     }
                   }
                   final sortedRevenueDates = revenueTrendMap.keys.toList()..sort();

                  
                  // CHART 5: Faculty Workload (Bar/Table)
                  // Instructor Name vs Students Handled (Sum of students in their courses)
                  final facultyWorkload = <String, int>{};
                  for (var course in filteredCourses) {
                     if (course.instructor.isNotEmpty) {
                       // Count filtered students in this course
                        int count = 0;
                         for (var student in filteredStudents) {
                           if (student.enrolledCourseIds.contains(course.id)) {
                             count++;
                           }
                         }
                       facultyWorkload[course.instructor] = (facultyWorkload[course.instructor] ?? 0) + count;
                     }
                  }
                   final sortedFaculty = facultyWorkload.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final topFaculty = sortedFaculty.take(5).toList();

                  // ---------------- UI ----------------
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Control Bar
                        Row(
                          children: [
                            Text(
                              (startDate != null && endDate != null)
                                  ? '${DateFormat('MMM yyyy').format(startDate!)} - ${DateFormat('MMM yyyy').format(endDate!)}'
                                  : 'All Time',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 300,
                              child: DropdownButtonFormField<CourseModel>(
                                value: selectedCourse,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by Course',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<CourseModel>(value: null, child: Text('All Courses')),
                                  ...allCourses.map((c) => DropdownMenuItem(value: c, child: Text(c.title))),
                                ],
                                onChanged: (val) => setState(() => selectedCourse = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // KPIs
                        Row(
                          children: [
                            Expanded(child: _MetricCard(title: 'Total Students', value: '$totalStudents', icon: Icons.school, color: Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _MetricCard(title: 'Total Courses', value: '$totalCourses', icon: Icons.library_books, color: Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(child: _MetricCard(title: 'Total Faculty', value: '$totalFaculty', icon: Icons.person_4, color: Colors.purple)),
                            const SizedBox(width: 16),
                            Expanded(child: _MetricCard(title: 'Total Revenue', value: '₹${NumberFormat.compact().format(totalRevenue)}', icon: Icons.currency_rupee, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // FIRST ROW CHARTS: Enrollements & Revenue
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ChartContainer(
                                title: 'Course Enrollment (Top 5)',
                                child: topEnrollments.isEmpty 
                                  ? const Center(child: Text('No Data')) 
                                  : BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: (topEnrollments.first.value.toDouble()) * 1.2,
                                      titlesData: _getBarTitles(topEnrollments.map((e) => e.key).toList()),
                                      borderData: FlBorderData(show: false),
                                      gridData: FlGridData(show: false),
                                      barGroups: topEnrollments.asMap().entries.map((e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: Colors.blueAccent, width: 20, borderRadius: BorderRadius.circular(4))],
                                      )).toList(),
                                    ),
                                  ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _ChartContainer(
                                title: 'Course Revenue (Top 5)',
                                child: topRevenue.isEmpty
                                ? const Center(child: Text('No Data'))
                                : BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: (topRevenue.first.value.toDouble()) * 1.2,
                                      titlesData: _getBarTitles(topRevenue.map((e) => e.key).toList()),
                                      borderData: FlBorderData(show: false),
                                      gridData: FlGridData(show: false),
                                      barGroups: topRevenue.asMap().entries.map((e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: Colors.green, width: 20, borderRadius: BorderRadius.circular(4))],
                                      )).toList(),
                                    ),
                                  ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // SECOND ROW CHARTS: Trends
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                               child: _ChartContainer(
                                title: 'Student Admission Trend',
                                child: sortedAdmissionDates.isEmpty
                                ? const Center(child: Text('No Data'))
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(show: true, drawVerticalLine: false),
                                      titlesData: _getLineTitles(sortedAdmissionDates),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: sortedAdmissionDates.asMap().entries.map((e) {
                                            return FlSpot(e.key.toDouble(), admissionTrendMap[e.value]!.toDouble());
                                          }).toList(),
                                          isCurved: true,
                                          color: Colors.blue,
                                          barWidth: 3,
                                          dotData: FlDotData(show: true),
                                          belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                                        ),
                                      ],
                                    ),
                                  ),
                               ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                               child: _ChartContainer(
                                title: 'Monthly Revenue Trend',
                                child: sortedRevenueDates.isEmpty
                                ? const Center(child: Text('No Data'))
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(show: true, drawVerticalLine: false),
                                      titlesData: _getLineTitles(sortedRevenueDates),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: sortedRevenueDates.asMap().entries.map((e) {
                                            return FlSpot(e.key.toDouble(), revenueTrendMap[e.value]!.toDouble());
                                          }).toList(),
                                          isCurved: true,
                                          color: Colors.green,
                                          barWidth: 3,
                                          dotData: FlDotData(show: true),
                                          belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                                        ),
                                      ],
                                    ),
                                  ),
                               ),
                            ),
                          ],
                        ),
                         const SizedBox(height: 24),

                         // THIRD ROW: Faculty Workload
                         _ChartContainer(
                           title: 'Faculty Workload',
                           height: 250, // Slightly simpler height
                           child: topFaculty.isEmpty
                           ? const Center(child: Text('No Data'))
                           : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceEvenly,
                                maxY: (topFaculty.first.value.toDouble()) * 1.2,
                                titlesData: _getBarTitles(topFaculty.map((e) => e.key).toList()),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false), // Clean look
                                barGroups: topFaculty.asMap().entries.map((e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: Colors.purple, width: 40, borderRadius: BorderRadius.circular(4))],
                                )).toList(),
                              ),
                            ),
                         ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Helper for Bar Chart Titles
  FlTitlesData _getBarTitles(List<String> labels) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
             if (value.toInt() >= 0 && value.toInt() < labels.length) {
               return Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(labels[value.toInt()].split(' ').first, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
               );
             }
             return const Text('');
          },
          reservedSize: 30,
        ),
      ),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Clean no-axis look
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // Helper for Line Chart Titles
  FlTitlesData _getLineTitles(List<DateTime> dates) {
     return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
             if (value.toInt() >= 0 && value.toInt() < dates.length) {
               // Show every other label to avoid crowding
               if (value.toInt() % 2 != 0 && dates.length > 5) return const Text(''); 
               return Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(DateFormat('MMM').format(dates[value.toInt()]), style: const TextStyle(fontSize: 10)),
               );
             }
             return const Text('');
          },
          reservedSize: 30,
        ),
      ),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const _ChartContainer({required this.title, required this.child, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _ReportCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      ),
    );
  }

}
