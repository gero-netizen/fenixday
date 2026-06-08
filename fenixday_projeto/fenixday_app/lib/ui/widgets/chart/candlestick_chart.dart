import 'package:flutter/material.dart';

class CandleData {
  final DateTime time;
  final double open, high, low, close, volume;
  const CandleData({required this.time, required this.open, required this.high, required this.low, required this.close, this.volume = 0});
}

class CandlestickChart extends StatelessWidget {
  final List<CandleData> candles;
  final double? upperBound;
  final double? lowerBound;
  final double? currentPrice;
  final dynamic gridLevels;
  final int? visibleCandles;
  const CandlestickChart({super.key, required this.candles, this.upperBound, this.lowerBound, this.currentPrice, this.gridLevels, this.visibleCandles});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Gráfico indisponível'));
}
