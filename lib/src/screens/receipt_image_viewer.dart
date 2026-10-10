import 'dart:io';

import 'package:flutter/material.dart';

import '../strings.dart';

class ReceiptImageViewer extends StatelessWidget {
  const ReceiptImageViewer({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const LText('ပြေစာပုံ'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6,
          child: Hero(
            tag: 'receipt:$imagePath',
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: LText(
                  'ပြေစာပုံ ဖွင့်၍မရပါ',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openReceiptImage(BuildContext context, String imagePath) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ReceiptImageViewer(imagePath: imagePath),
    ),
  );
}
