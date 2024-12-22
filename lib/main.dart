import 'package:flutter/material.dart';
import './screens/game_store_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/favorite_screen.dart';
import './screens/cart_screen.dart';
import './screens/profile_screen.dart';
import './screens/orders_screen.dart';
import 'screens/chat_screen.dart';
import '../models/game.dart';
import '../widgets/bottom_navigation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Store',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Game> games = [];
  List<Game> favoriteGames = [];
  List<CartItem> cartItems = [];
  final String baseUrl = "http://localhost:8080";

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          games = data.map((json) => Game.fromJson(json)).toList();
        });
      } else {
        throw Exception('Ошибка загрузки продуктов: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка загрузки игр: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить игры: $e')),
      );
    }
  }

  void _addToCart(Game game) {
    setState(() {
      final existingItem = cartItems.firstWhere(
        (item) => item.game == game,
        orElse: () => CartItem(game, 0),
      );
      if (existingItem.quantity == 0) {
        cartItems.add(CartItem(game, 1));
      } else {
        existingItem.quantity++;
      }
    });
  }

  void _addNewGame(Game game) {
    setState(() {
      games.add(game);
    });
  }

  void toggleFavorite(Game game) {
    setState(() {
      favoriteGames.contains(game)
          ? favoriteGames.remove(game)
          : favoriteGames.add(game);
    });
  }

  void _onOrderCompleted() {
    setState(() {
      cartItems.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заказ оформлен и корзина очищена!')),
    );
  }

  double get totalAmount {
    return cartItems.fold(
        0.0, (sum, item) => sum + (item.game.price * item.quantity));
  }

  double _calculateTotal() {
    double total = 0;
    for (var item in cartItems) {
      total += item.game.price * item.quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final totalAmount = _calculateTotal();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Авторизация')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Пожалуйста, войдите в систему', style: TextStyle(fontSize: 18)),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: const Text('Перейти к авторизации'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> screens = [
      GameStoreScreen(
        games: games,
        toggleFavorite: toggleFavorite,
        favoriteGames: favoriteGames,
        onAddToCart: _addToCart,
        onAddGame: _addNewGame,
      ),
      FavoriteScreen(
        favoriteGames: favoriteGames,
        toggleFavorite: toggleFavorite,
        addToCart: _addToCart,
      ),
      CartScreen(
        cartItems: cartItems,
        onOrderCompleted: _onOrderCompleted,
      ),
      const ProfileScreen(),
      OrdersScreen(
        userId: userId,
        cartItems: cartItems,
        totalAmount: totalAmount,
      ),
    ];

    return Scaffold(
      body: games.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : screens[_currentIndex],
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTabTapped: (index) => setState(() => _currentIndex = index),
        favoriteCount: favoriteGames.length,
        cartCount: cartItems.length,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen()),
          );
        },
        
        child: Icon(Icons.chat),
      ),
    );
  }
}
