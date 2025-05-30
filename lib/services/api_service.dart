import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/app_db.dart';

class ApiService {
  static const String _keyLoggedIn = "loggedIn";
  static const String _keyEmail = "email";
  static const String _keyUserId = "userId";
  static const String _keyLastSync = "lastSync";
  static String get keyUserId => _keyUserId;

  final String baseUrl = 'https://gedeon-chat-api.up.railway.app';
  final AppDb db = AppDb();
  late Future<Database> _localDb;
  final List<Map<String, dynamic>> _pendingMessages = [];
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  ApiService() {
    _localDb = db.localDb;
    _initSyncListener();
  }

  // Check if device is online
  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // Enhanced sync listener that also handles background sync of profile data
  void _initSyncListener() {
    _connectivitySubscription?.cancel();
    final connectivity = Connectivity();

    _connectivitySubscription = connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      if (results.any((result) => result != ConnectivityResult.none)) {
        await _syncPendingMessages();

        // Sync profile data when connection is restored
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt(_keyUserId);
        if (userId != null) {
          await syncLocalData(userId);
        }
      }
    });
  }

  // Enhanced profile fetching with offline support
  Future<Map<String, dynamic>?> getProfile(int userId) async {
    // First try to get data from local database
    final localData = await (await _localDb).query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    // If online, try to fetch fresh data and update local
    if (await _isOnline()) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/profile/$userId'));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await (await _localDb).insert(
            'users',
            {...data, 'is_synced': 1},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          return data;
        }
      } catch (e) {
        // If API call fails, fall back to local data
        if (localData.isNotEmpty) {
          return localData.first;
        }
        return null;
      }
    }

    // Return local data if offline or if API call failed
    return localData.isNotEmpty ? localData.first : null;
  }

  // Enhanced related users fetching with offline support
  Future<List<Map<String, dynamic>>> getRelatedUsers(int? userId) async {
    if (userId == null) return [];

    // First get local data
    final localRelations = await (await _localDb).rawQuery('''
      SELECT u.* FROM users u
      JOIN user_relations ur ON u.id = ur.user2_id
      WHERE ur.user1_id = ?
    ''', [userId]);

    // If online, try to fetch fresh data
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/relations?user_id=${userId.toString()}'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;

          // Update local database with fresh data
          for (var user in data) {
            await (await _localDb).insert(
              'users',
              {...user, 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          return List<Map<String, dynamic>>.from(data);
        }
      } catch (e) {
        // Fall back to local data if API call fails
        return List<Map<String, dynamic>>.from(localRelations);
      }
    }

    // Return local data if offline or if API call failed
    return List<Map<String, dynamic>>.from(localRelations);
  }

  // Enhanced message fetching with offline support
  Future<List<Map<String, dynamic>>> getMessages(
      int senderId, int receiverId) async {
    // First get local messages
    final localMessages = await (await _localDb).query(
      'messages',
      where:
          '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [senderId, receiverId, receiverId, senderId],
      orderBy: 'timestamp DESC',
    );

    // If online, try to fetch fresh messages
    if (await _isOnline()) {
      try {
        final response = await http.get(Uri.parse(
            '$baseUrl/messages?sender_id=$senderId&receiver_id=$receiverId'));

        if (response.statusCode == 200) {
          final messages = json.decode(response.body) as List;

          // Update local database with fresh messages
          for (var message in messages) {
            await (await _localDb).insert(
              'messages',
              {...message, 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          return List<Map<String, dynamic>>.from(messages);
        }
      } catch (e) {
        // Fall back to local messages if API call fails
        return List<Map<String, dynamic>>.from(localMessages);
      }
    }

    // Return local messages if offline or if API call failed
    return List<Map<String, dynamic>>.from(localMessages);
  }

  // Enhanced sync function with progress tracking
  Future<void> syncLocalData(int userId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    final prefs = await SharedPreferences.getInstance();

    try {
      if (await _isOnline()) {
        // Sync profile
        final profile = await getProfile(userId);
        if (profile != null) {
          await (await _localDb).insert(
            'users',
            {...profile, 'is_synced': 1},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Sync relations and their messages
        final relations = await getRelatedUsers(userId);
        for (var relation in relations) {
          await (await _localDb).insert(
            'user_relations',
            {'user1_id': userId, 'user2_id': relation['id'], 'is_synced': 1},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Store related user's profile
          await (await _localDb).insert(
            'users',
            {...relation, 'is_synced': 1},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Sync messages with this relation
          final messages = await getMessages(userId, relation['id']);
          for (var message in messages) {
            await (await _localDb).insert(
              'messages',
              {...message, 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Update last sync timestamp
        await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> _syncPendingMessages() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final List<Map<String, dynamic>> pendingCopy =
          List.from(_pendingMessages);
      for (var message in pendingCopy) {
        final success = await sendMessage(
          message['sender_id'],
          message['receiver_id'],
          message['content'],
          message['message_type'],
        );
        if (success) {
          _pendingMessages.remove(message);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  // Health Profile Methods
  Future<void> updateHealthProfile(
      int userId, double height, double weight, int dailyCalorieGoal) async {
    (await _localDb).insert(
      'user_health_profile',
      {
        'user_id': userId,
        'height': height,
        'weight': weight,
        'daily_calorie_goal': dailyCalorieGoal,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getHealthProfile(int userId) async {
    final List<Map<String, dynamic>> results = await (await _localDb).query(
      'user_health_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Meal Methods
  Future<int> addMeal(
      int userId, String name, int calories, DateTime consumedAt) async {
    return (await _localDb).insert('meals', {
      'user_id': userId,
      'name': name,
      'calories': calories,
      'consumed_at': consumedAt.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'is_synced': 0
    });
  }

  Future<List<Map<String, dynamic>>> getMeals(int userId,
      {DateTime? startDate, DateTime? endDate}) async {
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND consumed_at BETWEEN ? AND ?';
      whereArgs.addAll(
          [startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch]);
    }

    return (await _localDb).query('meals',
        where: whereClause, whereArgs: whereArgs, orderBy: 'consumed_at DESC');
  }

  Future<void> updateMeal(
      int mealId, String name, int calories, DateTime consumedAt) async {
    (await _localDb).update(
      'meals',
      {
        'name': name,
        'calories': calories,
        'consumed_at': consumedAt.millisecondsSinceEpoch,
        'is_synced': 0
      },
      where: 'id = ?',
      whereArgs: [mealId],
    );
  }

  Future<void> deleteMeal(int mealId) async {
    (await _localDb).delete(
      'meals',
      where: 'id = ?',
      whereArgs: [mealId],
    );
  }

  Future<bool> sendMessage(
      int senderId, int receiverId, String content, String messageType) async {
    final messageData = {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_synced': 0
    };

    // Toujours sauvegarder en local d'abord
    final localId = (await _localDb).insert('messages', messageData);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'content': content,
          'message_type': messageType,
        }),
      );

      if (response.statusCode == 201) {
        (await _localDb).update(
          'messages',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [localId],
        );
        return true;
      }

      // Si échec, ajouter à la file d'attente
      _pendingMessages.add(messageData);
      return false;
    } catch (e) {
      // En cas d'erreur, ajouter à la file d'attente
      _pendingMessages.add(messageData);
      return false;
    }
  }

  // Méthodes de gestion de session
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
  }

  // Authentification
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        // Stocker les informations de connexion
        await prefs.setBool(_keyLoggedIn, true);
        await prefs.setString(_keyEmail, email);
        await prefs.setInt(_keyUserId, responseData['user_id']);

        // Synchroniser les données locales après connexion
        await syncLocalData(responseData['user_id']);

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProfile(
      int userId, String name, String profilePicture) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'profile_picture': profilePicture,
        }),
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        (await _localDb).update('users',
            {'name': name, 'profile_picture': profilePicture, 'is_synced': 1},
            where: 'id = ?', whereArgs: [userId]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addUserRelation(
      String currentUserId, String newUserEmail) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_relation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user1_id': currentUserId,
          'user2_email': newUserEmail,
        }),
      );

      if (response.statusCode == 201) {
        // Stocker la relation localement
        (await _localDb).insert('user_relations', {
          'user1_id': int.parse(currentUserId),
          'user2_id': int.parse(
              currentUserId), // Récupérer l'ID de l'utilisateur ajouté côté serveur
          'is_synced': 1
        });
        return true;
      }
      return false;
    } catch (e) {
      // Stocker comme relation non synchronisée
      (await _localDb).insert('user_relations',
          {'user1_id': int.parse(currentUserId), 'is_synced': 0});

      return false;
    }
  }

  Future<bool> deleteProfile(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        // Supprimer les données locales
        (await _localDb).delete('users', where: 'id = ?', whereArgs: [userId]);
        (await _localDb).delete('messages',
            where: 'sender_id = ? OR receiver_id = ?',
            whereArgs: [userId, userId]);
        (await _localDb).delete('user_relations',
            where: 'user1_id = ? OR user2_id = ?', whereArgs: [userId, userId]);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyLoggedIn);
        await prefs.remove(_keyEmail);
        await prefs.remove(_keyUserId);

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
