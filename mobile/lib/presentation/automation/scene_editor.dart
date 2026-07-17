import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SceneEditorScreen extends ConsumerWidget {
  final String? automationId;

  const SceneEditorScreen({super.key, this.automationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = automationId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Scene' : 'Edit Scene',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Scene Name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text('Conditions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _AddButton(label: 'Add Condition', onTap: () {}),
          const SizedBox(height: 24),
          Text('Actions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _AddButton(label: 'Add Action', onTap: () {}),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4C6FFF),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Color(0xFF4C6FFF)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: const Color(0xFF4C6FFF), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
