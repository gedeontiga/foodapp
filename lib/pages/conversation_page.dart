import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import '../services/api_service.dart';

class ConversationPage extends StatefulWidget {
  final int senderId;
  final int receiverId;

  const ConversationPage({
    super.key,
    required this.senderId,
    required this.receiverId,
  });

  @override
  ConversationPageState createState() => ConversationPageState();
}

class ConversationPageState extends State<ConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  final _supportedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
  final _supportedVideoTypes = ['mp4', 'mov', 'avi'];
  final _supportedAudioTypes = ['mp3', 'wav', 'aac', 'm4a'];
  bool _isRecording = false;
  String? _audioFilePath;
  List<dynamic> _messages = [];
  final ApiService _apiService = ApiService();
  VideoPlayerController? _videoController;
  final Map<String, bool> _audioPlayingStates = {};
  final Map<String, File> _cachedFiles = {};

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _loadMessages();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.microphone,
    ];

    for (var permission in permissions) {
      final status = await permission.request();
      if (status.isDenied) {
        _showCustomToast("Permission ${permission.toString()} is required",
            isError: true);
      }
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      await _audioPlayer.openPlayer();
    } catch (e) {
      _showCustomToast("Error initializing audio", isError: true);
    }
  }

  void _showCustomToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> _loadMessages() async {
    try {
      final messages =
          await _apiService.getMessages(widget.senderId, widget.receiverId);
      setState(() {
        _messages = messages;
        for (var message in messages) {
          if (_isMediaMessage(message['message_type'])) {
            _cacheFile(message['content'], message['message_type']);
          }
        }
      });
    } catch (e) {
      _showCustomToast("Error loading messages", isError: true);
    }
  }

  bool _isMediaMessage(String type) {
    return ['image', 'video', 'audio'].contains(type);
  }

  Future<void> _cacheFile(String filePath, String type) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        _cachedFiles[filePath] = file;
      }
    } catch (e) {
      ("Error caching file: $e");
    }
  }

  Future<File> _saveFileToLocal(String originalPath) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = path.basename(originalPath);
      final String savedPath = path.join(
          appDir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final File originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        throw Exception('Original file does not exist');
      }

      final File savedFile = await originalFile.copy(savedPath);
      return savedFile;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  Future<void> _sendMessage(
      {required String content, required String type}) async {
    try {
      await _apiService.sendMessage(
        widget.senderId,
        widget.receiverId,
        content,
        type,
      );

      setState(() {
        _messages.add({
          'sender_id': widget.senderId,
          'receiver_id': widget.receiverId,
          'content': content,
          'message_type': type,
          'timestamp': DateTime.now().toString(),
        });

        if (type == 'audio') {
          _audioPlayingStates[content] = false;
        }
      });

      if (_isMediaMessage(type)) {
        _cacheFile(content, type);
      }

      _messageController.clear();
      _showCustomToast("Message sent");
    } catch (e) {
      _showCustomToast("Failed to send message", isError: true);
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showCustomToast("Microphone permission denied", isError: true);
        return;
      }

      Directory tempDir = await getTemporaryDirectory();
      _audioFilePath = '${tempDir.path}/temp_audio${Random().nextInt(100)}.aac';

      await _recorder.startRecorder(
        toFile: _audioFilePath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
      });

      _showCustomToast("Recording started...");
    } catch (e) {
      _showCustomToast("Error starting recording", isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      _showAudioPreview();
    } catch (e) {
      _showCustomToast("Error stopping recording", isError: true);
    }
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_audioPlayer.isPlaying) {
        await _audioPlayer.stopPlayer();
        setState(() {
          _audioPlayingStates.forEach((key, value) {
            _audioPlayingStates[key] = false;
          });
        });
        return;
      }

      await _audioPlayer.startPlayer(
        fromURI: filePath,
        whenFinished: () {
          setState(() {
            _audioPlayingStates[filePath] = false;
          });
        },
      );

      setState(() {
        _audioPlayingStates[filePath] = true;
      });
    } catch (e) {
      _showCustomToast("Error playing audio", isError: true);
    }
  }

  void _showAudioPreview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Audio Preview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildAudioPreviewControls(),
              const SizedBox(height: 20),
              _buildAudioPreviewActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPreviewControls() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatefulBuilder(
            builder: (context, setState) => IconButton(
              icon: Icon(
                _audioPlayingStates[_audioFilePath] ?? false
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 48,
                color: Colors.blue,
              ),
              onPressed: () => _handleAudioPreviewPlayback(setState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreviewActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Send'),
            onPressed: () async {
              final File savedFile = await _saveFileToLocal(_audioFilePath!);
              await _sendMessage(content: savedFile.path, type: 'audio');
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAudioPreviewPlayback(StateSetter setState) async {
    if (_audioPlayingStates[_audioFilePath] ?? false) {
      await _audioPlayer.pausePlayer();
    } else {
      await _playAudio(_audioFilePath!);
    }
    setState(() {
      _audioPlayingStates[_audioFilePath!] =
          !(_audioPlayingStates[_audioFilePath] ?? false);
    });
  }

  Future<void> _pickFile(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _getFileExtensions(type),
      );

      if (result != null) {
        final File originalFile = File(result.files.single.path!);
        final int fileSize = await originalFile.length();
        final int maxSize = 100 * 1024 * 1024; // 100MB

        if (fileSize > maxSize) {
          _showCustomToast("File must be smaller than 100MB", isError: true);
          return;
        }

        final File savedFile = await _saveFileToLocal(originalFile.path);
        _cachedFiles[savedFile.path] = savedFile;

        await _sendMessage(content: savedFile.path, type: type);
        _showCustomToast("File uploaded successfully");
      }
    } catch (e) {
      _showCustomToast("Error selecting file: ${e.toString()}", isError: true);
    }
  }

  List<String> _getFileExtensions(String type) {
    switch (type) {
      case 'image':
        return _supportedImageTypes;
      case 'video':
        return _supportedVideoTypes;
      case 'audio':
        return _supportedAudioTypes;
      default:
        return [];
    }
  }

  void _showFilePickerOptions() {
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
              'Send a File',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFilePickerOption(
              icon: Icons.image,
              color: Colors.blue,
              title: 'Image',
              subtitle: 'Send an image',
              onTap: () => _handleFilePickerOption(context, 'image'),
            ),
            _buildFilePickerOption(
              icon: Icons.videocam,
              color: Colors.purple,
              title: 'Video',
              subtitle: 'Send a video',
              onTap: () => _handleFilePickerOption(context, 'video'),
            ),
            _buildFilePickerOption(
              icon: Icons.audiotrack,
              color: Colors.orange,
              title: 'Audio',
              subtitle: 'Send an audio file',
              onTap: () => _handleFilePickerOption(context, 'audio'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha((0.1 * 255).toInt()),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  void _handleFilePickerOption(BuildContext context, String type) {
    Navigator.pop(context);
    _pickFile(type);
  }

  // Add these methods to your ConversationPageState class:

  Widget _buildVideoPlayer(String videoPath) {
    if (!_cachedFiles.containsKey(videoPath)) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeVideoPlayer(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _videoController != null) {
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    if (_videoController?.dataSource == videoPath) {
      return;
    }

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(videoPath));

    try {
      await _videoController!.initialize();
      _videoController!.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      _showCustomToast("Error initializing video", isError: true);
    }
  }

  Future<void> _handleAudioPlayback(String audioPath) async {
    try {
      if (!_cachedFiles.containsKey(audioPath)) {
        _showCustomToast("Audio file not available", isError: true);
        return;
      }

      if (_audioPlayingStates[audioPath] ?? false) {
        await _audioPlayer.pausePlayer();
        setState(() {
          _audioPlayingStates[audioPath] = false;
        });
      } else {
        // Stop any currently playing audio
        if (_audioPlayer.isPlaying) {
          await _audioPlayer.stopPlayer();
          setState(() {
            _audioPlayingStates.forEach((key, value) {
              _audioPlayingStates[key] = false;
            });
          });
        }

        // Start playing the new audio
        await _audioPlayer.startPlayer(
          fromURI: audioPath,
          whenFinished: () {
            setState(() {
              _audioPlayingStates[audioPath] = false;
            });
          },
        );

        setState(() {
          _audioPlayingStates[audioPath] = true;
        });
      }
    } catch (e) {
      _showCustomToast("Error playing audio", isError: true);
      setState(() {
        _audioPlayingStates[audioPath] = false;
      });
    }
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    bool isSentByCurrentUser = message['sender_id'] == widget.senderId;
    final messageBgColor = isSentByCurrentUser ? Colors.blue : Colors.grey[200];
    final messageTextColor =
        isSentByCurrentUser ? Colors.white : Colors.black87;

    return Align(
      alignment:
          isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: messageBgColor,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isSentByCurrentUser ? const Radius.circular(5) : null,
            bottomLeft: !isSentByCurrentUser ? const Radius.circular(5) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).toInt()),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageContent(message, messageTextColor),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message['timestamp']),
              style: TextStyle(
                fontSize: 11,
                color: messageTextColor.withAlpha((0.6 * 255).toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> message, Color textColor) {
    switch (message['message_type']) {
      case 'text':
        return Text(
          message['content'],
          style: TextStyle(color: textColor, fontSize: 16),
        );

      case 'audio':
        return _buildAudioMessage(message['content'], textColor);

      case 'image':
        return _buildImageMessage(message['content']);

      case 'video':
        return _buildVideoMessage(message['content']);

      default:
        return Text(
          'Unsupported message type',
          style: TextStyle(
              color: textColor, fontSize: 16, fontStyle: FontStyle.italic),
        );
    }
  }

  Widget _buildAudioMessage(String audioPath, Color textColor) {
    bool isPlaying = _audioPlayingStates[audioPath] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: textColor,
            ),
            onPressed: () => _handleAudioPlayback(audioPath),
          ),
          Icon(
            Icons.audiotrack,
            color: textColor.withAlpha((0.6 * 255).toInt()),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Audio message',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(String imagePath) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imagePath),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          width: 200,
          height: 200,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoMessage(String videoPath) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _buildVideoPlayer(videoPath),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child:
                        Icon(Icons.broken_image, color: Colors.white, size: 50),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Text(
          'Chat with User ${widget.receiverId}',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image:
                const AssetImage("assets/images/conversation_background.webp"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              const Color.fromARGB(255, 255, 133, 10)
                  .withAlpha((0.2 * 255).toInt()),
              BlendMode.lighten,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: _messages.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(
                        _messages[_messages.length - 1 - index]);
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            offset: const Offset(0, -1),
            blurRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop_circle : Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey[600],
              size: 28,
            ),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: Colors.grey[600],
              size: 28,
            ),
            onPressed: _showFilePickerOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                if (_messageController.text.isNotEmpty) {
                  _sendMessage(
                    content: _messageController.text,
                    type: 'text',
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.closePlayer();
    _messageController.dispose();
    _videoController?.dispose();
    _cachedFiles.clear();
    super.dispose();
  }
}
