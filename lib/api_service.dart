import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/game.dart';
import '../models/order.dart';

class ApiService {
  final String baseUrl = "http://192.168.1.6:8080";
  final Dio dio = Dio(BaseOptions(
    baseUrl: "http://192.168.1.6:8080",
  
  ));

  ApiService() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('Запрос: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('Ответ: ${response.statusCode} ${response.data}');
        return handler.next(response);
      },
      onError: (DioError e, handler) {
        print('Ошибка: ${e.message}');
        return handler.next(e);
      },
    ));
  }

  Future<List<Game>> fetchGames() async {
    try {
      final response = await dio.get('$baseUrl/products');
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((item) => Game.fromJson(item)).toList();
      } else {
        throw Exception('Ошибка при загрузке данных');
      }
    } catch (e) {
      throw Exception('Не удалось загрузить игры: $e');
    }
  }

  Future<Game> createGame(Game game) async {
    try {
      final response = await dio.post(
        '$baseUrl/products',
        data: game.toJson(),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 201) {
        return Game.fromJson(response.data);
      } else {
        throw Exception('Не удалось создать игру');
      }
    } catch (e) {
      throw Exception('Ошибка при создании игры: $e');
    }
  }

  Future<void> updateFavoriteStatus(int productId, bool isFavorite) async {
    try {
      await dio.put(
        '$baseUrl/products/$productId/favorite',
        data: {'is_favorite': isFavorite},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (e) {
      throw Exception('Ошибка при обновлении статуса избранного товара: $e');
    }
  }

  Future<void> updateCart(int productId, int quantity) async {
    try {
      await dio.post(
        '$baseUrl/cart',
        data: {'product_id': productId, 'quantity': quantity},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (e) {
      throw Exception('Ошибка при обновлении корзины: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      await dio.delete('$baseUrl/cart');
    } catch (e) {
      throw Exception('Ошибка при очистке корзины: $e');
    }
  }

  Future<List<Order>> fetchOrders(String userId) async {
  try {
    final response = await dio.get('$baseUrl/orders/$userId');
    if (response.statusCode == 200) {
      List<dynamic> data = response.data;
      return data.map((item) => Order.fromJson(item)).toList();
    } else {
      throw Exception('Ошибка при загрузке заказов');
    }
  } catch (e) {
    print("Ошибка запроса: $e");
    throw Exception('Не удалось загрузить заказы');
  }
}


 Future<List<dynamic>> fetchOrderDetails(String orderId) async {
  try {
    final response = await dio.get('$baseUrl/order_products/$orderId');
    if (response.statusCode == 200) {
      return response.data ?? [];
    } else {
      throw Exception('Ошибка при загрузке продуктов заказа');
    }
  } catch (e) {
    throw Exception('Не удалось загрузить продукты заказа: $e');
  }
}


  Future<Order> createOrder(String userId, double total) async {
  try {
    final response = await dio.post(
      '$baseUrl/orders',
      data: {
        'user_id': userId,
        'total': total,
        'status': 'Pending',
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode == 201) {
      return Order.fromJson(response.data);
    } else {
      throw Exception('Ошибка при создании заказа');
    }
  } catch (e) {
    throw Exception('Не удалось создать заказ: $e');
  }
}


Future<Order> placeOrder(String userId, double total) async {
  try {
    final order = await createOrder(userId, total);
    print('Заказ успешно оформлен, ID заказа (UUID): ${order.id}');
    return order;
  } catch (e) {
    print('Ошибка при оформлении заказа: $e');
    throw Exception('Не удалось оформить заказ: $e');
  }
}


}
