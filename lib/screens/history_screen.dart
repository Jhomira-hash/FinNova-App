import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_transaction_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('transacciones')
          .select('id, fecha, descripcion, monto, tipo, categorias(nombre)')
          .order('fecha', ascending: false);

      setState(() {
        _transactions = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar transacciones: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transacciones',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? const Center(child: Text('No hay transacciones registradas.'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final item = _transactions[index];
                final isExpense = item['tipo'] == 'gasto';
                final category = item['categorias']?['nombre'] ?? 'General';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isExpense ? Colors.red.shade50 : Colors.teal.shade50,
                      child: Icon(
                        isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isExpense ? Colors.red : Colors.teal,
                      ),
                    ),
                    title: Text(item['descripcion'] ?? category,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item['fecha']} • $category'),
                    trailing: Text(
                      '${isExpense ? '-' : '+'}S/ ${(item['monto'] as num).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isExpense ? Colors.red : Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF104070),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () async {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTransactionScreen()),
            );
            if (refresh == true) {
              _fetchTransactions(); // Recargar el historial
            }
        },
      ),
    );
  }
}