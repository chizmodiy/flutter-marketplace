import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/profile_service.dart';

class ProductCardListItem extends StatefulWidget {
  final String id;
  final String title;
  final String price;
  final String? date;
  final String? region;
  final List<String> images;
  final bool isFavorite;
  final bool isNegotiable;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  final bool
  compact; // режим компактної горизонтальної картки (профіль активні/неактивні)

  const ProductCardListItem({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    this.date,
    this.region,
    required this.images,
    this.isFavorite = false,
    this.isNegotiable = false,
    this.onFavoriteToggle,
    this.onTap,
    this.compact = false,
  });

  @override
  State<ProductCardListItem> createState() => _ProductCardListItemState();
}

class _ProductCardListItemState extends State<ProductCardListItem> {
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
    if (widget.compact) {
      // Компактна картка для сторінок активні/неактивні (76x76 фото, висота 80)
      return InkWell(
        onTap: () {
          ProfileService().addToViewedList(widget.id);
          widget.onTap?.call();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 80,
          decoration: ShapeDecoration(
            color: const Color(0xFFFAFAFA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.images.first,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration(milliseconds: 0),
                          fadeOutDuration: Duration(milliseconds: 0),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.zinc200,
                            child: const Icon(
                              Icons.broken_image,
                              color: AppColors.color5,
                            ),
                          ),
                          placeholder: (context, url) =>
                              Container(color: AppColors.zinc200),
                        )
                      : Container(color: AppColors.zinc200),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Назва в один рядок
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.30,
                        letterSpacing: 0.24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Ціна
                    Text(
                      widget.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        height: 1.30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int imagesCount = widget.images.length;
    final bool isOnePhoto = imagesCount == 1;
    final bool isTwoPhotos = imagesCount == 2;
    final bool isThreeOrMore = imagesCount >= 3;

    return InkWell(
      onTap: () {
        print(
          'DEBUG (ProductCardListItem): Card tapped for product ID: ${widget.id}',
        );
        ProfileService().addToViewedList(widget.id);
        if (widget.onTap != null) {
          print('DEBUG (ProductCardListItem): Calling onTap callback');
          widget.onTap!();
        } else {
          print('DEBUG (ProductCardListItem): onTap callback is null');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0xFFFAFAFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: isOnePhoto
            // Випадок: 1 фото — зображення зверху, контент знизу (згідно макету)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Верхній блок із зображенням 364x120 та кнопкою обраного
                  Container(
                    height: 120,
                    padding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: widget.images.first,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration(milliseconds: 0),
                              fadeOutDuration: Duration(milliseconds: 0),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.zinc200,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: AppColors.color5,
                                ),
                              ),
                              placeholder: (context, url) =>
                                  Container(color: AppColors.zinc200),
                            ),
                          ),
                        ),
                        if (widget.onFavoriteToggle != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      width: 1,
                                      color: Color(0xFFF4F4F5),
                                    ),
                                    borderRadius: BorderRadius.circular(200),
                                  ),
                                ),
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
                      ],
                    ),
                  ),
                  // Нижній контент
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Назва
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.30,
                            letterSpacing: 0.24,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Ціна + дата/регіон
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                widget.price,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  height: 1.50,
                                  letterSpacing: 0.16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.date ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF838583),
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                        height: 1.40,
                                        letterSpacing: 0.20,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if ((widget.date ?? '').isNotEmpty)
                                    const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.region ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF838583),
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                        height: 1.40,
                                        letterSpacing: 0.20,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : isTwoPhotos
            // Випадок: 2 фото — два прев'ю поруч, контент знизу
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 120,
                    padding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        // Два зображення поруч
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[0],
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[1],
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onFavoriteToggle != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      width: 1,
                                      color: Color(0xFFF4F4F5),
                                    ),
                                    borderRadius: BorderRadius.circular(200),
                                  ),
                                ),
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
                      ],
                    ),
                  ),
                  // Контент низ
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.30,
                            letterSpacing: 0.24,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              child: Text(
                                widget.price,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  height: 1.40,
                                  letterSpacing: 0.14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.date ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF838583),
                                    fontSize: 10,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: 0.20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((widget.date ?? '').isNotEmpty)
                                  const SizedBox(width: 6),
                                Text(
                                  widget.region ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF838583),
                                    fontSize: 10,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: 0.20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : isThreeOrMore
            // Випадок: ≥3 фото — три прев'ю поруч, контент знизу
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 120,
                    padding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[0],
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[1],
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[2],
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onFavoriteToggle != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      width: 1,
                                      color: Color(0xFFF4F4F5),
                                    ),
                                    borderRadius: BorderRadius.circular(200),
                                  ),
                                ),
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
                      ],
                    ),
                  ),
                  // Контент низ
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.30,
                            letterSpacing: 0.24,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              child: Text(
                                widget.price,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  height: 1.40,
                                  letterSpacing: 0.14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.date ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF838583),
                                    fontSize: 10,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: 0.20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((widget.date ?? '').isNotEmpty)
                                  const SizedBox(width: 6),
                                Text(
                                  widget.region ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF838583),
                                    fontSize: 10,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: 0.20,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            // Тимчасово: ≥3 фото — старий горизонтальний вигляд
            : Row(
                children: [
                  // Зображення (слайдер/індикатор залишаємо як було)
                  Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
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
                                  return CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.zinc200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.color5,
                                          ),
                                        ),
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.zinc200),
                                  );
                                },
                              )
                            : Container(
                                color: AppColors.zinc200,
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 40,
                                    color: AppColors.color5,
                                  ),
                                ),
                              ),
                      ),
                      if (widget.images.length > 1)
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.2),
                                backgroundBlendMode: BlendMode.overlay,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final total = widget.images.length;
                                  int start = 0;
                                  int count = total;
                                  if (total > 3) {
                                    if (_currentImageIndex <= 0) {
                                      start = 0;
                                    } else if (_currentImageIndex >=
                                        total - 1) {
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
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? AppColors.primaryColor
                                              : Colors.white.withValues(
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
                    ],
                  ),
                  // Контент праворуч (як було)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        height: 1.40,
                                        letterSpacing: 0.14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.price,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        height: 1.30,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.onFavoriteToggle != null)
                                GestureDetector(
                                  onTap: widget.onFavoriteToggle,
                                  child: Icon(
                                    widget.isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 16,
                                    color: widget.isFavorite
                                        ? const Color(0xFF015873)
                                        : const Color(0xFF27272A),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                widget.date ?? '12 Березня 16:00',
                                style: const TextStyle(
                                  color: Color(0xFF838583),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  height: 1.30,
                                  letterSpacing: 0.24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.region ?? 'Харків',
                                  style: const TextStyle(
                                    color: Color(0xFF838583),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                    height: 1.30,
                                    letterSpacing: 0.24,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
