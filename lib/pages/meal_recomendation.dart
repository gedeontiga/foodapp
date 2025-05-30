import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/meal.dart';

class MealRecommendationsPage extends StatefulWidget {
  final double? bmi;

  const MealRecommendationsPage({super.key, this.bmi});

  @override
  State<MealRecommendationsPage> createState() => _MealRecommendationsPageState();
}

class _MealRecommendationsPageState extends State<MealRecommendationsPage> {
  late List<Meal> _allMeals = [];
  List<Meal> _displayedMeals = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _rowsPerPage = 5;
  String _searchQuery = '';
  String _selectedType = 'All';
  int _minCalories = 0;
  int _maxCalories = 1000;

  final List<String> _mealTypes = ['All', 'breakfast', 'lunch', 'dinner', 'snack', 'mixte', 'dessert'];
  final List<String> _tags = [
    'fruit',
    'vegetable',
    'protein',
    'grain',
    'pastry',
    'healthy',
    'high-calorie',
    'light',
    'traditional'
  ];

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  Future<void> _fetchMeals() async {
    try {
      final response = await http.get(Uri.parse('https://abcd1234.ngrok.io/api/foods/distinct'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allMeals = data
              .map((item) => Meal(
                    name: item['name'],
                    calories: item['calories'],
                    type: item['type'],
                    tags: List<String>.from(item['tags']).where((tag) => tag.isNotEmpty).toList(),
                    image: item['image'],
                    ingredients: item['ingredients'],
                    recipe: item['recipe'],
                  ))
              .toList();
          _applyFiltersAndPagination();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load meals: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndPagination() {
    List<Meal> filteredMeals = _allMeals.where((meal) {
      final matchesSearch = meal.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'All' || meal.type == _selectedType;
      final matchesCalories = meal.calories >= _minCalories && meal.calories <= _maxCalories;
      return matchesSearch && matchesType && matchesCalories;
    }).toList();

    final mealsToDisplay = widget.bmi != null ? _getRecommendedMeals(filteredMeals) : filteredMeals;

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    _displayedMeals = mealsToDisplay.sublist(
      startIndex,
      endIndex > mealsToDisplay.length ? mealsToDisplay.length : endIndex,
    );
  }

  List<Meal> _getRecommendedMeals(List<Meal> meals) {
    if (widget.bmi == null) return meals;
    if (widget.bmi! < 18.5) {
      return meals.where((meal) => meal.calories >= 300).toList();
    } else if (widget.bmi! < 25) {
      return meals.where((meal) => meal.calories >= 200 && meal.calories <= 400).toList();
    } else {
      return meals.where((meal) => meal.calories <= 300).toList();
    }
  }

  void _updateFilters({
    String? searchQuery,
    String? selectedType,
    int? minCalories,
    int? maxCalories,
  }) {
    setState(() {
      _searchQuery = searchQuery ?? _searchQuery;
      _selectedType = selectedType ?? _selectedType;
      _minCalories = minCalories ?? _minCalories;
      _maxCalories = maxCalories ?? _maxCalories;
      _currentPage = 1;
      _applyFiltersAndPagination();
    });
  }

  void _nextPage() {
    List<Meal> filteredMeals = _allMeals.where((meal) {
      final matchesSearch = meal.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'All' || meal.type == _selectedType;
      final matchesCalories = meal.calories >= _minCalories && meal.calories <= _maxCalories;
      return matchesSearch && matchesType && matchesCalories;
    }).toList();

    final mealsToDisplay = widget.bmi != null ? _getRecommendedMeals(filteredMeals) : filteredMeals;

    if (_currentPage * _rowsPerPage < mealsToDisplay.length) {
      setState(() {
        _currentPage++;
        _applyFiltersAndPagination();
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _applyFiltersAndPagination();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.bmi != null ? 'Meal Recommendations' : 'Food List'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.bmi != null ? 'Meal Recommendations' : 'Food List'),
        ),
        body: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    List<Meal> filteredMeals = _allMeals.where((meal) {
      final matchesSearch = meal.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'All' || meal.type == _selectedType;
      final matchesCalories = meal.calories >= _minCalories && meal.calories <= _maxCalories;
      return matchesSearch && matchesType && matchesCalories;
    }).toList();

    final mealsToDisplay = widget.bmi != null ? _getRecommendedMeals(filteredMeals) : filteredMeals;
    final totalPages = (mealsToDisplay.length / _rowsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bmi != null ? 'Meal Recommendations' : 'Food List',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).brightness == Brightness.light
                  ? Colors.teal
                  : Colors.teal[700]!,
              Theme.of(context).brightness == Brightness.light
                  ? Colors.tealAccent
                  : Colors.tealAccent[700]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) => _updateFilters(searchQuery: value),
                decoration: InputDecoration(
                  hintText: 'Search meals...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: Theme.of(context).inputDecorationTheme.border,
                  contentPadding: Theme.of(context).inputDecorationTheme.contentPadding,
                ),
              ),
            ),
            Expanded(
              child: _displayedMeals.isEmpty
                  ? Center(
                      child: Text(
                        widget.bmi != null
                            ? 'No meals match your BMI criteria.'
                            : 'No meals match your filters.',
                        style: const TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _displayedMeals.length,
                      itemBuilder: (context, index) {
                        final meal = _displayedMeals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    meal.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (meal.image != null && meal.image!.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              meal.image!,
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(
                                                Icons.broken_image,
                                                size: 50,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        if (meal.ingredients != null && meal.ingredients!.isNotEmpty)
                                          Text('Ingredients: ${meal.ingredients}'),
                                        const SizedBox(height: 10),
                                        if (meal.recipe != null && meal.recipe!.isNotEmpty)
                                          Text('Recipe: ${meal.recipe}'),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: meal.image != null && meal.image!.isNotEmpty
                                        ? Image.network(
                                            meal.image!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.fastfood,
                                                size: 40,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.fastfood,
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meal.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${meal.calories} kcal - ${meal.type}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: meal.tags
                                              .map(
                                                (tag) => Chip(
                                                  label: Text(
                                                    tag,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 0),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _previousPage,
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Page $_currentPage of $totalPages',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _nextPage,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Filters',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Min Calories'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _updateFilters(minCalories: int.tryParse(value) ?? 0),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Max Calories'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _updateFilters(maxCalories: int.tryParse(value) ?? 1000),
              ),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Meal Type'),
                items: _mealTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) => _updateFilters(selectedType: value),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((tag) => FilterChip(
                          label: Text(tag),
                          selected: _displayedMeals.any((meal) => meal.tags.contains(tag)),
                          onSelected: (selected) {
                            setState(() {
                              _applyFiltersAndPagination();
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}