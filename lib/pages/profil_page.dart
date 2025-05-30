import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  dynamic _currentUser;
  File? _profileImage;
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showCustomToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor:
          isError ? Colors.red.withAlpha((0.9 * 255).toInt()) : Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  // Chargement de l'utilisateur courant avec gestion d'erreur améliorée
  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt(ApiService.keyUserId);

      if (userId == null) {
        throw Exception("Aucun ID utilisateur trouvé");
      }

      dynamic user = await _apiService.getProfile(userId);
      if (user == null) {
        throw Exception("Utilisateur non trouvé");
      }

      setState(() {
        _currentUser = user;
        _nameController.text = user['name'];
        if (user['profile_picture'] != null) {
          _profileImage = File(user['profile_picture']);
        }
      });
    } catch (e) {
      _showCustomToast("Erreur: ${e.toString()}", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Gestion améliorée de la sélection d'image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70, // Compression pour optimiser la taille
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        final maxSize = 10 * 1024 * 1024; // 10 MB

        if (fileSize <= maxSize) {
          setState(() => _profileImage = file);
        } else {
          _showCustomToast(
            "L'image doit être inférieure à 10 Mo",
            isError: true,
          );
        }
      }
    } catch (e) {
      _showCustomToast(
        "Erreur lors de la sélection de l'image",
        isError: true,
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null) return;

    setState(() => _isSaving = true);
    try {
      await _apiService.updateProfile(
        _currentUser['id'],
        _nameController.text,
        _profileImage?.path ?? '',
      );
      _showCustomToast("Profil mis à jour avec succès");
    } catch (e) {
      _showCustomToast("Erreur lors de la mise à jour", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Photo de profil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Utiliser l\'appareil photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('Choisir une photo'),
              subtitle: const Text('Sélectionner depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _currentUser == null
          ? const Center(child: Text('Aucune donnée disponible'))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Hero(
                          tag: 'profile_image',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withAlpha((0.1 * 255).toInt()),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _profileImage != null
                                  ? Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/images/default_profile.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImagePickerModal,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.05 * 255).toInt()),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations personnelles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nom complet',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Mettre à jour le profil',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _deleteAccount,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(
                                    color: Colors.red
                                        .withAlpha((0.5 * 255).toInt())),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Supprimer mon compte',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Ajoutez cette méthode à votre classe ProfilePageState
  Future<void> _deleteAccount() async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.',
          style: TextStyle(color: Colors.red),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _apiService.deleteProfile(_currentUser['id']);
        if (success && mounted) {
          _showCustomToast("Votre compte a été supprimé");
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          _showCustomToast(
            "Erreur lors de la suppression du compte",
            isError: true,
          );
        }
      } catch (e) {
        _showCustomToast(
          "Erreur lors de la suppression du compte",
          isError: true,
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}
