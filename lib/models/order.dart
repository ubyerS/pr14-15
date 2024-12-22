class Order {
  final String id;
  final String status;
  final double total;
  final DateTime createdAt;
  final List<Product> products;

  Order({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.products,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['order_id'] as String,
      status: json['status'] as String,
      total: double.parse(json['total']),
      createdAt: DateTime.parse(json['created_at']),
      products: (json['products'] as List)
          .map((product) => Product.fromJson(product))
          .toList(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final int quantity;

  Product({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['product_id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
    );
  }
}
