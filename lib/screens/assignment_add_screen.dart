import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/assignment_model.dart';
import '../models/course_model.dart';
import '../services/firestore_service.dart';

class AssignmentAddScreen extends StatefulWidget {
  final AssignmentModel? assignment;

  const AssignmentAddScreen({super.key, this.assignment});

  @override
  State<AssignmentAddScreen> createState() => _AssignmentAddScreenState();
}

class _AssignmentAddScreenState extends State<AssignmentAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  String? _selectedCourseId;
  List<QuestionData> _questions = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!.title;
      _selectedCourseId = widget.assignment!.courseId;
      for (var q in widget.assignment!.questions) {
        final qData = QuestionData();
        qData.textController.text = q.text;
        qData.correctIndex = q.correctOptionIndex;
        qData.optionControllers = q.options.map((opt) {
          final ctrl = TextEditingController();
          ctrl.text = opt;
          return ctrl;
        }).toList();
        _questions.add(qData);
      }
    } else {
      _questions.add(QuestionData());
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(QuestionData());
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a course')));
      return;
    }

    // Validate that all questions have non-empty text and options
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Question ${i + 1} text is empty')));
        return;
      }
      for (int j = 0; j < q.optionControllers.length; j++) {
        if (q.optionControllers[j].text.trim().isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Question ${i + 1}, Option ${j + 1} is empty')));
           return;
        }
      }
    }

    setState(() => _isSaving = true);
    
    try {
       final service = Provider.of<FirestoreService>(context, listen: false);
       final id = widget.assignment?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

       final questionsList = _questions.map((q) => QuestionModel(
         text: q.textController.text.trim(),
         options: q.optionControllers.map((c) => c.text.trim()).toList(),
         correctOptionIndex: q.correctIndex,
       )).toList();

       final assignment = AssignmentModel(
         id: id,
         courseId: _selectedCourseId!,
         title: _titleController.text.trim(),
         createdAt: widget.assignment?.createdAt ?? DateTime.now(),
         questions: questionsList,
       );

       await service.saveAssignment(assignment);
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.assignment == null ? 'Assignment added successfully' : 'Assignment updated successfully')));
         Navigator.pop(context);
       }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
         setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment == null ? 'Add Assignment' : 'Edit Assignment'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: service.getCourses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final courses = snapshot.data!;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Course *',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCourseId,
                    items: courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                    validator: (v) => v == null ? 'Please select a course' : null,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 32),
                  const Text('Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 16),
                  
                  ..._questions.asMap().entries.map((entry) {
                     int index = entry.key;
                     QuestionData q = entry.value;
                     return Card(
                       margin: const EdgeInsets.only(bottom: 24),
                       elevation: 3,
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                 if (_questions.length > 1)
                                   IconButton(
                                     icon: const Icon(Icons.delete, color: Colors.red),
                                     onPressed: () => _removeQuestion(index),
                                     tooltip: 'Remove Question',
                                   )
                               ],
                             ),
                             const SizedBox(height: 16),
                             TextFormField(
                               controller: q.textController,
                               decoration: const InputDecoration(
                                 labelText: 'Enter Question Text *',
                                 border: OutlineInputBorder(),
                               ),
                             ),
                             const SizedBox(height: 16),
                             const Text('Options & Correct Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                             const SizedBox(height: 8),
                             ...q.optionControllers.asMap().entries.map((optEntry) {
                                int optIndex = optEntry.key;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Radio<int>(
                                        value: optIndex,
                                        groupValue: q.correctIndex,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          setState(() => q.correctIndex = val!);
                                        },
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: optEntry.value,
                                          decoration: InputDecoration(
                                            labelText: 'Option ${optIndex + 1}',
                                            border: const OutlineInputBorder(),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                                          ),
                                        ),
                                      ),
                                      if (q.optionControllers.length > 2)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.deepOrange),
                                          onPressed: () {
                                            setState(() {
                                               q.optionControllers.removeAt(optIndex);
                                               if (q.correctIndex >= q.optionControllers.length) {
                                                 q.correctIndex = q.optionControllers.length - 1;
                                               }
                                            });
                                          },
                                        )
                                    ],
                                  ),
                                );
                             }).toList(),
                             TextButton.icon(
                               onPressed: q.optionControllers.length < 6 ? () {
                                 setState(() {
                                    q.optionControllers.add(TextEditingController());
                                 });
                               } : null, // Max 6 options for UI sanity
                               icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                               label: const Text('Add Option', style: TextStyle(color: Colors.deepPurple)),
                             ),
                           ],
                         ),
                       ),
                     );
                  }).toList(),
                  
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Question'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        side: const BorderSide(color: Colors.deepPurple, width: 2)
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
             padding: const EdgeInsets.symmetric(vertical: 16),
             backgroundColor: Colors.deepPurple,
             foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _saveAssignment,
          child: _isSaving
             ? const CircularProgressIndicator(color: Colors.white)
             : const Text('Save Assessment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// Helper class to hold temporary state for each question
class QuestionData {
  TextEditingController textController = TextEditingController();
  List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctIndex = 0;
}
