import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

class DietitianMapPage extends StatefulWidget {
  const DietitianMapPage({super.key});

  @override
  State<DietitianMapPage> createState() => _DietitianMapPageState();
}

class _DietitianMapPageState extends State<DietitianMapPage> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  final MapController _mapController = MapController();

  // Expanded list of dietitians
  final List<Map<String, dynamic>> _dietitians = [
    {
      'name': 'Dr. Smith',
      'position': LatLng(4.0511, 9.7679),
      'speciality': 'Clinical Nutrition',
    },
    {
      'name': 'Dr. Johnson',
      'position': LatLng(4.0525, 9.7600),
      'speciality': 'Sports Nutrition',
    },
    {
      'name': 'Dr. Brown',
      'position': LatLng(4.0490, 9.7700),
      'speciality': 'Pediatric Nutrition',
    },
    {
      'name': 'Dr. Taylor',
      'position': LatLng(4.0550, 9.7650),
      'speciality': 'Gastroenterology',
    },
    {
      'name': 'Dr. Wilson',
      'position': LatLng(4.0480, 9.7580),
      'speciality': 'Weight Management',
    },
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() => _currentPosition = position);
    } catch (e) {
      if (!mounted) return;
      // Handle location errors gracefully
      setState(() => _currentPosition = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAppointmentDialog(Map<String, dynamic> dietitian) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book appointment with ${dietitian['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Preferred date',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Reason for visit',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage();
            },
            child: const Text('Book Appointment'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment booked successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nearby Dietitians')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Dietitians')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              // Current location marker
              Marker(
                width: 40,
                height: 40,
                point: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              // Dietitian markers
              ..._dietitians.map(
                (dietitian) => Marker(
                  width: 40,
                  height: 40,
                  point: dietitian['position'] as LatLng,
                  child: GestureDetector(
                    onTap: () => _showAppointmentDialog(dietitian),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
