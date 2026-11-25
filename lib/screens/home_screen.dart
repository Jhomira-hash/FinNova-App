import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'history_screen.dart';
import 'analysis_screen.dart';
import 'budget_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  double _saldoActual = 0.0;
  double _gastoMensual = 0.0;
  var _recentTransactions = [];
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener o crear el perfil con el Saldo Actual del usuario
      final perfilData = await Supabase.instance.client
          .from('perfiles')
          .select('saldo_actual')
          .eq('user_id', user.id)
          .maybeSingle();

      double saldo = 0.0;
      if (perfilData != null) {
        saldo = (perfilData['saldo_actual'] as num).toDouble();
      } else {
        await Supabase.instance.client.from('perfiles').insert({
          'user_id': user.id,
          'saldo_actual': 0.0,
        });
      }

      // 2. Obtener todas las transacciones del usuario
      final txResponse = await Supabase.instance.client
          .from('transacciones')
          .select('id, fecha, descripcion, monto, tipo, categorias(nombre)')
          .eq('user_id', user.id)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      final allTransactions = List.from(txResponse);
      // 3. Calcular el Gasto Mensual
      final now = DateTime.now();
      double sumaGastosMes = 0.0;

      for (var tx in allTransactions) {
        if (tx['tipo'] == 'gasto') {
          final fechaTx = DateTime.tryParse(tx['fecha'].toString());
          if (fechaTx != null &&
              fechaTx.month == now.month &&
              fechaTx.year == now.year) {
            sumaGastosMes += (tx['monto'] as num).toDouble();
          }
        }
      }

      setState(() {
        _saldoActual = saldo;
        _gastoMensual = sumaGastosMes;
        _recentTransactions = allTransactions.take(4).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditBalanceDialog() {
    final controller = TextEditingController(
      text: _saldoActual > 0 ? _saldoActual.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Actualizar Saldo Actual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: 'S/ ',
            hintText: 'Ej. 2450.80',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF104070),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nuevoSaldo = double.tryParse(controller.text.trim()) ?? 0.0;
              final user = Supabase.instance.client.auth.currentUser;
              Navigator.pop(context);

              if (user != null) {
                await Supabase.instance.client.from('perfiles').upsert({
                  'user_id': user.id,
                  'saldo_actual': nuevoSaldo,
                });
                _loadDashboardData();
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'Usuario';
    final double ahorroMensual = _saldoActual - _gastoMensual;

    final List<Widget> pages = [
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TARJETA SALDO ACTUAL
              GestureDetector(
                onTap: _showEditBalanceDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF104070).withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'SALDO ACTUAL',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF104070)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'S/ ${_saldoActual.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF104070),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Toca aquí para actualizar tu monto',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // TARJETAS DE GASTO Y AHORRO MENSUAL
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gasto Mensual',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(
                            'S/ ${_gastoMensual.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ahorro Mensual',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(
                            'S/ ${ahorroMensual.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ahorroMensual >= 0
                                  ? Colors.teal
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // TRANSACCIONES RECIENTES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transacciones Recientes',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentIndex = 1);
                    },
                    child: const Text('Ver todo'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_recentTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Aún no tienes transacciones este mes.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ..._recentTransactions.map((tx) {
                  final isExpense = tx['tipo'] == 'gasto';
                  final categoryName =
                      tx['categorias']?['nombre'] ?? 'General';
                  final description = (tx['descripcion'] != null &&
                      tx['descripcion'].toString().isNotEmpty)
                      ? tx['descripcion']
                      : categoryName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isExpense
                            ? Colors.red.shade50
                            : Colors.teal.shade50,
                        child: Icon(
                          isExpense
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: isExpense ? Colors.red : Colors.teal,
                        ),
                      ),
                      title: Text(
                        description,
                        style:
                        const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${tx['fecha']} • $categoryName'),
                      trailing: Text(
                        '${isExpense ? '-' : '+'}S/ ${(tx['monto'] as num).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isExpense ? Colors.red : Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),

      // Pestaña 1: Historial
      const HistoryScreen(),

      // Pestaña 2: Análisis
      const AnalysisScreen(),

      // Pestaña 3: Presupuesto
      const BudgetScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _currentIndex == 0
          ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Bienvenido, $userName!',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Text(
              'Resumen de tus finanzas',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      )
          : null,
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            _loadDashboardData();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF104070),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Historial'),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), label: 'Análisis'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Presupuesto'),
        ],
      ),
    );
  }
}