// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';



class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class NotificationService { // notification stuff and setup
  static Future<void> scheduleNotification(String title, DateTime time) async {
    final androidDetails = AndroidNotificationDetails(
      'letter_channel_id',
      'Letter Notifications',
      channelDescription: 'Notifications for unlocked letters 💌',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      time.millisecondsSinceEpoch.remainder(100000),
      title,
      'Your letter is ready to open 💌',
      tz.TZDateTime.from(time, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}

class Letter {
  final String? id; // firestore document ID
  final String userId; // ID of the user who owns this letter
  final String title;
  final String message;
  final DateTime unlockDate;
  final String? imageUrl; // if time permits: for image attachments haha

  Letter({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.unlockDate,
    this.imageUrl,
  });

  // convert a Letter object into a Map for firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'unlockDate': Timestamp.fromDate(unlockDate),
      'imageUrl': imageUrl,
    };
  }

  factory Letter.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Letter(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      unlockDate: (data['unlockDate'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

class LetterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // adding a new letter
  Future<void> addLetter(Letter letter) async {
    await _firestore.collection('letters').add(letter.toJson());
  }

  // ordered by unlockDate
  Stream<List<Letter>> getLettersForUser(String userId) {
    return _firestore
        .collection('letters')
        .where('userId', isEqualTo: userId)
        .orderBy('unlockDate', descending: false)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Letter.fromFirestore(doc)).toList());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();

  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initSettings =
  InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: ToYouFromMeApp(),
    ),
  );
}

class ToYouFromMeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To You, From Me',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.purple, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService._auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {

          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // User is logged in
          return HomeScreen();
        } else {
          // User is not logged in
          return AuthScreen();
        }
      },
    );
  }
}

// --- auth Screens ---
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLogin = true;
  String? _errorMessage;

  void _submitAuthForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    User? user;

    try {
      if (_isLogin) {
        user = await authService.signInWithEmailAndPassword(_email, _password);
      } else {
        user =
        await authService.registerWithEmailAndPassword(_email, _password);
      }

      if (user == null) {
        setState(() {
          _errorMessage = "Authentication failed. Please check your credentials.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Sign In' : 'Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "To You, From Me",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                SizedBox(height: 30),
                TextFormField(
                  key: ValueKey('email'),
                  decoration: InputDecoration(labelText: 'Email address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _email = value!;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('password'),
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters long.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _password = value!;
                  },
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _submitAuthForm(context),
                  child: Text(_isLogin ? 'Login' : 'Create Account'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    });
                  },
                  child: Text(_isLogin
                      ? 'Create new account'
                      : 'I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    if (index == 2) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateLetterScreen()),
      );

      if (result == true) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final letterService = LetterService();
    final User? currentUser = authService.user;
    final now = DateTime.now();

    if (currentUser == null) {
      return AuthScreen(); // shoud not happen, but just in case hehe
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Vault (Locked Letters)' : 'My Letters (Unlocked)',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _selectedIndex == 0 ? 'Upcoming Unlocks:' : 'Past Unlocks:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Letter>>(
              stream: letterService.getLettersForUser(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No letters yet! Create one.'));
                }

                final allLetters = snapshot.data!;
                final filteredLetters = allLetters.where((letter) {
                  if (_selectedIndex == 0) {
                    return now.isBefore(letter.unlockDate);
                  } else {
                    return now.isAfter(letter.unlockDate) || now.isAtSameMomentAs(letter.unlockDate);
                  }
                }).toList();

                if (filteredLetters.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedIndex == 0
                          ? 'No upcoming locked letters.'
                          : 'No unlocked letters yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredLetters.length,
                  itemBuilder: (context, index) {
                    final letter = filteredLetters[index];
                    final isUnlocked = now.isAfter(letter.unlockDate) || now.isAtSameMomentAs(letter.unlockDate);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          letter.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? Colors.purple : Colors.grey.shade700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlocks: ${DateFormat('MM/dd/yy HH:mm').format(letter.unlockDate)}', // Added time to subtitle
                              style: TextStyle(
                                color: isUnlocked ? Colors.green : Colors.orange,
                              ),
                            ),
                            if (isUnlocked && _selectedIndex == 0) // Show "New letter available!" only in Vault if unlocked
                              Text(
                                'New letter available!',
                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        trailing: Icon(
                          isUnlocked ? Icons.lock_open : Icons.lock_outline,
                          color: isUnlocked ? Colors.green : Colors.red,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isUnlocked
                                  ? UnlockedLetterScreen(letter: letter)
                                  : LockedLetterScreen(letter: letter),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline),
            label: 'Vault', // Locked Letters
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email),
            label: 'Unlocked', // Open Letters
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple.shade800,
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
      ),
    );
  }
}


class CreateLetterScreen extends StatefulWidget {
  @override
  _CreateLetterScreenState createState() => _CreateLetterScreenState();
}

class _CreateLetterScreenState extends State<CreateLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _message = '';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      _pickTime();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // helper to combine date and time
  DateTime? _combineDateTime() {
    if (_selectedDate == null || _selectedTime == null) {
      return null;
    }
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final letterService = LetterService();
    final User? currentUser = authService.user;

    return Scaffold(
      appBar: AppBar(title: Text('Create Letter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Title'),
                validator: (val) =>
                val == null || val.isEmpty ? 'Enter a title' : null,
                onChanged: (val) => _title = val,
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(labelText: 'Message'),
                maxLines: 5,
                validator: (val) =>
                val == null || val.isEmpty ? 'Enter a message' : null,
                onChanged: (val) => _message = val,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pickDate,
                      child: Text('Pick Unlock Date & Time'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    _selectedDate == null
                        ? 'No date selected'
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!) +
                        (_selectedTime == null
                            ? ''
                            : ' at ${_selectedTime!.format(context)}'),
                  ),
                ],
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () async {
                  final combinedDateTime = _combineDateTime();
                  if (_formKey.currentState!.validate() &&
                      combinedDateTime != null) {
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User not logged in.')),
                      );
                      return;
                    }

                    final newLetter = Letter(
                      userId: currentUser.uid,
                      title: _title,
                      message: _message,
                      unlockDate: combinedDateTime,
                    );

                    try {
                      await letterService.addLetter(newLetter); // Saving to firestone
                      await NotificationService.scheduleNotification(
                          newLetter.title, newLetter.unlockDate);
                      // Display success message BEFORE popping the screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Letter saved successfully!')),
                      );


                      Navigator.pop(context, true);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save letter: $e')),
                      );
                      print("Error saving letter: $e");
                    }
                  } else if (combinedDateTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please pick a date and time.')),
                    );
                  }
                },
                child: Text('Save Letter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LockedLetterScreen extends StatelessWidget {
  final Letter letter;

  LockedLetterScreen({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Locked')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 60, color: Colors.redAccent),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'This letter unlocks on ${DateFormat('yyyy-MM-dd HH:mm').format(letter.unlockDate)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class UnlockedLetterScreen extends StatelessWidget {
  final Letter letter;

  UnlockedLetterScreen({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Letter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${letter.title}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(letter.message, style: TextStyle(fontSize: 16, color: Colors.black87)),
              ),
            ),
            // TODO: add image display here once I can instatiate image support
          ],
        ),
      ),
    );
  }
}