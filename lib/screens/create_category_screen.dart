import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateCategoryScreen extends StatefulWidget {
  const CreateCategoryScreen({super.key});

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  String _selectedIcon = 'house';
  bool _isLoading = false;
  double _saldoActual = 0.0;
  double _presupuestosAsignados = 0.0;

  final List _icons = [
    {'name': 'Casa', 'icon': Icons.home_outlined, 'id': 'house'},
    {'name': 'Universidad', 'icon': Icons.school_outlined, 'id': 'school'},
    {'name': 'Dispensas', 'icon': Icons.shopping_cart_outlined, 'id': 'shopping'},
    {'name': 'Salidas', 'icon': Icons.auto_awesome_outlined, 'id': 'star'},
    {'name': 'Trabajo', 'icon': Icons.work_outline, 'id': 'work'},
    {'name': 'Internet', 'icon': Icons.wifi, 'id': 'wifi'},
    {'name': 'Luz', 'icon': Icons.lightbulb_outline, 'id': 'light'},
    {'name': 'Otros', 'icon': Icons.add, 'id': 'other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
  }

  Future<void> _loadUserBalance() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final perfil = await Supabase.instance.client
          .from('perfiles')
          .select('saldo_actual')
          .eq('user_id', user.id)
          .maybeSingle();

      final budgets = await Supabase.instance.client
          .from('presupuestos')
          .select('monto_limite')
          .eq('user_id', user.id);

      double totalAsignado = 0.0;
      for (var b in budgets) {
        totalAsignado += (b['monto_limite'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _saldoActual =
          perfil != null ? (perfil['saldo_actual'] as num).toDouble() : 0.0;
          _presupuestosAsignados = totalAsignado;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    final budgetText = _budgetController.text.trim();

    if (name.isEmpty || budgetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor completa el nombre y el presupuesto.')),
      );
      return;
    }

    final budgetAmount = double.tryParse(budgetText) ?? 0.0;

    if (budgetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El presupuesto debe ser mayor a S/ 0.')),
      );
      return;
    }

    if (budgetAmount > _saldoActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
              'El monto (S/ ${budgetAmount.toStringAsFixed(2)}) no puede superar tu Saldo Actual (S/ ${_saldoActual.toStringAsFixed(2)}).'),
        ),
      );
      return;
    }

    final double disponibleParaAsignar = _saldoActual - _presupuestosAsignados;
    if (budgetAmount > disponibleParaAsignar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFF59E0B),
          content: Text(
              'Ya tienes S/ ${_presupuestosAsignados.toStringAsFixed(2)} asignados en otras categorías. Solo te quedan S/ ${disponibleParaAsignar.toStringAsFixed(2)} disponibles.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;

      final categoryResponse = await Supabase.instance.client
          .from('categorias')
          .insert({
        'nombre': name,
        'tipo': 'gasto',
      })
          .select()
          .single();

      final categoryId = categoryResponse['id'];

      await Supabase.instance.client.from('presupuestos').insert({
        'user_id': user?.id,
        'categoria_id': categoryId,
        'monto_limite': budgetAmount,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Categoría y presupuesto creados con éxito.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double disponible =
    (_saldoActual - _presupuestosAsignados).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nueva categoria',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nombre',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ej. Internet',
                fillColor: const Color(0xFFF4F5F7),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Detalles de la nueva categoría...',
                fillColor: const Color(0xFFF4F5F7),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Elegir Icono',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((item) {
                final isSelected = _selectedIcon == item['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = item['id']),
                  child: Container(
                    width: 75,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF104070)
                          : const Color(0xFFE8EEF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          item['icon'],
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF104070),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['name'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF104070),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Presupuesto destinado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _budgetController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: 'S/ ',
                hintText: '100.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo total',
                          style: TextStyle(color: Colors.black87)),
                      Text(
                        'S/ ${_saldoActual.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Disponible para asignar',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        'S/ ${disponible.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Estado inicial: 0% consumido (Verde)',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _saveCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF104070),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Crear categoria',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}