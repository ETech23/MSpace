import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../booking/domain/entities/booking_entity.dart';

class InvoiceLineItem {
  InvoiceLineItem({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    this.details = '',
  });

  final String title;
  final int quantity;
  final double unitPrice;
  final String details;

  double get total => quantity * unitPrice;
}

class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    this.booking,
  });

  final BookingEntity? booking;

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _providerNameController;
  late final TextEditingController _providerEmailController;
  late final TextEditingController _providerPhoneController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _clientEmailController;
  late final TextEditingController _clientPhoneController;
  late final TextEditingController _serviceTitleController;
  late final TextEditingController _serviceDescriptionController;
  late final TextEditingController _notesController;

  late DateTime _issueDate;
  late DateTime _dueDate;
  late List<InvoiceLineItem> _items;

  final _currency = NumberFormat.currency(locale: 'en_NG', symbol: 'NGN ');

  bool get _isManualInvoice => widget.booking == null;

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    final basePrice = booking?.finalPrice ?? booking?.estimatedPrice ?? 0;

    _invoiceNumberController = TextEditingController(
      text: booking != null
          ? 'INV-${booking.id.substring(0, 8).toUpperCase()}'
          : 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
    );
    _providerNameController = TextEditingController(
      text: booking?.artisanName ?? '',
    );
    _providerEmailController = TextEditingController(
      text: booking?.artisanEmail ?? '',
    );
    _providerPhoneController = TextEditingController(
      text: booking?.artisanPhone ?? '',
    );
    _clientNameController = TextEditingController(
      text: booking?.customerName ?? '',
    );
    _clientEmailController = TextEditingController(
      text: booking?.customerEmail ?? '',
    );
    _clientPhoneController = TextEditingController(
      text: booking?.customerPhone ?? '',
    );
    _serviceTitleController = TextEditingController(
      text: booking?.serviceType ?? '',
    );
    _serviceDescriptionController = TextEditingController(
      text: booking?.description ?? '',
    );
    _notesController = TextEditingController(
      text: booking?.customerNotes ?? '',
    );
    _issueDate = DateTime.now();
    _dueDate = booking?.scheduledDate ?? DateTime.now().add(const Duration(days: 7));
    _items = [
      InvoiceLineItem(
        title: booking?.serviceType ?? 'Service',
        quantity: 1,
        unitPrice: basePrice.toDouble(),
        details: booking?.description ?? '',
      ),
    ];
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _providerNameController.dispose();
    _providerEmailController.dispose();
    _providerPhoneController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _serviceTitleController.dispose();
    _serviceDescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _upsertItem({int? index}) async {
    final existing = index != null ? _items[index] : null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final detailsController =
        TextEditingController(text: existing?.details ?? '');
    final quantityController =
        TextEditingController(text: (existing?.quantity ?? 1).toString());
    final unitPriceController = TextEditingController(
      text: existing?.unitPrice.toStringAsFixed(0) ?? '',
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              index == null ? 'Add service item' : 'Edit service item',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Service or item name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Item details',
                hintText: 'Scope, materials, or service notes',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unitPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Unit price'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(index == null ? 'Add Item' : 'Save Item'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    final title = titleController.text.trim();
    final details = detailsController.text.trim();
    final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
    final unitPrice = double.tryParse(unitPriceController.text.trim()) ?? 0;

    if (title.isEmpty) {
      return;
    }

    final item = InvoiceLineItem(
      title: title,
      quantity: quantity <= 0 ? 1 : quantity,
      unitPrice: unitPrice < 0 ? 0 : unitPrice,
      details: details,
    );

    setState(() {
      if (index == null) {
        _items.add(item);
      } else {
        _items[index] = item;
      }
    });
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final dateFmt = DateFormat('MMM dd, yyyy');
    final providerName = _providerNameController.text.trim().isEmpty
        ? 'Service Provider'
        : _providerNameController.text.trim();
    final clientName = _clientNameController.text.trim().isEmpty
        ? 'Client'
        : _clientNameController.text.trim();
    final serviceDescription = _serviceDescriptionController.text.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Invoice',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _serviceTitleController.text.trim().isEmpty
                        ? 'Service invoice'
                        : _serviceTitleController.text.trim(),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _invoiceNumberController.text.trim(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Issue date: ${dateFmt.format(_issueDate)}'),
                  pw.Text('Due date: ${dateFmt.format(_dueDate)}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _pdfPartyBlock(
                  title: 'From',
                  name: providerName,
                  email: _providerEmailController.text.trim(),
                  phone: _providerPhoneController.text.trim(),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _pdfPartyBlock(
                  title: 'To',
                  name: clientName,
                  email: _clientEmailController.text.trim(),
                  phone: _clientPhoneController.text.trim(),
                ),
              ),
            ],
          ),
          if (serviceDescription.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Service details',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(serviceDescription),
          ],
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: const ['Item', 'Details', 'Qty', 'Unit', 'Total'],
            data: _items
                .map(
                  (item) => [
                    item.title,
                    item.details,
                    item.quantity.toString(),
                    _currency.format(item.unitPrice),
                    _currency.format(item.total),
                  ],
                )
                .toList(),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.4),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Subtotal: ${_currency.format(_subtotal)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Total: ${_currency.format(_subtotal)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_notesController.text.trim().isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(_notesController.text.trim()),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfPartyBlock({
    required String title,
    required String name,
    String? email,
    String? phone,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey100),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(name),
          if (email != null && email.isNotEmpty) pw.Text(email),
          if (phone != null && phone.isNotEmpty) pw.Text(phone),
        ],
      ),
    );
  }

  Future<void> _printPdf() async {
    final data = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) => data);
    AnalyticsService.instance.logEvent(
      'invoice_print',
      params: {
        'booking_id': widget.booking?.id,
        'invoice_mode': _isManualInvoice ? 'manual' : 'booking',
      },
    );
  }

  Future<void> _sharePdf() async {
    final data = await _buildPdf();
    final invoiceId = _invoiceNumberController.text.trim().replaceAll(' ', '_');
    await Printing.sharePdf(
      bytes: data,
      filename: '${invoiceId.isEmpty ? 'invoice' : invoiceId}.pdf',
    );
    AnalyticsService.instance.logEvent(
      'invoice_share',
      params: {
        'booking_id': widget.booking?.id,
        'invoice_mode': _isManualInvoice ? 'manual' : 'booking',
      },
    );
  }

  Future<void> _savePdf() async {
    final data = await _buildPdf();
    final dir = await getApplicationDocumentsDirectory();
    final safeInvoiceId = _invoiceNumberController.text
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      '${dir.path}/${safeInvoiceId.isEmpty ? 'invoice' : safeInvoiceId}.pdf',
    );
    await file.writeAsBytes(data);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to ${file.path}')),
    );
    AnalyticsService.instance.logEvent(
      'invoice_save',
      params: {
        'booking_id': widget.booking?.id,
        'invoice_mode': _isManualInvoice ? 'manual' : 'booking',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('MMM dd, yyyy');
    final modeLabel = _isManualInvoice ? 'Manual Invoice' : 'Booking Invoice';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print),
            onPressed: _printPdf,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isManualInvoice
                    ? const [Color(0xFF455A64), Color(0xFF263238)]
                    : const [Color(0xFF1565C0), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    modeLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Create, refine, and export your invoice in one place.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isManualInvoice
                      ? 'Start from scratch and enter the exact service details your client needs.'
                      : 'The booking information is prefilled, and you can still adjust the invoice to match the final service scope.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ExpandableSection(
            title: 'Invoice setup',
            subtitle: 'Invoice number and dates',
            initiallyExpanded: true,
            child: Column(
              children: [
                TextField(
                  controller: _invoiceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Invoice number',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateTile(
                        label: 'Issue date',
                        value: dateFmt.format(_issueDate),
                        onTap: () => _pickDate(
                          initial: _issueDate,
                          onSelected: (next) => setState(() => _issueDate = next),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTile(
                        label: 'Due date',
                        value: dateFmt.format(_dueDate),
                        onTap: () => _pickDate(
                          initial: _dueDate,
                          onSelected: (next) => setState(() => _dueDate = next),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ExpandableSection(
            title: 'Service details',
            subtitle: 'Invoice title and scope of work',
            initiallyExpanded: true,
            child: Column(
              children: [
                TextField(
                  controller: _serviceTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Service title',
                    hintText: 'Electrical installation, AC servicing, etc.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceDescriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Service description',
                    hintText: 'Describe the work done, deliverables, materials, or milestones',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ExpandableSection(
            title: 'Business and client',
            subtitle: 'Who is issuing the invoice and who is receiving it',
            child: Column(
              children: [
                _PartyCard(
                  title: 'From',
                  nameController: _providerNameController,
                  emailController: _providerEmailController,
                  phoneController: _providerPhoneController,
                ),
                const SizedBox(height: 12),
                _PartyCard(
                  title: 'To',
                  nameController: _clientNameController,
                  emailController: _clientEmailController,
                  phoneController: _clientPhoneController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ExpandableSection(
            title: 'Items and pricing',
            subtitle: 'Add line items with exact service details',
            initiallyExpanded: true,
            child: Column(
              children: [
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _upsertItem(index: index),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit item',
                            ),
                            IconButton(
                              onPressed: _items.length == 1
                                  ? null
                                  : () => setState(() => _items.removeAt(index)),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete item',
                            ),
                          ],
                        ),
                        if (item.details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.details,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _ItemPill(
                              label: 'Qty ${item.quantity}',
                              color: const Color(0xFF1565C0),
                            ),
                            const SizedBox(width: 8),
                            _ItemPill(
                              label: _currency.format(item.unitPrice),
                              color: const Color(0xFF00897B),
                            ),
                            const Spacer(),
                            Text(
                              _currency.format(item.total),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _upsertItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _currency.format(_subtotal),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ExpandableSection(
            title: 'Notes',
            subtitle: 'Payment instructions or extra details',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Bank details, payment terms, warranty notes, or reminders',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _savePdf,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Share PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(subtitle),
          children: [child],
        ),
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.title,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
  });

  final String title;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ],
      ),
    );
  }
}

class _ItemPill extends StatelessWidget {
  const _ItemPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
