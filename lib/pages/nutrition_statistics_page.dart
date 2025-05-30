import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

import 'restaurant_map_page.dart';

class NutritionStatsPage extends StatefulWidget {
  const NutritionStatsPage({super.key});
  @override
  State<NutritionStatsPage> createState() => NutritionStatsPageState();
}

class NutritionStatsPageState extends State<NutritionStatsPage> {
  final _apiService = ApiService();
  late int _userId;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<FlSpot> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt(ApiService.keyUserId) ?? 0;
    await _loadStats();
    setState(() => _isLoading = false);
  }

  void loadStats() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek =
        startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    final dailyMeals = await _apiService.getMeals(
      _userId,
      startDate: startOfDay,
      endDate: startOfDay.add(const Duration(days: 1)),
    );
    final dailyCalories = dailyMeals.fold<int>(
      0,
      (sum, meal) => sum + (meal['calories'] as int),
    );

    _weeklyData = [];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final meals = await _apiService.getMeals(
        _userId,
        startDate: day,
        endDate: day.add(const Duration(days: 1)),
      );
      final calories = meals.fold<int>(
        0,
        (sum, meal) => sum + (meal['calories'] as int),
      );
      _weeklyData.add(FlSpot(i.toDouble(), calories.toDouble()));
    }

    final monthlyMeals = await _apiService.getMeals(
      _userId,
      startDate: startOfMonth,
      endDate: DateTime(now.year, now.month + 1, 1),
    );
    final monthlyCalories = monthlyMeals.fold<int>(
      0,
      (sum, meal) => sum + (meal['calories'] as int),
    );

    final yearlyMeals = await _apiService.getMeals(
      _userId,
      startDate: startOfYear,
      endDate: DateTime(now.year + 1, 1, 1),
    );
    final yearlyCalories = yearlyMeals.fold<int>(
      0,
      (sum, meal) => sum + (meal['calories'] as int),
    );

    setState(() {
      _stats = {
        'daily': dailyCalories,
        'weekly': _weeklyData.fold<double>(
          0,
          (sum, spot) => sum + spot.y,
        ),
        'monthly': monthlyCalories,
        'yearly': yearlyCalories,
        'weeklyAvg': _weeklyData.fold<double>(
              0,
              (sum, spot) => sum + spot.y,
            ) /
            7,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(
              'Today\'s Calories',
              '${_stats['daily']} kcal',
              Icons.today,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return Text(days[value.toInt()]);
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _weeklyData,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Weekly Average',
                    '${_stats['weeklyAvg'].toStringAsFixed(0)} kcal',
                    Icons.calendar_view_week,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Monthly Total',
                    '${_stats['monthly']} kcal',
                    Icons.calendar_today,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              'Yearly Total',
              '${_stats['yearly']} kcal',
              Icons.calendar_month,
              Colors.purple,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => RestaurantMapPage())),
        child: const Icon(Icons.store),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
