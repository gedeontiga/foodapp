import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class MealTrackingPage extends StatefulWidget {
  const MealTrackingPage({super.key});
  @override
  State<MealTrackingPage> createState() => MealTrackingPageState();
}

class MealTrackingPageState extends State<MealTrackingPage> {
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  late int _userId;
  List<Map<String, dynamic>> _meals = [];
  DateTime _selectedDate = DateTime.now();
  int _dailyCalorieGoal = 2000; // Default value
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadMeals();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt(ApiService.keyUserId) ?? 0;
    final profile = await _apiService.getHealthProfile(_userId);
    if (profile != null) {
      _dailyCalorieGoal = profile['daily_calorie_goal'];
    }
    await _loadMeals();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMeals() async {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final meals = await _apiService.getMeals(_userId,
        startDate: startOfDay, endDate: endOfDay);
    setState(() => _meals = meals);
  }

  void showAddMealDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Meal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Meal Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Calories',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final calories = int.tryParse(_caloriesController.text);
                      if (calories != null) {
                        Navigator.pop(context);
                        await _apiService.addMeal(
                          _userId,
                          _nameController.text,
                          calories,
                          _selectedDate,
                        );
                        _nameController.clear();
                        _caloriesController.clear();
                        await _loadMeals();
                        _checkCalorieGoal();
                      }
                    },
                    child: const Text('Add Meal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditMealDialog(Map<String, dynamic> meal) {
    final editNameController = TextEditingController(text: meal['name']);
    final editCaloriesController =
        TextEditingController(text: meal['calories'].toString());
    final consumedAt = DateTime.fromMillisecondsSinceEpoch(meal['consumed_at']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Meal',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: editNameController,
                decoration: InputDecoration(
                  labelText: 'Meal Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: editCaloriesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final newTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(consumedAt),
                  );
                  if (newTime != null) {
                    setState(() {
                      final newDateTime = DateTime(
                        consumedAt.year,
                        consumedAt.month,
                        consumedAt.day,
                        newTime.hour,
                        newTime.minute,
                      );
                      meal['consumed_at'] = newDateTime.millisecondsSinceEpoch;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time Consumed'),
                      Text(
                        DateFormat('HH:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              meal['consumed_at']),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Meal'),
                            content: const Text(
                                'Are you sure you want to delete this meal?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _apiService.deleteMeal(meal['id']);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          await _loadMeals();
                        }
                      },
                      child: const Text('Delete Meal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final calories =
                            int.tryParse(editCaloriesController.text);
                        if (calories != null) {
                          await _apiService.updateMeal(
                            meal['id'],
                            editNameController.text,
                            calories,
                            DateTime.fromMillisecondsSinceEpoch(
                                meal['consumed_at']),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          await _loadMeals();
                          _checkCalorieGoal();
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _checkCalorieGoal() {
    final totalCalories = _meals.fold<int>(
      0,
      (sum, meal) => sum + (meal['calories'] as int),
    );
    if (totalCalories > _dailyCalorieGoal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning: Daily calorie goal exceeded!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCalories = _meals.fold<int>(
      0,
      (sum, meal) => sum + (meal['calories'] as int),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color.fromARGB(25, 33, 150, 243),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM d, y').format(_selectedDate),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '$totalCalories / $_dailyCalorieGoal kcal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: totalCalories > _dailyCalorieGoal
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              final meal = _meals[index];
              return Dismissible(
                key: Key(meal['id'].toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await _apiService.deleteMeal(meal['id']);
                  await _loadMeals();
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      meal['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('HH:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(
                            meal['consumed_at']),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${meal['calories']} kcal',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit,
                          color: Colors.blue[300],
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () => _showEditMealDialog(meal),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
