import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dietitian_page.dart';
import 'meal_recomendation.dart';

class BMICalculatorPage extends StatefulWidget {
  const BMICalculatorPage({super.key});

  @override
  State<BMICalculatorPage> createState() => _BMICalculatorPageState();
}

class _BMICalculatorPageState extends State<BMICalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bmiHistory = <Map<String, dynamic>>[];
  final _apiService = ApiService();

  double? _bmi;
  String _interpretation = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthProfile();
    _loadBMIHistory();
  }

  Future<void> _loadBMIHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _bmiHistory.addAll(List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString('bmi_history') ?? '[]'),
    ));
    setState(() {});
  }

  Future<void> _saveBMIHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bmi_history', jsonEncode(_bmiHistory));
  }

  void _calculateBMI() {
    if (_formKey.currentState?.validate() ?? false) {
      final height = double.parse(_heightController.text) / 100;
      final weight = double.parse(_weightController.text);

      setState(() {
        _bmi = weight / (height * height);
        _interpretation = _getBMIInterpretation(_bmi!);
        _bmiHistory.add({
          'date': DateTime.now().millisecondsSinceEpoch,
          'bmi': _bmi,
          'weight': weight,
          'height': height * 100,
        });
      });
      _saveBMIHistory();
    }
  }

  Future<void> _loadHealthProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(ApiService.keyUserId);
    if (userId != null) {
      final profile = await _apiService.getHealthProfile(userId);
      if (profile != null) {
        setState(() {
          _heightController.text = profile['height'].toString();
          _weightController.text = profile['weight'].toString();
          _isLoading = false;
        });
        _calculateBMI();
      }
    }
    setState(() => _isLoading = false);
  }

  String _getBMIInterpretation(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obesity';
  }

  Color _getInterpretationColor(String interpretation) {
    switch (interpretation) {
      case 'Underweight':
        return Colors.orange;
      case 'Normal weight':
        return Colors.green;
      case 'Overweight':
        return Colors.orange;
      case 'Obesity':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }

  Widget _buildBMIResultCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Your BMI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _bmi!.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _getInterpretationColor(_interpretation),
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _interpretation,
              style: TextStyle(
                fontSize: 18,
                color: _getInterpretationColor(_interpretation),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBMIHistoryCarousel() {
    if (_bmiHistory.isEmpty) {
      return const Center(
        child: Text(
          'No BMI History Found',
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'BMI History',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _bmiHistory.length,
            itemBuilder: (context, index) {
              final entry = _bmiHistory[index];
              final date = DateTime.fromMillisecondsSinceEpoch(entry['date']);
              final formattedDate = '${date.day}/${date.month}/${date.year}';
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date: $formattedDate',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('BMI: ${entry['bmi'].toStringAsFixed(1)}'),
                      Text('Weight: ${entry['weight']} kg'),
                      Text('Height: ${entry['height']} cm'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMealRecommendationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _bmiHistory.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MealRecommendationsPage(bmi: _bmiHistory.last['bmi']),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _bmiHistory.isNotEmpty ? Colors.blue : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Get Meal Recommendations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Your Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _heightController,
                      label: 'Height (cm)',
                      hintText: 'Enter your height in cm',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter your height'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _weightController,
                      label: 'Weight (kg)',
                      hintText: 'Enter your weight in kg',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter your weight'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _calculateBMI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Calculate BMI'),
                      ),
                    ),
                    if (_bmi != null) ...[
                      const SizedBox(height: 24),
                      _buildBMIResultCard(),
                    ],
                    _buildMealRecommendationButton(),
                    _buildBMIHistoryCarousel(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DietitianMapPage()),
        ),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.map_outlined),
      ),
    );
  }
}
