import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/course_model.dart'; // Will create
import '../models/attendance_model.dart'; // Will create

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Students
  Future<void> saveStudent(UserModel user) async {
    await _db.collection('students').doc(user.uid).set(user.toMap());
  }

  Stream<List<UserModel>> getStudents() {
    return _db.collection('students').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> deleteStudent(String uid) async {
    await _db.collection('students').doc(uid).delete();
  }

  // Faculty
  Future<void> saveFaculty(UserModel user) async {
    await _db.collection('faculty').doc(user.uid).set(user.toMap());
  }

  Stream<List<UserModel>> getFaculty() {
    return _db.collection('faculty').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> deleteFaculty(String uid) async {
    await _db.collection('faculty').doc(uid).delete();
  }

  // Legacy/Generic Users (Optional: keeping strict role-based fetching or helper)
  // For 'getUsers' generic calls, we might now need to fetch from both or deprecate it.
  // For now, I will keep 'getUsers' fetching from 'users' collection to not break other things immediately if any,
  // BUT the screens requested will use the new methods.
  // Actually, to fully migrate, we should probably stop writing to 'users'.
  
  // Helper for attendance which relied on 'users' collection before?
  // getStudentsByIds needs update to look in 'students' collection.
  Future<List<UserModel>> getStudentsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    if (ids.length <= 10) {
      final snapshot = await _db.collection('students').where(FieldPath.documentId, whereIn: ids).get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    } else {
        final snapshot = await _db.collection('students').get(); 
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).where((u) => ids.contains(u.uid)).toList();
    }
  }

  // Attendance
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

  // General Daily Attendance (No Course Filter)
   Stream<List<AttendanceModel>> getDailyAttendance(DateTime date) {
     final start = DateTime(date.year, date.month, date.day);
     final end = start.add(const Duration(days: 1));
     
     return _db.collection('attendance')
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
  


  Future<void> updateCourseEnrollments(String studentId, List<String> oldCourseIds, List<String> newCourseIds) async {
    // 1. Find courses to ADD student to
    final coursesToAdd = newCourseIds.where((id) => !oldCourseIds.contains(id)).toList();
    
    // 2. Find courses to REMOVE student from
    final coursesToRemove = oldCourseIds.where((id) => !newCourseIds.contains(id)).toList();

    final batch = _db.batch();

    for (var courseId in coursesToAdd) {
      final docRef = _db.collection('courses').doc(courseId);
      batch.update(docRef, {
        'studentIds': FieldValue.arrayUnion([studentId])
      });
    }

    for (var courseId in coursesToRemove) {
      final docRef = _db.collection('courses').doc(courseId);
      batch.update(docRef, {
        'studentIds': FieldValue.arrayRemove([studentId])
      });
    }

    await batch.commit();
  }

  // Storage Methods Let's add material logic
  Future<String> uploadCourseMaterial(String courseId, String fileName, {File? file, Uint8List? bytes}) async {
    final ref = _storage.ref().child('courses/$courseId/materials/$fileName');
    if (file != null) {
       await ref.putFile(file);
    } else if (bytes != null) {
       // For web support where path handles aren't valid
       await ref.putData(bytes);
    } else {
       throw Exception("Must provide either a file or bytes");
    }
    return await ref.getDownloadURL();
  }

  Future<void> deleteCourseMaterial(String courseId, String fileName) async {
    try {
      final ref = _storage.ref().child('courses/$courseId/materials/$fileName');
      await ref.delete();
    } catch (_) {
      // Ignored if not found
    }
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
}
