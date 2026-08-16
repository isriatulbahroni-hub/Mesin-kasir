import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';

class CartLine {
  final Product product;
  final int quantity;
  final int discount; // diskon nominal per-line (total untuk semua qty di line ini)

  const CartLine({required this.product, required this.quantity, this.discount = 0});

  int get grossSubtotal => product.sellingPrice * quantity;
  int get netSubtotal => (grossSubtotal - discount).clamp(0, grossSubtotal);

  CartLine copyWith({int? quantity, int? discount}) => CartLine(
        product: product,
        quantity: quantity ?? this.quantity,
        discount: discount ?? this.discount,
      );
}

class CartState {
  final List<CartLine> lines;
  final int transactionDiscount; // diskon nominal tambahan untuk seluruh transaksi
  final String note;

  const CartState({this.lines = const [], this.transactionDiscount = 0, this.note = ''});

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  int get subtotal => lines.fold(0, (sum, l) => sum + l.grossSubtotal);
  int get lineDiscountTotal => lines.fold(0, (sum, l) => sum + l.discount);
  int get totalDiscount => lineDiscountTotal + transactionDiscount;
  int get total => (subtotal - totalDiscount).clamp(0, subtotal);

  CartState copyWith({List<CartLine>? lines, int? transactionDiscount, String? note}) =>
      CartState(
        lines: lines ?? this.lines,
        transactionDiscount: transactionDiscount ?? this.transactionDiscount,
        note: note ?? this.note,
      );
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void addProduct(Product product) {
    final idx = state.lines.indexWhere((l) => l.product.id == product.id);
    if (idx == -1) {
      state = state.copyWith(lines: [...state.lines, CartLine(product: product, quantity: 1)]);
    } else {
      _setQuantity(idx, state.lines[idx].quantity + 1);
    }
  }

  void incrementLine(int index) => _setQuantity(index, state.lines[index].quantity + 1);

  void decrementLine(int index) {
    final newQty = state.lines[index].quantity - 1;
    if (newQty <= 0) {
      removeLine(index);
    } else {
      _setQuantity(index, newQty);
    }
  }

  void setLineDiscount(int index, int discount) {
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(discount: discount);
    state = state.copyWith(lines: lines);
  }

  void setTransactionDiscount(int discount) {
    state = state.copyWith(transactionDiscount: discount);
  }

  void setNote(String note) => state = state.copyWith(note: note);

  void removeLine(int index) {
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void _setQuantity(int index, int qty) {
    final maxStock = state.lines[index].product.stock;
    final clamped = (maxStock != null) ? qty.clamp(1, maxStock) : qty;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(quantity: clamped);
    state = state.copyWith(lines: lines);
  }

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);
