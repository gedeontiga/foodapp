import 'package:flutter/material.dart';

import 'pages/bmi_calculator_page.dart';
import 'pages/chat_page.dart';
import 'pages/meal_history.dart';
import 'pages/nutrition_statistics_page.dart';
import 'pages/profil_page.dart';
import 'services/api_service.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final GlobalKey<ChatPageState> _chatKey = GlobalKey<ChatPageState>();
  final GlobalKey<MealTrackingPageState> _mealKey =
      GlobalKey<MealTrackingPageState>();
  final GlobalKey<NutritionStatsPageState> _statsKey =
      GlobalKey<NutritionStatsPageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();
  late final List<Widget> _pages;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Initialize selected index with the passed initial index
    _selectedIndex = widget.initialIndex;

    _pages = [
      ChatPage(key: _chatKey),
      const BMICalculatorPage(),
      MealTrackingPage(key: _mealKey),
      NutritionStatsPage(key: _statsKey),
      ProfilePage(key: _profileKey),
    ];
  }

  final List<String> _titles = [
    'Chat',
    'BMI Calculator',
    'Meal Tracker',
    'Nutrition Statistics',
    'My Profile'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget>? _buildActions(BuildContext context) {
    switch (_selectedIndex) {
      case 2: // Meal tracking page
        return [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2025),
              );
              if (date != null) {
                _mealKey.currentState?.selectDate(date);
              }
            },
          ),
        ];

      case 3: // Nutrition stats page
        return [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _statsKey.currentState?.loadStats();
            },
          ),
        ];

      case 4: // Profile page
        return [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ];

      default:
        return null;
    }
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 0:
        return FloatingActionButton(
          onPressed: () {
            _chatKey.currentState?.showAddUserDialog();
          },
          child: const Icon(Icons.add),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () {
            _mealKey.currentState?.showAddMealDialog();
          },
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: _buildActions(context),
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight),
            label: 'BMI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Meals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
