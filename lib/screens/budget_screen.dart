import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_category_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _isLoading = true;
  List _budgets = [];
  Map _spentByCategory = {};
  double _saldoActual = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchBudgets();
  }

  Color _getTrafficLightColor(double percentage) {
    if (percentage >= 0.85) {
      return const Color(0xFFEF4444); // Rojo
    } else if (percentage >= 0.50) {
      return const Color(0xFFF59E0B); // Amarillo
    } else {
      return const Color(0xFF10B981); // Verde
    }
  }

  Future<void> _fetchBudgets() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final perfil = await Supabase.instance.client
          .from('perfiles')
          .select('saldo_actual')
          .eq('user_id', user.id)
          .maybeSingle();

      final budgetsResponse = await Supabase.instance.client
          .from('presupuestos')
          .select('id, categoria_id, monto_limite, categorias(nombre)')
          .eq('user_id', user.id);

      final txResponse = await Supabase.instance.client
          .from('transacciones')
          .select('categoria_id, monto, fecha, tipo')
          .eq('user_id', user.id)
          .eq('tipo', 'gasto');

      final now = DateTime.now();
      final Map spentMap = {};

      for (var tx in txResponse) {
        final fechaTx = DateTime.tryParse(tx['fecha'].toString());
        if (fechaTx != null &&
            fechaTx.month == now.month &&
            fechaTx.year == now.year) {
          final catId = tx['categoria_id'];
          final monto = (tx['monto'] as num).toDouble();
          spentMap[catId] = (spentMap[catId] ?? 0.0) + monto;
        }
      }

      if (mounted) {
        setState(() {
          _saldoActual =
          perfil != null ? (perfil['saldo_actual'] as num).toDouble() : 0.0;
          _budgets = List.from(budgetsResponse);
          _spentByCategory = spentMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar presupuestos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Diálogo para EDITAR el monto límite de un presupuesto
  void _showEditBudgetDialog(Map budgetItem, double currentSpent) {
    final currentLimit = (budgetItem['monto_limite'] as num).toDouble();
    final categoryName = budgetItem['categorias']?['nombre'] ?? 'Categoría';
    final controller =
    TextEditingController(text: currentLimit.toStringAsFixed(2));

    // Calcular cuánto queda libre del Saldo Actual sin contar este presupuesto
    double otrosPresupuestos = 0.0;
    for (var b in _budgets) {
      if (b['id'] != budgetItem['id']) {
        otrosPresupuestos += (b['monto_limite'] as num).toDouble();
      }
    }
    final double maximoPermitido = _saldoActual - otrosPresupuestos;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Editar "$categoryName"',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: 'S/ ',
                labelText: 'Nuevo límite mensual',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Máximo disponible según tu saldo: S/ ${maximoPermitido.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
              final nuevoLimite = double.tryParse(controller.text.trim()) ?? 0.0;

              if (nuevoLimite <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('El monto debe ser mayor a S/ 0.')),
                );
                return;
              }
              if (nuevoLimite < currentSpent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFEF4444),
                    content: Text(
                        'No puede ser menor a lo ya gastado (S/ ${currentSpent.toStringAsFixed(2)}).'),
                  ),
                );
                return;
              }
              if (nuevoLimite > maximoPermitido) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFEF4444),
                    content: Text(
                        'Supera tu saldo disponible (Máx: S/ ${maximoPermitido.toStringAsFixed(2)}).'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await Supabase.instance.client
                  .from('presupuestos')
                  .update({'monto_limite': nuevoLimite}).eq('id', budgetItem['id']);

              _fetchBudgets();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Presupuesto actualizado.')),
                );
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Diálogo para ELIMINAR un presupuesto
  void _confirmDeleteBudget(Map budgetItem) {
    final categoryName = budgetItem['categorias']?['nombre'] ?? 'Categoría';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar presupuesto',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            '¿Seguro que deseas eliminar "$categoryName"? También se quitará de tus opciones al registrar gastos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client
                    .from('presupuestos')
                    .delete()
                    .eq('id', budgetItem['id']);

                _fetchBudgets();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Presupuesto eliminado.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo eliminar: $e')),
                  );
                }
              }
            },
            child:
            const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Presupuestos Activos',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF104070)),
            onPressed: _fetchBudgets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              if (_budgets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                      'No tienes presupuestos activos. ¡Crea uno nuevo!'),
                )
              else
                ..._budgets.map((b) {
                  final categoryName =
                      b['categorias']?['nombre'] ?? 'Categoría';
                  final catId = b['categoria_id'];
                  final limit = (b['monto_limite'] as num).toDouble();

                  final double spent =
                  (_spentByCategory[catId] ?? 0.0).toDouble();
                  final double percentage =
                  limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                  final double remaining = limit - spent;
                  final Color statusColor =
                  _getTrafficLightColor(percentage);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  categoryName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'S/ ${spent.toStringAsFixed(0)} / S/ ${limit.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: percentage >= 0.85
                                        ? statusColor
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      size: 20, color: Colors.grey),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditBudgetDialog(b, spent);
                                    } else if (value == 'delete') {
                                      _confirmDeleteBudget(b);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: Color(0xFF104070)),
                                          SizedBox(width: 8),
                                          Text('Editar monto'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Color(0xFFEF4444)),
                                          SizedBox(width: 8),
                                          Text('Eliminar',
                                              style: TextStyle(
                                                  color:
                                                  Color(0xFFEF4444))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey.shade200,
                            color: statusColor,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(percentage * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              remaining >= 0
                                  ? 'Restan S/ ${remaining.toStringAsFixed(0)}'
                                  : 'Excedido por S/ ${remaining.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: remaining >= 0
                                      ? Colors.grey
                                      : const Color(0xFFEF4444),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                        const CreateCategoryScreen()),
                  );
                  if (refresh == true) {
                    _fetchBudgets();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF104070),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Agregar nueva categoria',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}