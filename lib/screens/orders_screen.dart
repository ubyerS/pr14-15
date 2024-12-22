import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'cart_screen.dart';

class OrdersScreen extends StatefulWidget {
  final String userId;
  final List<CartItem> cartItems;
  final double totalAmount;

  const OrdersScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final String baseUrl = "http://192.168.1.6:8080";
  final Dio dio = Dio();
  List<dynamic> orders = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

 Future<void> _fetchOrders() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userId = user.id;
      print("Текущий userId: $userId");
      final url = '$baseUrl/orders/$userId';
      print('Запрос к серверу: $url');
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> ordersList = response.data;


        final ordersWithProducts = await Future.wait(
          ordersList.map((order) async {
            final orderId = order['order_id'];
            if (orderId == null) {
              print("Ошибка: отсутствует order_id в заказе: $order");
              return order;
            }

            final productUrl = '$baseUrl/orders/$orderId/products';
            print('Запрос на продукты для заказа $orderId: $productUrl');

            try {
              final productResponse = await dio.get(productUrl);

              if (productResponse.statusCode == 200) {
                order['products'] = productResponse.data;
              } else {
                print("Ошибка загрузки продуктов для заказа $orderId: ${productResponse.statusCode}");
                order['products'] = [];
              }
            } catch (e) {
              print("Ошибка при получении продуктов для заказа $orderId: $e");
              order['products'] = [];
            }

            return order;
          }),
        );

        setState(() {
          orders = ordersWithProducts;
        });

      } else {
        throw Exception('Ошибка при загрузке заказов, статус: ${response.statusCode}');
      }
    } else {
      print("Пользователь не авторизован");
      throw Exception('Пользователь не авторизован');
    }
  } catch (e) {
    print("Ошибка при загрузке заказов: $e");
    setState(() {
      errorMessage = 'Ошибка: $e';
    });
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}




  Future<void> _showOrderDetails(String orderId) async {
  try {
    final response = await dio.get('$baseUrl/order_products/$orderId');
    if (response.statusCode == 200) {
      final List products = response.data ?? [];
      if (products.isEmpty) {
        print("Заказ $orderId не содержит продуктов");
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Детали заказа'),
          content: products.isNotEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: products.map<Widget>((product) {
                    return ListTile(
                      title: Text('Продукт: ${product['name']} (ID: ${product['product_id']})'),
                      subtitle: Text('Количество: ${product['quantity']} | Цена: ${product['price']}'),
                    );
                  }).toList(),
                )
              : const Text('Этот заказ не содержит продуктов.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } else {
      throw Exception('Ошибка при загрузке продуктов для заказа');
    }
  } catch (e) {
    print("Ошибка при загрузке продуктов для заказа: $e");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text('Не удалось загрузить детали заказа: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}


  Future<void> _cancelOrder(String orderId) async {
    try {
      final response = await dio.delete('$baseUrl/orders/$orderId');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ успешно отменён')),
        );
        _fetchOrders();
      } else {
        throw Exception('Ошибка при отмене заказа');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отмене заказа: $e')),

      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : orders.isEmpty
                  ? const Center(child: Text('У вас пока нет заказов'))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            title: Text('Заказ #${order['order_id']}'),
                            subtitle: Text('Дата: ${order['created_at']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _cancelOrder(order['order_id']),
                            ),
                            onTap: () => _showOrderDetails(order['order_id']),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _placeOrder,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _placeOrder() async {
    try {
      final response = await dio.post(
        '$baseUrl/orders',
        data: {
          'user_id': widget.userId,
          'total': widget.totalAmount,
          'status': 'Pending',
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final orderId = response.data['order_id'];
        print('Заказ успешно оформлен! ID заказа: $orderId');

        for (var item in widget.cartItems) {
          await Supabase.instance.client.from('order_products').insert({
            'order_id': orderId,
            'product_id': item.game.productId,
            'quantity': item.quantity,
          });
        }

        _fetchOrders();
      } else {
        throw Exception('Ошибка при оформлении заказа');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при оформлении заказа: $e')),
      );
    }
  }
}
