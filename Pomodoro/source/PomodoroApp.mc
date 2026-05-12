import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PomodoroApp extends Application.AppBase {

    var pomodoroManager;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        pomodoroManager = new PomodoroManager();
        pomodoroManager.loadState();
    }

    function onStop(state as Dictionary?) as Void {
        if (pomodoroManager != null) {
            pomodoroManager.saveState();
        }
    }

    function getInitialView() {
        var view = new PomodoroView(pomodoroManager);
        var delegate = new PomodoroDelegate(pomodoroManager, view);
        
        return [ view, delegate ];
    }

    function onSettingsChanged() as Void {
        if (pomodoroManager != null) {
            pomodoroManager.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as PomodoroApp {
    return Application.getApp() as PomodoroApp;
}