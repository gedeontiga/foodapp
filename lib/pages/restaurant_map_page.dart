import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RestaurantMapPage extends StatefulWidget {
  const RestaurantMapPage({super.key});

  @override
  State<RestaurantMapPage> createState() => _RestaurantMapPageState();
}

class _RestaurantMapPageState extends State<RestaurantMapPage> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  final List<Map<String, dynamic>> _restaurants = [
    {
      'name': 'Healthy Kitchen',
      'position': const LatLng(4.0511, 9.7679),
      'rating': 4.5,
    },
    // Add more restaurants
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      // Handle error
    }
  }

  void _showReservationDialog(Map<String, dynamic> restaurant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reserve at ${restaurant['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Number of people',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Preferred time',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('Confirm Reservation'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reservation confirmed!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Restaurants')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              ..._restaurants.map(
                (restaurant) => Marker(
                  point: restaurant['position'],
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showReservationDialog(restaurant),
                    child: const Icon(
                      Icons.restaurant,
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
