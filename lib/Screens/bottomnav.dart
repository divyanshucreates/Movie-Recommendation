import 'package:flutter/material.dart';
import 'homescreen.dart';

class MovieBottomNav extends StatefulWidget {
  @override
  _MovieBottomNavState createState() => _MovieBottomNavState();
}

class _MovieBottomNavState extends State<MovieBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Homescreen(),
    Homescreen(),
    Homescreen(), // Floating button triggers this
    Homescreen(),
    Homescreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onSearchPressed() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.energy_savings_leaf),
            label: 'My Garden',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
      // Floating action button at the center
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20), // Optional: adjust position
        child: Container(
          width: 70, // Increase the width
          height: 70, // Increase the height
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Homescreen()));
            },
            backgroundColor: Colors.green,
            child: const Icon(
              Icons.add,
              size: 35,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

}
