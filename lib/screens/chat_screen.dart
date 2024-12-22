import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref('messages');
  firebase_auth.User? _firebaseUser;

  @override
  void initState() {
    super.initState();
    _firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  }

  Future<void> sendMessage(String message) async {
    try {
      await _messagesRef.push().set({
        'sender': Supabase.instance.client.auth.currentUser?.id ?? _firebaseUser?.email,
        'message': message,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки сообщения: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final message = _messageController.text.trim();

    // Получаем userId из Supabase, если доступно
    final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;

    // Проверка: есть ли авторизованный пользователь
    if (supabaseUserId == null && _firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы должны быть авторизованы для отправки сообщений')),
      );
      return;
    }

    // Используем sendMessage для отправки сообщения
    await sendMessage(message);

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чат с продавцом')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _messagesRef.orderByChild('timestamp').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final event = snapshot.data;
                final messagesData = event?.snapshot.value;

                if (messagesData == null) {
                  return const Center(child: Text('Нет сообщений'));
                }

                // Преобразуем данные в Map
                final messagesMap = (messagesData as Map<dynamic, dynamic>)
                    .map((key, value) => MapEntry(key as String, value as Map<dynamic, dynamic>));

                final messageWidgets = messagesMap.entries.map((entry) {
                  final sender = entry.value['sender'] ?? 'Неизвестный';
                  final message = entry.value['message'] ?? '';
                  final isCurrentUser =
                      sender == Supabase.instance.client.auth.currentUser?.id || sender == _firebaseUser?.email;

                  return ListTile(
                    title: Text(
                      sender,
                      style: TextStyle(
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentUser ? Colors.blue : Colors.black,
                      ),
                    ),
                    subtitle: Text(message),
                  );
                }).toList();

                return ListView(
                  children: messageWidgets,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Введите сообщение'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}