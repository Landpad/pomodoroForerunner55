import Toybox.WatchUi;
import Toybox.Lang;

class PomodoroDelegate extends WatchUi.BehaviorDelegate {
    private var manager as PomodoroManager;
    private var view as PomodoroView;

    function initialize(pomodoroManager as PomodoroManager, pomodoroView as PomodoroView) {
        BehaviorDelegate.initialize();
        manager = pomodoroManager;
        view = pomodoroView;
    }

    // Botón físico DOWN
    function onNextPage() as Boolean {
        view.nextPage();
        return true;
    }

    // Botón físico UP (Toque corto)
    function onPreviousPage() as Boolean {
        view.prevPage();
        return true;
    }

    // Botón físico START / STOP superior derecho
    function onSelect() as Boolean {
        if (view.currentPage == 3) {
            // Pantalla Tareas: Sumar tarea
            manager.adjustTasks(1);
        } else {
            // Resto de pantallas: Controlar temporizador
            var state = manager.currentState;
            if (state == 0 || state == 3) { // IDLE o PAUSED
                manager.startSession();
            } else { // FOCUS o BREAK
                manager.pauseSession();
            }
        }
        return true;
    }

    // Mantener presionado el botón UP (Comportamiento nativo de Menú)
    function onMenu() as Boolean {
        if (view.currentPage == 3) {
            // Pantalla Tareas: Restar tarea si nos equivocamos al sumar
            manager.adjustTasks(-1);
        } else {
            // Resto de pantallas: Detener totalmente y guardar el archivo .FIT
            if (manager.currentState != 0) {
                manager.stopAndSaveSession();
            }
        }
        return true;
    }

    // Botón físico BACK (inferior derecho)
    function onBack() as Boolean {
        // Al devolver 'false', le decimos a Connect IQ que cierre la app.
        // Esto gatillará automáticamente PomodoroApp.onStop(), guardando el estado en memoria.
        return false; 
    }
}