import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String text;
  final List<String> options;
  final int correctOptionIndex;

  QuestionModel({
    required this.text,
    required this.options,
    required this.correctOptionIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      text: map['text'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex']?.toInt() ?? 0,
    );
  }
}

class AssignmentModel {
  final String id;
  final String courseId;
  final String title;
  final DateTime createdAt;
  final List<QuestionModel> questions;

  AssignmentModel({
    required this.id,
    required this.courseId,
    required this.title,
    required this.createdAt,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'questions': questions.map((x) => x.toMap()).toList(),
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentModel(
      id: id,
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      questions: List<QuestionModel>.from((map['questions'] as List? ?? []).map((x) => QuestionModel.fromMap(x))),
    );
  }
}
