// lib/features/messaging/presentation/widgets/image_gallery_preview_screen.dart
import 'package:flutter/material.dart';

class ImageGalleryPreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageGalleryPreviewScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<ImageGalleryPreviewScreen> createState() =>
      _ImageGalleryPreviewScreenState();
}

class _ImageGalleryPreviewScreenState extends State<ImageGalleryPreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
