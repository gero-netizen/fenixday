import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CandleData {
  final DateTime time;
  final double open, high, low, close, volume;
  const CandleData({required this.time, required this.open, required this.high, required this.low, required this.close, this.volume = 0});
  bool get isBull => close >= open;
}

class CandlestickChart extends StatefulWidget {
  final List<CandleData> candles;
  final double? upperBound, lowerBound, currentPrice;
  final dynamic gridLevels;
  final int? visibleCandles;
  const CandlestickChart({super.key, required this.candles, this.upperBound, this.lowerBound, this.currentPrice, this.gridLevels, this.visibleCandles});
  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  int? _hovered;
  double _scroll = 0, _dragX = 0, _dragScroll = 0;
  int get _n => widget.visibleCandles ?? 40;

  List<CandleData> get _visible {
    final all = widget.candles;
    if (all.isEmpty) return [];
    final off = _scroll.toInt().clamp(0, (all.length - _n).clamp(0, all.length));
    final s = (all.length - _n - off).clamp(0, all.length);
    final e = (s + _n).clamp(0, all.length);
    return all.sublist(s, e);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Color(0xFFF7931A), strokeWidth: 2), SizedBox(height: 12), Text('Carregando...', style: TextStyle(fontSize: 11, color: Color(0xFF848E9C)))]));
    final vis = _visible;
    if (vis.isEmpty) return const SizedBox.shrink();
    double minY = vis.map((c) => c.low).reduce((a,b) => a<b?a:b);
    double maxY = vis.map((c) => c.high).reduce((a,b) => a>b?a:b);
    if (widget.upperBound != null && widget.upperBound! > maxY) maxY = widget.upperBound! * 1.005;
    if (widget.lowerBound != null && widget.lowerBound! < minY) minY = widget.lowerBound! * 0.995;
    final rng = maxY - minY;
    minY -= rng * 0.03; maxY += rng * 0.03;
    return GestureDetector(
      onHorizontalDragStart: (d) { _dragX = d.localPosition.dx; _dragScroll = _scroll; },
      onHorizontalDragUpdate: (d) => setState(() => _scroll = (_dragScroll + (d.localPosition.dx - _dragX) / 6).clamp(0, (widget.candles.length - _n).toDouble().clamp(0, double.infinity))),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Painter(candles: vis, minY: minY, maxY: maxY, upperBound: widget.upperBound, lowerBound: widget.lowerBound, currentPrice: widget.currentPrice, hovered: _hovered, gridLevels: widget.gridLevels is List<double> ? widget.gridLevels as List<double> : null))),
        Positioned.fill(child: MouseRegion(onHover: (e) { final w = context.size?.width ?? 1; setState(() => _hovered = (e.localPosition.dx / (w / vis.length)).floor().clamp(0, vis.length-1)); }, onExit: (_) => setState(() => _hovered = null), child: const SizedBox.expand())),
        if (_hovered != null && _hovered! < vis.length) Positioned(top: 4, left: 4, child: _Tip(vis[_hovered!])),
      ]),
    );
  }
}

