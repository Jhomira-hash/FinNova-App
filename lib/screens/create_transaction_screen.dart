import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId; // Inicia en null para obligar a seleccionar
  String _paymentMethod = 'Yape';
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  List _userCategories = [];

  @override
  void initState() {
    super.initState();
    _fetchUserCategoriesAndLimits();
  }

  Future<void> _fetchUserCategoriesAndLimits() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final budgetsResponse = await Supabase.instance.client
          .from('presupuestos')
          .select('categoria_id, monto_limite, categorias(id, nombre, tipo)')
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
          spentMap[catId] =
              (spentMap[catId] ?? 0.0) + (tx['monto'] as num).toDouble();
        }
      }

      final List loadedCats = [];
      final Set seenIds = {};

      for (var item in budgetsResponse) {
        final catData = item['categorias'];
        if (catData != null && !seenIds.contains(catData['id'])) {
          seenIds.add(catData['id']);
          final double limit = (item['monto_limite'] as num).toDouble();
          final double spent = (spentMap[catData['id']] ?? 0.0).toDouble();

          loadedCats.add({
            'id': catData['id'],
            'nombre': catData['nombre'],
            'tipo': catData['tipo'] ?? 'gasto',
            'monto_limite': limit,
            'gastado': spent,
            'disponible': limit - spent,
          });
        }
      }

      if (mounted) {
        setState(() {
          _userCategories = loadedCats;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tus categorías: $e')),
        );
      }
    }
  }

  Future<void> _saveTransaction() async {
    // Validación obligatoria de Categoría
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Por favor selecciona una categoría obligatoria.'),
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un monto.')),
      );
      return;
    }

    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor a S/ 0.00.')),
      );
      return;
    }

    final selectedCat =
    _userCategories.firstWhere((c) => c['id'] == _selectedCategoryId);
    final String type = selectedCat['tipo'] ?? 'gasto';
    final double limit = (selectedCat['monto_limite'] as num).toDouble();
    final double spent = (selectedCat['gastado'] as num).toDouble();
    final double available = limit - spent;

    if (type == 'gasto' && amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          content: Text(
            'El monto (S/ ${amount.toStringAsFixed(2)}) supera el límite disponible de "${selectedCat['nombre']}" (Te quedan S/ ${available.toStringAsFixed(2)} de S/ ${limit.toStringAsFixed(2)}).',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('transacciones').insert({
        'user_id': user?.id,
        'fecha': _selectedDate.toIso8601String().split('T')[0],
        'descripcion': _descriptionController.text.trim(),
        'categoria_id': _selectedCategoryId,
        'monto': amount,
        'tipo': type,
        'metodo_pago': _paymentMethod,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transacción guardada exitosamente.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar transacción: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentMethodModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempMethod = _paymentMethod;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Método de pago',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Efectivo'),
                    value: 'Efectivo',
                    groupValue: tempMethod,
                    onChanged: (value) =>
                        setModalState(() => tempMethod = value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Banca Móvil'),
                    value: 'Banca Móvil',
                    groupValue: tempMethod,
                    onChanged: (value) =>
                        setModalState(() => tempMethod = value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Yape'),
                    value: 'Yape',
                    groupValue: tempMethod,
                    onChanged: (value) =>
                        setModalState(() => tempMethod = value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Otro'),
                    value: 'Otro',
                    groupValue: tempMethod,
                    onChanged: (value) =>
                        setModalState(() => tempMethod = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF104070),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() => _paymentMethod = tempMethod);
                    Navigator.pop(context);
                  },
                  child:
                  const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map? currentCat;
    if (_selectedCategoryId != null && _userCategories.isNotEmpty) {
      currentCat = _userCategories.firstWhere(
            (c) => c['id'] == _selectedCategoryId,
        orElse: () => null,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nueva transacción',
            style:
            TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FECHA
            const Text('Fecha',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: Color(0xFF104070)),
                        const SizedBox(width: 8),
                        Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      ],
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // DESCRIPCIÓN
            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Detalles del gasto...',
                fillColor: const Color(0xFFF4F5F7),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // CATEGORÍA OBLIGATORIA (CON PUNTITO ROJO)
            Row(
              children: [
                const Text('Categoría',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), // Puntito rojo obligatorio
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isLoadingCategories)
              const CircularProgressIndicator()
            else if (_userCategories.isEmpty)
              const Text(
                'Aún no tienes categorías creadas. Ve a Presupuesto para crear una.',
                style: TextStyle(color: Colors.redAccent),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _userCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat['id'];
                  return ChoiceChip(
                    label: Text(cat['nombre']),
                    selected: isSelected,
                    selectedColor: const Color(0xFF104070),
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryId = selected ? cat['id'] : null;
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // MONTO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monto',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (currentCat != null)
                  Text(
                    'Disponible: S/ ${(currentCat['disponible'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: 'S/ ',
                hintText: '100.00',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // SELECTOR MÉTODO DE PAGO
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              leading: const Icon(Icons.account_circle_outlined,
                  color: Color(0xFF104070)),
              title:
              const Text('Método de pago', style: TextStyle(fontSize: 14)),
              subtitle: Text(_paymentMethod,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF104070))),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showPaymentMethodModal,
            ),
            const SizedBox(height: 12),

            // BOTÓN REGISTRAR CON IA (LISTO PARA EL MÓDULO DE TU COMPAÑERA)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              leading: const Icon(Icons.auto_awesome,
                  color: Color(0xFF104070)),
              title: const Text('Registrar con IA',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Escanear boleta o factura',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Conectar aquí la pantalla/modal de registro con IA
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Módulo de registro con IA próximamente.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // BOTÓN CONTINUAR
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed:
              _userCategories.isEmpty ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF104070),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONTINUAR',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}