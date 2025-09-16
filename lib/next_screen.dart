import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speechtext.dart';
import 'upload.dart';
import 'whoisthis.dart';
import 'task.dart';
import 'premium.dart'; // Import Premium Page
import 'profile.dart'; // Import Profile Page
import 'emergency.dart'; // Import Emergency Page

class CategoryItem {
  final String title;
  final Color color;
  final IconData icon;
  final Widget page;

  CategoryItem({
    required this.title,
    required this.color,
    required this.icon,
    required this.page,
  });
}

class CategoryBox extends StatelessWidget {
  final CategoryItem category;

  CategoryBox({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => category.page),
      ),
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: category.color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, size: 40, color: Colors.black),
            SizedBox(height: 10),
            Text(
              category.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class NextScreen extends StatefulWidget {
  @override
  _NextScreenState createState() => _NextScreenState();
}

class _NextScreenState extends State<NextScreen> {
  String userName = "Amy";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  int _selectedIndex = 0;
  List<CategoryItem> categories = [];
  List<CategoryItem> filteredCategories = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String ipAddress = '192.168.0.1';

  @override
  void initState() {
    super.initState();
    _nameController.text = userName;
    _speech = stt.SpeechToText();
    _initializeCategories();
    _loadIPAddress();
  }

  void _initializeCategories() {
    categories = [
      CategoryItem(
        title: 'Add person',
        color: Colors.purple[100]!,
        icon: Icons.person_add,
        page: UploadPage(),
      ),
      CategoryItem(
        title: 'Person identification',
        color: Colors.pink[100]!,
        icon: Icons.help_outline,
        page: WhoIsThisPage(),
      ),
      CategoryItem(
        title: 'Task entering',
        color: Colors.orange[100]!,
        icon: Icons.add_task,
        page: SpeechToTextPage(),
      ),
      CategoryItem(
        title: 'Task viewing',
        color: Colors.yellow[100]!,
        icon: Icons.view_list,
        page: ViewTasksPage(),
      ),
    ];
    filteredCategories = List.from(categories);
  }

  void _filterCategories(String query) {
    setState(() {
      filteredCategories = query.isEmpty
          ? List.from(categories)
          : categories
          .where((category) =>
          category.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _loadIPAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ipAddress = prefs.getString('ip_address') ?? '192.168.0.1';
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterCategories,
            ),
          ),
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(child: Text("No results found"))
                : GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1,
              children: filteredCategories
                  .map((category) => CategoryBox(category: category))
                  .toList(),
            ),
          ),
        ],
      ),
      Center(child: Text("IP Settings Page")),
      Center(child: Text("Reminder Page")),
      ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Hi, $userName', style: TextStyle(color: Colors.black)),
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],
          Positioned(
            bottom: 70,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EmergencyScreen()),
                );
              },
              child: Icon(Icons.help_outline, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'IP'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'Premium'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
