/// FênixDay — Design System completo
///
/// Paleta híbrida Binance + Bybit aplicada consistentemente
/// em todas as telas do app.

import 'package:flutter/material.dart';

// ── Cores ─────────────────────────────────────────────────────────────────────

abstract final class FenixColors {
  // Fundos
  static const Color bg      = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color card    = Color(0xFF1C2128);
  static const Color card2   = Color(0xFF21262D);

  // Bordas
  static const Color border  = Color(0xFF30363D);
  static const Color dim     = Color(0xFF484F58);

  // Texto
  static const Color textPrimary   = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFFB0BAC5);
  static const Color textMuted     = Color(0xFF7D8590);

  // Verde (lucros, sucesso)
  static const Color green   = Color(0xFF0ECB81);
  static const Color greenBg = Color(0x1A0ECB81);   // 10% opacity
  static const Color greenBd = Color(0x400ECB81);   // 25% opacity

  // Amarelo/Dourado (Binance — CTAs, destaques)
  static const Color yellow   = Color(0xFFF0B90B);
  static const Color yellowBg = Color(0x1AF0B90B);
  static const Color yellowBd = Color(0x40F0B90B);

  // Vermelho (perdas, alertas críticos)
  static const Color red   = Color(0xFFF6465D);
  static const Color redBg = Color(0x1AF6465D);
  static const Color redBd = Color(0x40F6465D);

  // Azul (informação, LINK, Bybit)
  static const Color blue   = Color(0xFF1E88E5);
  static const Color blueBg = Color(0x1A1E88E5);
  static const Color blueBd = Color(0x401E88E5);

  // Roxo (Pro, Paper Trading, elementos premium)
  static const Color purple   = Color(0xFF8957E5);
  static const Color purpleBg = Color(0x1A8957E5);
  static const Color purpleBd = Color(0x408957E5);

  // Violeta (Admin, ações especiais)
  static const Color violet   = Color(0xFF6E40C9);
  static const Color violetBg = Color(0x1A6E40C9);
  static const Color violetBd = Color(0x406E40C9);

  // Laranja (Bybit, avisos, Demo/Testnet)
  static const Color orange   = Color(0xFFF7931A);
  static const Color orangeBg = Color(0x1AF7931A);
  static const Color orangeBd = Color(0x40F7931A);

  // Construtor privado
  FenixColors._();
}

// ── Tema ─────────────────────────────────────────────────────────────────────

final fenixTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: FenixColors.bg,
  colorScheme: const ColorScheme.dark(
    primary:      FenixColors.yellow,
    secondary:    FenixColors.green,
    surface:      FenixColors.surface,
    error:        FenixColors.red,
    onPrimary:    Color(0xFF1A0A00),
    onSecondary:  Color(0xFF0A1F15),
    onSurface:    FenixColors.textPrimary,
    onError:      FenixColors.textPrimary,
  ),

  // AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor:  FenixColors.surface,
    foregroundColor:  FenixColors.textPrimary,
    elevation:        0,
    centerTitle:      false,
    titleTextStyle:   TextStyle(
      fontSize:       15,
      fontWeight:     FontWeight.w500,
      color:          FenixColors.textPrimary,
    ),
    iconTheme: IconThemeData(
      color: FenixColors.textMuted,
      size:  18,
    ),
  ),

  // BottomNavigationBar
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor:        FenixColors.surface,
    selectedItemColor:      FenixColors.yellow,
    unselectedItemColor:    FenixColors.textMuted,
    selectedLabelStyle:     TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
    unselectedLabelStyle:   TextStyle(fontSize: 9),
    elevation:              0,
    type:                   BottomNavigationBarType.fixed,
  ),

  // TabBar
  tabBarTheme: const TabBarThemeData(
    labelColor:         FenixColors.yellow,
    unselectedLabelColor: FenixColors.textMuted,
    indicatorColor:     FenixColors.yellow,
    indicatorSize:      TabBarIndicatorSize.label,
    labelStyle:         TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    unselectedLabelStyle: TextStyle(fontSize: 12),
  ),

  // ElevatedButton — botão principal amarelo
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor:  FenixColors.yellow,
      foregroundColor:  Color(0xFF1A0A00),
      elevation:        0,
      padding:          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  ),

  // OutlinedButton
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: FenixColors.textSecondary,
      side: BorderSide(color: FenixColors.border, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: TextStyle(fontSize: 12),
    ),
  ),

  // TextButton
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: FenixColors.yellow,
      textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
  ),

  // Switch
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return FenixColors.green;
      return FenixColors.textMuted;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return FenixColors.green.withOpacity(.3);
      }
      return FenixColors.border;
    }),
  ),

  // Slider
  sliderTheme: const SliderThemeData(
    activeTrackColor:   FenixColors.yellow,
    inactiveTrackColor: FenixColors.border,
    thumbColor:         FenixColors.yellow,
    trackHeight:        3,
    thumbShape:  RoundSliderThumbShape(enabledThumbRadius: 7),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
  ),

  // Checkbox
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return FenixColors.yellow;
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(const Color(0xFF1A0A00)),
    side: const BorderSide(color: FenixColors.border, width: 0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
  ),

  // RadioButton
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return FenixColors.violet;
      return FenixColors.textMuted;
    }),
  ),

  // Card
  cardTheme: CardThemeData(
    color:       FenixColors.card,
    elevation:   0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: FenixColors.border, width: 0.5),
    ),
  ),

  // Divider
  dividerTheme: const DividerThemeData(
    color:     FenixColors.border,
    thickness: 0.5,
    space:     1,
  ),

  // Input / TextField
  inputDecorationTheme: InputDecorationTheme(
    filled:           true,
    fillColor:        FenixColors.card2,
    contentPadding:   const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: FenixColors.border, width: 0.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: FenixColors.border, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: FenixColors.yellow, width: 1),
    ),
    hintStyle: const TextStyle(fontSize: 12, color: FenixColors.textMuted),
    labelStyle: const TextStyle(fontSize: 11, color: FenixColors.textMuted),
  ),

  // DropdownMenu
  dropdownMenuTheme: DropdownMenuThemeData(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FenixColors.card2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: FenixColors.border, width: 0.5),
      ),
    ),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStateProperty.all(FenixColors.card),
    ),
  ),

  // SnackBar
  snackBarTheme: const SnackBarThemeData(
    backgroundColor:  FenixColors.card,
    contentTextStyle: TextStyle(color: FenixColors.textPrimary, fontSize: 12),
    behavior:         SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),

  // Dialog
  dialogTheme: const DialogThemeData(
    backgroundColor: FenixColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    titleTextStyle: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500,
      color: FenixColors.textPrimary,
    ),
    contentTextStyle: TextStyle(
      fontSize: 12, color: FenixColors.textMuted, height: 1.4,
    ),
  ),

  // PopupMenu
  popupMenuTheme: const PopupMenuThemeData(
    color:   FenixColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      side: BorderSide(color: FenixColors.border, width: 0.5),
    ),
    textStyle: TextStyle(fontSize: 12, color: FenixColors.textSecondary),
  ),

  // Text padrão
  textTheme: const TextTheme(
    displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    displaySmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    titleLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    titleMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    titleSmall:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: FenixColors.textSecondary),
    bodyLarge:     TextStyle(fontSize: 14, color: FenixColors.textPrimary),
    bodyMedium:    TextStyle(fontSize: 13, color: FenixColors.textSecondary),
    bodySmall:     TextStyle(fontSize: 11, color: FenixColors.textMuted),
    labelLarge:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: FenixColors.textPrimary),
    labelMedium:   TextStyle(fontSize: 11, color: FenixColors.textMuted),
    labelSmall:    TextStyle(fontSize: 9,  color: FenixColors.textMuted),
  ),
);
