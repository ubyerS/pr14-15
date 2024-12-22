import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import 'orders_screen.dart';
import 'registration_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoggedIn = false;
  String? userEmail;
  String? userId;
  List<CartItem> cartItems = [];
  double totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      setState(() {
        isLoggedIn = true;
        userEmail = session.user.email;
        userId = session.user.id;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId ?? '');
    }
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        setState(() {
          isLoggedIn = true;
          userEmail = response.user!.email;
          userId = response.user!.id;
        });
      } else {
        _showError('Неправильные данные для входа');
      }
    } catch (error) {
      _showError('Ошибка входа: $error');
    }
  }

  Future<void> _register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        setState(() {
          isLoggedIn = true;
          userEmail = response.user!.email;
          userId = response.user!.id;
        });
      } else {
        _showError('Ошибка регистрации');
      }
    } catch (error) {
      _showError('Ошибка регистрации: $error');
    }
  }


  Future<void> _logout() async {
    await SupabaseConfig.client.auth.signOut();
    setState(() {
      isLoggedIn = false;
      userEmail = null;
      userId = null;
    });
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double _calculateTotal() {
    double total = 0.0;
    for (var item in cartItems) {
      total += item.game.price * item.quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoggedIn
            ? _buildLoggedInContent()
            : _buildLoginForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'Пароль'),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _login,
          child: const Text('Войти'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegistrationScreen()),
            );
          },
          child: const Text('Зарегистрироваться'),
        ),
      ],
    );
  }

  Widget _buildLoggedInContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Вы вошли под профилем:',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            userEmail ?? 'Неизвестный пользователь',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: const Text('Выйти'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrdersScreen(
                    userId: userId ?? '',
                    cartItems: cartItems,
                    totalAmount: _calculateTotal(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: const Text('Мои заказы'),
          ),
        ],
      ),
    );
  }
}
