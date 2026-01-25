import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<UserModel>>(
          stream: firestoreService.getUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final users = snapshot.data!;
            return DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              minWidth: 600,
              columns: const [
                DataColumn2(label: Text('Name'), size: ColumnSize.L),
                DataColumn2(label: Text('Email'), size: ColumnSize.L),
                DataColumn2(label: Text('Role'), size: ColumnSize.S),
                DataColumn2(label: Text('Actions'), size: ColumnSize.S),
              ],
              rows: users.map((user) => DataRow(cells: [
                DataCell(Text(user.name)),
                DataCell(Text(user.email)),
                DataCell(Chip(label: Text(user.role))),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showUserDialog(context, user)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => firestoreService.deleteUser(user.uid)),
                  ],
                )),
              ])).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUserDialog(BuildContext context, UserModel? user) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final roleController = TextEditingController(text: user?.role ?? 'student');
    // Password could be handled here too if needed for creation

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user == null ? 'Add User' : 'Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            DropdownButtonFormField<String>(
              value: roleController.text,
              items: ['student', 'teacher', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => roleController.text = val!,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              final uid = user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(); // Simple ID gen for now if not using Auth
              
              // Note: Real Auth creation would go here, separate from Firestore
              
              final newUser = UserModel(
                uid: uid,
                email: emailController.text,
                name: nameController.text,
                role: roleController.text,
              );
              
              await firestoreService.saveUser(newUser);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