class _Painter extends CustomPainter {
  final List<CandleData> candles;
  final double minY, maxY;
  final double? upperBound, lowerBound, currentPrice;
  final int? hovered;
  final List<double>? gridLevels;
  const _Painter({required this.candles, required this.minY, required this.maxY, this.upperBound, this.lowerBound, this.currentPrice, this.hovered, this.gridLevels});
  double _y(double p, double h) => h - ((p - minY) / (maxY - minY)) * h;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height; final n = candles.length;
    final cw = w / n; final bw = (cw * 0.6).clamp(2.0, 12.0);
    final gp = Paint()..color = const Color(0xFF2B3139)..strokeWidth = 0.5;
    for (int i = 0; i <= 5; i++) canvas.drawLine(Offset(0, h*i/5), Offset(w, h*i/5), gp);
    for (int i = 0; i <= 5; i++) { final price = minY + (maxY-minY)*(5-i)/5; _lbl(canvas, '\$${_f(price)}', Offset(w-68, h*i/5+2), const Color(0xFF848E9C), 8); }
    // Linhas internas do grid baseadas no número real de grades
    if (upperBound != null && lowerBound != null) {
      // Usa gridLevels se disponível, senão usa 10 divisões
      final levels = gridLevels;
      final glp = Paint()..color = const Color(0xFF0ECB81).withOpacity(.25)..strokeWidth = 0.5;
      if (levels != null && levels.isNotEmpty) {
        for (final price in levels) {
          final y = _y(price, h);
          if (y >= 0 && y <= h) {
            double x = 0;
            while (x < w - 4) {
              canvas.drawLine(Offset(x, y), Offset(x + 3, y), glp);
              x += 6;
            }
          }
        }
      } else {
        final numLines = 10;
        final sp = (upperBound! - lowerBound!) / numLines;
        for (int i = 1; i < numLines; i++) {
          final price = lowerBound! + sp * i;
          final y = _y(price, h);
          if (y >= 0 && y <= h) {
            double x = 0;
            while (x < w - 4) {
              canvas.drawLine(Offset(x, y), Offset(x + 3, y), glp);
              x += 6;
            }
          }
        }
      }
    }
    // Linha superior (vermelha/laranja)
    if (upperBound != null) {
      final y = _y(upperBound!, h);
      if (y >= 0 && y <= h) {
        canvas.drawLine(Offset(0, y), Offset(w, y),
          Paint()..color = const Color(0xFFFF4B4B)..strokeWidth = 1.5);
        // Label
        final tp = TextPainter(
          text: TextSpan(text: 'PREÇO SUPERIOR  \$${_f(upperBound!)}',
            style: const TextStyle(color: Color(0xFFFF4B4B), fontSize: 9, fontFamily: 'RobotoMono')),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        // Box
        canvas.drawRect(Rect.fromLTWH(w - tp.width - 12, y - 10, tp.width + 12, 18),
          Paint()..color = const Color(0xFFFF4B4B));
        tp.paint(canvas, Offset(w - tp.width - 6, y - 6));
        // Label esquerdo
        _lbl(canvas, 'PREÇO SUPERIOR  \$${_f(upperBound!)}', Offset(4, y - 12), const Color(0xFFFF4B4B));
      }
    }
    // Linha inferior (verde)
    if (lowerBound != null) {
      final y = _y(lowerBound!, h);
      if (y >= 0 && y <= h) {
        canvas.drawLine(Offset(0, y), Offset(w, y),
          Paint()..color = const Color(0xFF0ECB81)..strokeWidth = 1.5);
        final tp = TextPainter(
          text: TextSpan(text: 'PREÇO INFERIOR  \$${_f(lowerBound!)}',
            style: const TextStyle(color: Color(0xFF0ECB81), fontSize: 9, fontFamily: 'RobotoMono')),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        canvas.drawRect(Rect.fromLTWH(w - tp.width - 12, y - 10, tp.width + 12, 18),
          Paint()..color = const Color(0xFF0ECB81));
        canvas.drawRect(Rect.fromLTWH(w - tp.width - 12, y - 10, tp.width + 12, 18),
          Paint()..color = Colors.black.withOpacity(.5));
        tp.paint(canvas, Offset(w - tp.width - 6, y - 6));
        _lbl(canvas, 'PREÇO INFERIOR  \$${_f(lowerBound!)}', Offset(4, y + 3), const Color(0xFF0ECB81));
      }
    }
    for (int i=0;i<n;i++) {
      final c=candles[i]; final cx=(i+0.5)*cw; final isH=hovered==i;
      final color=c.isBull?const Color(0xFF0ECB81):const Color(0xFFF6465D);
      if(isH) canvas.drawRect(Rect.fromLTWH(i*cw,0,cw,h),Paint()..color=Colors.white.withOpacity(.05));
      canvas.drawLine(Offset(cx,_y(c.high,h)),Offset(cx,_y(c.low,h)),Paint()..color=color.withOpacity(.8)..strokeWidth=1);
      final top=_y(c.isBull?c.close:c.open,h); final bot=_y(c.isBull?c.open:c.close,h); final bh=(bot-top).abs().clamp(1.0,double.infinity);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx-bw/2,top,bw,bh),const Radius.circular(1)),Paint()..color=color);
    }
    if (currentPrice != null) {
      final y=_y(currentPrice!,h); if(y>=0&&y<=h){
        final dp=Paint()..color=const Color(0xFF0ECB81)..strokeWidth=1;
        double x=0; while(x<w-4){canvas.drawLine(Offset(x,y),Offset(x+4,y),dp);x+=8;}
        final txt='\$${_f(currentPrice!)}'; final tp=TextPainter(text:TextSpan(text:txt,style:const TextStyle(color:Colors.black,fontSize:9,fontFamily:'RobotoMono')),textDirection:ui.TextDirection.ltr,)..layout();
        final bxW=tp.width+8; final bxH=tp.height+4;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w-bxW-2,y-bxH/2,bxW,bxH),const Radius.circular(3)),Paint()..color=const Color(0xFF0ECB81));
        tp.paint(canvas,Offset(w-bxW+2,y-bxH/2+2));
      }
    }
  }
  void _lbl(Canvas canvas, String t, Offset o, Color c, [double s=9]) { final tp=TextPainter(text:TextSpan(text:t,style:TextStyle(color:c,fontSize:s,fontFamily:'RobotoMono')),textDirection:ui.TextDirection.ltr,)..layout(); tp.paint(canvas,o); }
  String _f(double v) { if(v>=10000)return NumberFormat('#,##0.00').format(v); if(v>=1)return v.toStringAsFixed(4); if(v>=0.01)return v.toStringAsFixed(5); return v.toStringAsFixed(6); }
  @override
  bool shouldRepaint(_Painter o) => o.candles!=candles||o.hovered!=hovered||o.currentPrice!=currentPrice;
}

class _Tip extends StatelessWidget {
  final CandleData c;
  const _Tip(this.c);
  @override
  Widget build(BuildContext context) {
    final fmt=NumberFormat('#,##0.00');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:8,vertical:6),
      decoration: BoxDecoration(color:const Color(0xFF1E2329).withOpacity(.95),borderRadius:BorderRadius.circular(6),border:Border.all(color:const Color(0xFF2B3139))),
      child: DefaultTextStyle(style:const TextStyle(fontFamily:'RobotoMono',fontSize:9,color:Color(0xFF848E9C)),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(DateFormat('dd/MM HH:mm').format(c.time)),
          const SizedBox(height:2),
          Row(children:[const Text('O '),Text(fmt.format(c.open),style:TextStyle(color:c.isBull?const Color(0xFF0ECB81):const Color(0xFFF6465D)))]),
          Row(children:[const Text('H '),Text(fmt.format(c.high),style:const TextStyle(color:Color(0xFF0ECB81)))]),
          Row(children:[const Text('L '),Text(fmt.format(c.low),style:const TextStyle(color:Color(0xFFF6465D)))]),
          Row(children:[const Text('C '),Text(fmt.format(c.close),style:TextStyle(color:c.isBull?const Color(0xFF0ECB81):const Color(0xFFF6465D)))]),
        ]),
      ),
    );
  }
}
