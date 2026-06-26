/// FênixDay — Handler de Background do Monitor (Foreground Service)
/// Roda o ciclo do monitor mesmo com o app fechado / celular travado.
/// Usa flutter_foreground_task: o serviço chama onRepeatEvent
/// periodicamente, e nós executamos um ciclo do GridMonitor.
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'grid_monitor.dart';

/// Ponto de entrada do isolate de background.
/// Precisa ser uma top-level function com @pragma para o AOT não removê-la.
@pragma('vm:entry-point')
void startGridMonitorTask() {
  FlutterForegroundTask.setTaskHandler(GridMonitorTaskHandler());
}

class GridMonitorTaskHandler extends TaskHandler {
  int _ciclos = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('GRID_BG: serviço iniciado ($starter)');
  }

  // Chamado periodicamente conforme o intervalo configurado no serviço.
  @override
  void onRepeatEvent(DateTime timestamp) {
    _ciclos++;
    debugPrint('GRID_BG: ciclo #$_ciclos @ ${timestamp.toIso8601String().substring(11, 19)}');
    // Executa o ciclo do monitor (detecta execuções, cria ordens opostas).
    GridMonitor.instance.executarCiclo();
    // Atualiza a notificação com a hora do último ciclo.
    FlutterForegroundTask.updateService(
      notificationTitle: 'FênixDay — monitorando grids',
      notificationText: 'Último check: ${timestamp.toIso8601String().substring(11, 19)}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('GRID_BG: serviço encerrado');
  }

  // Quando o usuário toca a notificação, traz o app para frente.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}
