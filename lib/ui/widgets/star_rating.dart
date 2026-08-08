import 'package:flutter/material.dart';

/// Exibicao compacta de avaliacao em estrelas (0..5).
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 12,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          Icon(
            i < rating.floor()
                ? Icons.star
                : (rating - i >= 0.5 ? Icons.star_half : Icons.star_border),
            size: size,
            color: color,
          ),
          if (i < 4) const SizedBox(width: 1),
        ],
      ],
    );
  }
}
