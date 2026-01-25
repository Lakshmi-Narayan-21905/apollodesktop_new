import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/course_model.dart'; // Will create
import '../models/attendance_model.dart'; // Will create

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Users
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Stream<List<UserModel>> getUsers() {
    return _db.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<List<UserModel>> getStudentsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Ideally use whereIn, but for simplicity/limitations, we can fetch all or use whereIn chunks.
    // Optimization: fetch only needed.
    // For < 10 ids:
    if (ids.length <= 10) {
      final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: ids).get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    } else {
        // Fallback: fetch all and filter (not scalable but works for prototype)
        // Or chunk it. Let's just fetch all users for now if list is huge, or just fetch all 'student' role.
        final snapshot = await _db.collection('users').get(); // potentially expensive
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).where((u) => ids.contains(u.uid)).toList();
    }
  }

  // Attendance
   Stream<List<AttendanceModel>> getAttendance(String courseId, DateTime date) {
     // Start of day
     final start = DateTime(date.year, date.month, date.day);
     final end = start.add(const Duration(days: 1));
     
     return _db.collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data(), doc.id)).toList());
  }
  
  Stream<List<AttendanceModel>> getCourseAttendance(String courseId) {
     return _db.collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> saveAttendance(AttendanceModel attendance) async {
    if (attendance.id.isEmpty) {
        await _db.collection('attendance').add(attendance.toMap());
    } else {
        await _db.collection('attendance').doc(attendance.id).set(attendance.toMap(), SetOptions(merge: true));
    }
  }

  // Courses
  Future<void> saveCourse(CourseModel course) async {
    await _db.collection('courses').doc(course.id).set(course.toMap());
  }

  Future<void> deleteCourse(String id) async {
    await _db.collection('courses').doc(id).delete();
  }

  Stream<List<CourseModel>> getCourses() {
     return _db.collection('courses').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CourseModel.fromMap(doc.data(), doc.id)).toList());
  }
  


  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
}
