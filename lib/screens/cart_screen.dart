import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game.dart';
import 'orders_screen.dart';

class CartItem {
  final Game game;
  int quantity;

  CartItem(this.game, this.quantity);
}

class CartScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final Function onOrderCompleted;

  const CartScreen({super.key, required this.cartItems, required this.onOrderCompleted});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final String baseUrl = "http://192.168.1.6:8080";

  Future<void> _removeItem(CartItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userId = user.id;
    try {
      setState(() {
        widget.cartItems.remove(item);
      });

      final response = await Supabase.instance.client
          .from('cart')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', item.game.productId.toString());

      if (response.error != null) {
        throw Exception('Ошибка при удалении товара из корзины');
      }
    } catch (error) {
      print('Ошибка при удалении товара из корзины: $error');
    }
  }

  Future<void> _incrementQuantity(CartItem item) async {
    setState(() {
      item.quantity++;
    });

    await _updateCart(item.game.productId, item.quantity);
  }

  Future<void> _decrementQuantity(CartItem item) async {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        widget.cartItems.remove(item);
      }
    });

    await _updateCart(item.game.productId, item.quantity);
  }

  Future<void> _updateCart(int gameId, int quantity) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userId = user.id;

    try {
      final response = await Supabase.instance.client.from('cart').upsert({
        'user_id': userId,
        'product_id': gameId.toString(),
        'quantity': quantity,
      });

      if (response.error != null) {
        throw Exception('Ошибка при обновлении корзины');
      }
    } catch (error) {
      print('Ошибка при обновлении корзины: $error');
    }
  }

  double _calculateTotal() {
    return widget.cartItems.fold(
      0,
      (total, item) => total + item.game.price * item.quantity,
    );
  }

  Future<void> _completeOrder() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    print("Ошибка: пользователь не авторизован");
    return;
  }

  final userId = user.id;

  final totalAmount = _calculateTotal();

  try {
    final orderResponse = await Supabase.instance.client.from('orders').insert({
      'user_id': userId,
      'total': totalAmount,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    print("Ответ Supabase: $orderResponse");

    final orderId = orderResponse?['order_id'];
    if (orderId == null) {
      print("Ошибка: ID заказа отсутствует");
      return;
    }

    for (var item in widget.cartItems) {
      await Supabase.instance.client.from('order_products').insert({
        'order_id': orderId,
        'product_id': item.game.productId.toString(),
        'quantity': item.quantity,
      });
    }

    widget.onOrderCompleted();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdersScreen(
          userId: userId,
          cartItems: widget.cartItems,
          totalAmount: totalAmount,
        ),
      ),
    );
  } catch (error) {
    print('Ошибка при оформлении заказа: $error');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: widget.cartItems.isEmpty
          ? const Center(child: Text('Корзина пуста'))
          : ListView.builder(
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                return Slidable(
                  key: ValueKey(item.game.productId),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => _removeItem(item),
                        backgroundColor: Colors.red,
                        icon: Icons.delete,
                        label: 'Удалить',
                      ),
                    ],
                  ),
                  child: Card(
                    margin: const EdgeInsets.all(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(item.game.imagePath),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.game.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${item.game.price} \$'),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _decrementQuantity(item),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _incrementQuantity(item),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Итог: ${_calculateTotal().toStringAsFixed(2)} \$',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _completeOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Оформить заказ'),
            ),
          ],
        ),
      ),
    );
  }
}
