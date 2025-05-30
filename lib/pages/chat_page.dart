import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation_page.dart';
import '../services/api_service.dart';
import 'add_user_dialog.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _relatedUsers;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserRelation();
  }

  Future<void> _loadUserRelation() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt(ApiService.keyUserId);

    if (_currentUserId != null) {
      setState(() {
        _relatedUsers = _apiService.getRelatedUsers(_currentUserId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Added Scaffold widget
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<dynamic>>(
              future: _relatedUsers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No related users found'));
                }

                List<dynamic> relatedUsers = snapshot.data!;
                return Material(
                  // Added Material widget
                  child: ListView.builder(
                    itemCount: relatedUsers.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> user = relatedUsers[index];
                      return ListTile(
                        title: Text(user["name"]),
                        subtitle: Text(user["email"]),
                        leading: CircleAvatar(
                          backgroundImage: user['profilePicture'] != null
                              ? NetworkImage(user['profilePicture']!)
                              : const AssetImage(
                                      'assets/images/default_profile.png')
                                  as ImageProvider,
                        ),
                        onTap: () {
                          if (!mounted || _currentUserId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationPage(
                                senderId: _currentUserId!,
                                receiverId: user['id']!,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_fab',
        onPressed: showAddUserDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void showAddUserDialog() {
    if (!mounted || _currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        onAddUser: (String email) async {
          try {
            await _apiService.addUserRelation(
              _currentUserId.toString(),
              email,
            );

            if (!mounted) return;
            setState(() {
              _relatedUsers = _apiService.getRelatedUsers(_currentUserId);
            });

            Fluttertoast.showToast(
              msg: "Utilisateur ajouté avec succès",
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );
            return;
          } catch (e) {
            throw Exception(
                "Impossible d'ajouter l'utilisateur: ${e.toString()}");
          }
        },
      ),
    );
  }
}
