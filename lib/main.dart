import 'dart:io'; // For platform checking
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import sqflite_common_ffi for desktop

// Define the ToDo model class
class ToDo {
  int? id;
  String task;
  bool isDone;

  ToDo({
    this.id,
    required this.task,
    this.isDone = false,
  });

  // Convert a ToDo object into a Map object for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task': task,
      'isDone': isDone ? 1 : 0, // Store as 1 for true and 0 for false
    };
  }

  // Convert a Map object into a ToDo object
  factory ToDo.fromMap(Map<String, dynamic> map) {
    return ToDo(
      id: map['id'],
      task: map['task'],
      isDone: map['isDone'] == 1,
    );
  }
}

// SQLite helper class for database interaction
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!; // If the database already exists, return it
    _database = await _initDB(); // Otherwise, initialize the database
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDB() async {
    // Initialize the database for desktop
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi; // Set the database factory to FFI for desktop
    }

    // Get the default database path and create the database
    String path = join(await getDatabasesPath(), 'todo.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // Create the ToDo table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE todos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task TEXT,
        isDone INTEGER
      )
    ''');
  }

  // Insert a new ToDo
  Future<int> insertToDo(ToDo todo) async {
    final db = await database;
    return await db.insert('todos', todo.toMap());
  }

  // Get all ToDos
  Future<List<ToDo>> getAllToDos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('todos');
    return List.generate(maps.length, (i) {
      return ToDo.fromMap(maps[i]);
    });
  }

  // Update a ToDo (mark as done/undone)
  Future<int> updateToDo(ToDo todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // Delete a ToDo
  Future<int> deleteToDo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ToDoListScreen(),
    );
  }
}

class ToDoListScreen extends StatefulWidget {
  const ToDoListScreen({super.key});

  @override
  _ToDoListScreenState createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ToDo> _todos = [];
  String _dbPath = '';

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  // Load todos from the database
  Future<void> _loadTodos() async {
    final todos = await DatabaseHelper().getAllToDos();
    final dbPath = await getDatabasesPath();
    setState(() {
      _todos = todos;
      _dbPath = dbPath; // Set the database path to display
    });
  }

  // Add a new ToDo
  Future<void> _addTodo() async {
    if (_controller.text.isEmpty) return;
    final newToDo = ToDo(
      task: _controller.text,
    );
    await DatabaseHelper().insertToDo(newToDo);
    _controller.clear();
    _loadTodos();
  }

  // Toggle a ToDo's completion status
  Future<void> _toggleToDoCompletion(ToDo todo) async {
    todo.isDone = !todo.isDone;
    await DatabaseHelper().updateToDo(todo);
    _loadTodos();
  }

  // Delete a ToDo
  Future<void> _deleteToDo(int id) async {
    await DatabaseHelper().deleteToDo(id);
    _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Database Path: $_dbPath',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _addTodo,
              child: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  final todo = _todos[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        todo.task,
                        style: TextStyle(
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          fontSize: 16,
                          color: todo.isDone ? Colors.grey : Colors.black,
                        ),
                      ),
                      leading: IconButton(
                        icon: Icon(
                          todo.isDone ? Icons.check_box : Icons.check_box_outline_blank,
                          color: todo.isDone ? Colors.green : Colors.blue,
                        ),
                        onPressed: () => _toggleToDoCompletion(todo),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteToDo(todo.id!),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
