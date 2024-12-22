import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'game_store_screen.dart';
import 'favorite_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../models/game.dart';
import '../widgets/bottom_navigation.dart';
import '../api_service.dart';
import 'orders_screen.dart';
import 'chat_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Game> favoriteGames = [];
  List<CartItem> cartItems = [];
  List<Game> games = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    try {
      final fetchedGames = await _apiService.fetchGames();
      print("Игры загружены: $fetchedGames");
      setState(() {
        games = fetchedGames;
      });
    } catch (error) {
      print('Ошибка загрузки игр: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить игры')),
      );
    }
  }

  Future<void> toggleFavorite(Game game) async {
    try {
      setState(() {
        favoriteGames.contains(game)
            ? favoriteGames.remove(game)
            : favoriteGames.add(game);
      });
      await _apiService.updateFavoriteStatus(game.productId, favoriteGames.contains(game));
    } catch (error) {
      print('Ошибка обновления избранного: $error');
    }
  }

  Future<void> _addToCart(Game game) async {
    try {
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
      await _apiService.updateCart(game.productId, 1);
    } catch (error) {
      print('Ошибка добавления в корзину: $error');
    }
  }

  Future<void> _addNewGame(Game game) async {
    try {
      final newGame = await _apiService.createGame(game);
      setState(() {
        games.add(newGame);
      });
    } catch (error) {
      print('Ошибка добавления игры: $error');
    }
  }

  void _onOrderCompleted() async {
    try {
      await _apiService.clearCart();
      setState(() {
        cartItems.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ оформлен и корзина очищена!')),
      );
    } catch (error) {
      print('Ошибка при оформлении заказа: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось оформить заказ')),
      );
    }
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
      ];

      return Scaffold(
        appBar: AppBar(
          title: const Text('Game Store'),
          actions: [
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),
        body: screens[_currentIndex],
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
          tooltip: 'Чат с продавцом',
          child: Icon(Icons.chat),
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
      ChatScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Store'),
      ),
      body: screens[_currentIndex],
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
        tooltip: 'Чат с продавцом',
        child: Icon(Icons.chat),
      ),
    );
  }
}