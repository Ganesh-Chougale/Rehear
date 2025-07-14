import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/editor_settings.dart';

class MarkerDialog extends StatefulWidget {
  final Marker? marker;
  final Duration? position;

  const MarkerDialog({
    super.key,
    this.marker,
    this.position,
  });

  @override
  State<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late Duration _position;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.marker?.name ?? 'Marker',
    );
    _selectedColor = widget.marker?.color ?? Colors.blue;
    _position = widget.position ?? widget.marker?.position ?? Duration.zero;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.marker == null ? 'Add Marker' : 'Edit Marker'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Marker Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Marker Color:'),
            const SizedBox(height: 8),
            BlockPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            final marker = Marker(
              id: widget.marker?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : 'Marker',
              position: _position,
              color: _selectedColor,
            );
            Navigator.pop(context, marker);
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
