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

    
    function onNextPage() as Boolean {
        view.nextPage();
        return true;
    }

    
    function onPreviousPage() as Boolean {
        view.prevPage();
        return true;
    }

    
    function onSelect() as Boolean {
        if (view.currentPage == 3) {
            // Pantalla Tareas: Sumar tarea
            manager.adjustTasks(1);
        } else {
            
            var state = manager.currentState;
            if (state == 0 || state == 3) { // IDLE or PAUSED
                manager.startSession();
            } else { // FOCUS o BREAK
                manager.pauseSession();
            }
        }
        return true;
    }

    
    function onMenu() as Boolean {
        if (view.currentPage == 3) {
            
            manager.adjustTasks(-1);
        } else {
            
            if (manager.currentState != 0) {
                manager.stopAndSaveSession();
            }
        }
        return true;
    }

    // Botón físico BACK (inferior derecho)
    function onBack() as Boolean {

        return false; 
    }
}