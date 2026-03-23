import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/profile_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductCard extends StatefulWidget {
  final String id;
  final String title;
  final String price;
  final bool isFree;
  final String date;
  final String? region;
  final List<String> images;
  final bool showLabel;
  final String? labelText;
  final bool isFavorite;
  final bool isNegotiable;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  final double
  imageHeight; // дозволяє підлаштовувати висоту зображення для різних контекстів

  const ProductCard({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    required this.date,
    this.region,
    required this.images,
    this.showLabel = false,
    this.labelText,
    this.isFavorite = false,
    this.isNegotiable = false,
    this.onFavoriteToggle,
    this.onTap,
    this.isFree = false,
    this.imageHeight = 200,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        print('DEBUG (ProductCard): Card tapped for product ID: ${widget.id}');
        ProfileService().addToViewedList(widget.id);
        if (widget.onTap != null) {
          print('DEBUG (ProductCard): Calling onTap callback');
          widget.onTap!();
        } else {
          print('DEBUG (ProductCard): onTap callback is null');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 174,
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section with pagination dots
              SizedBox(
                height: widget.imageHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    SizedBox(
                      height: widget.imageHeight,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.images.isNotEmpty
                            ? PageView.builder(
                                controller: _pageController,
                                itemCount: widget.images.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final imageUrl = widget.images[index];
                                  final image = CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  );
                                  if (index == 0) {
                                    return Hero(
                                      tag: 'product-photo-${widget.id}',
                                      child: image,
                                    );
                                  }
                                  return image;
                                },
                              )
                            : Container(
                                color: AppColors.zinc200,
                                child: Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: AppColors.color5,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    // Favorite icon in top-right over image
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(200),
                          border: Border.all(
                            color: const Color(0xFFF4F4F5),
                            width: 1,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: widget.onFavoriteToggle,
                          child: Icon(
                            widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: widget.isFavorite
                                ? const Color(0xFF015873)
                                : const Color(0xFF27272A),
                          ),
                        ),
                      ),
                    ),
                    // Pagination dots - показуємо тільки якщо є більше 1 зображення
                    if (widget.images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            child: Builder(
                              builder: (context) {
                                final total = widget.images.length;
                                // Вікно до 3 крапок навколо поточної
                                int start = 0;
                                int count = total;
                                if (total > 3) {
                                  if (_currentImageIndex <= 0) {
                                    start = 0;
                                  } else if (_currentImageIndex >= total - 1) {
                                    start = total - 3;
                                  } else {
                                    start = _currentImageIndex - 1;
                                  }
                                  count = 3;
                                }
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(count, (i) {
                                    final dotIndex = start + i;
                                    final isActive =
                                        dotIndex == _currentImageIndex;
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? AppColors.primaryColor
                                            : Colors.black.withValues(
                                                alpha: 0.25,
                                              ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (widget.showLabel && widget.labelText != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.labelText!,
                            style: const TextStyle(
                              color: Color(0xFF52525B),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    if (widget.isFree)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Безкоштовно',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    if (widget.isNegotiable)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Договірна',
                            style: const TextStyle(
                              color: Color(0xFF52525B),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Title
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.30,
                          letterSpacing: 0.24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      widget.isFree ? 'Безкоштовно' : widget.price,
                      style: TextStyle(
                        color: widget.isFree
                            ? const Color(0xFF15803D)
                            : Colors.black,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        height: 1.40,
                        letterSpacing: 0.14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Date and region
                    Row(
                      children: [
                        Text(
                          widget.date,
                          style: const TextStyle(
                            color: Color(0xFF838583),
                            fontSize: 10,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                            letterSpacing: 0.20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.region ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF838583),
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.40,
                              letterSpacing: 0.20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
