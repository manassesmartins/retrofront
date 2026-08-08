import 'package:flutter/material.dart';

/// Carrossel horizontal com distancia FIXA entre os tiles: em telas maiores
/// cabem mais itens por pagina (e em telas menores, menos), sem que os itens
/// fiquem "voando" uns dos outros. O tile selecionado e centralizado.
class CoverCarousel extends StatefulWidget {
  final int itemCount;
  final double tileWidth;
  final double tileHeight;

  /// Distancia em pixels entre a borda de um tile e a do proximo.
  final double gap;

  final int selected;
  final ValueChanged<int> onSelect;
  final Widget Function(BuildContext context, int index, bool selected)
      itemBuilder;

  const CoverCarousel({
    super.key,
    required this.itemCount,
    required this.tileWidth,
    required this.tileHeight,
    this.gap = 26,
    required this.selected,
    required this.onSelect,
    required this.itemBuilder,
  });

  @override
  State<CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<CoverCarousel> {
  PageController? _page;
  double _fraction = -1;
  late int _lastSelected;

  @override
  void initState() {
    super.initState();
    _lastSelected = widget.selected;
  }

  /// Recalcula a fracao de pagina para manter a distancia fixa:
  /// pagina = tileWidth + gap. Sem piso, para que telas grandes mostrem mais
  /// itens; teto evita overflow em telas muito estreitas.
  PageController _ensurePage(double width) {
    final pageWidth = widget.tileWidth + widget.gap;
    var fraction = pageWidth / width;
    if (fraction > 0.95) fraction = 0.95;
    if (fraction < 0.01) fraction = 0.01;

    final c = _page;
    if (c != null && (_fraction - fraction).abs() < 0.0005) return c;
    _page?.dispose();
    final nc = PageController(
      viewportFraction: fraction,
      initialPage: _lastSelected.clamp(0, widget.itemCount - 1),
    );
    _page = nc;
    _fraction = fraction;
    return nc;
  }

  @override
  void didUpdateWidget(covariant CoverCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != _lastSelected) {
      _lastSelected = widget.selected;
      final page = _page;
      if (page != null && page.hasClients) {
        page.animateToPage(
          widget.selected,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _page?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controller = _ensurePage(constraints.maxWidth);
        return PageView.builder(
          controller: controller,
          itemCount: widget.itemCount,
          padEnds: false,
          onPageChanged: (i) {
            _lastSelected = i;
            if (i != widget.selected) widget.onSelect(i);
          },
          itemBuilder: (context, index) {
            return Center(
              child: SizedBox(
                width: widget.tileWidth,
                height: widget.tileHeight,
                child: widget.itemBuilder(
                  context,
                  index,
                  index == widget.selected,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
