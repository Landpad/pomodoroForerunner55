import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Application.Properties;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Attention;
import Toybox.Sensor;
import Toybox.Lang;

enum {
    STATE_IDLE,
    STATE_FOCUS,
    STATE_BREAK,
    STATE_PAUSED
}

class PomodoroManager {    
    var currentState = STATE_IDLE;
    var previousState = STATE_IDLE; 
        
    var focusDurationSecs as Number = 1500;
    var breakDurationSecs as Number = 300;  
    var longBreakDurationSecs as Number = 900;
        
    var cyclesPerSet as Number = 4;
    var currentCycle as Number = 1;
    var isLongBreak as Boolean = false;
    
    var timeRemaining as Number = 1500;
    
    var completedTasks as Number = 0;
    var interruptionCount as Number = 0;
    var totalFocusTime as Number = 0;
    var totalInterruptionTime as Number = 0;
    var currentInterruptionTimer as Number = 0;
    
    var isAccelEnabled as Boolean = true;
    var accelThreshold as Number = 2500;
    var isRecordingEnabled as Boolean = true;
    
    var uiNeeds1HzUpdate as Boolean = true; 
    var idlePauseSecs as Number = 0;
    
    private var targetEndTime as Number? = null; 
    private var isInSleepMode as Boolean = false;

    private var appTimer as Timer.Timer?;
    private var session as ActivityRecording.Session?;
    
    private var fitFocusTime as FitContributor.Field?;
    private var fitInterruptionTime as FitContributor.Field?;
    private var fitTasks as FitContributor.Field?;

    function initialize() {
        reloadSettings();
    }


    function reloadSettings() as Void {
        var focusMin = Properties.getValue("pomodoroDuration");
        var breakMin = Properties.getValue("breakDuration");
        var longBreakMin = Properties.getValue("longBreakDuration");
        var cyclesVal = Properties.getValue("cyclesPerSet");
        
        focusDurationSecs = (focusMin != null ? focusMin : 25) * 60;
        breakDurationSecs = (breakMin != null ? breakMin : 5) * 60;
        longBreakDurationSecs = (longBreakMin != null ? longBreakMin : 15) * 60;
        cyclesPerSet = (cyclesVal != null ? cyclesVal : 4);
                
        var accelOn = Properties.getValue("accelEnabled");
        var thresholdVal = Properties.getValue("accelThreshold");
        var recordVal = Properties.getValue("recordActivity");
        
        isAccelEnabled = (accelOn != null ? accelOn : true);
        accelThreshold = (thresholdVal != null ? thresholdVal : 2500);
        isRecordingEnabled = (recordVal != null ? recordVal : true);
        
        if (!isAccelEnabled) {
            Sensor.unregisterSensorDataListener();
        } else {
            enableAccelerometer();
        }
        
        if (!isRecordingEnabled && session != null) {
            if (session has :stop) { session.stop(); }
            if (session has :discard) { session.discard(); }
            session = null;
        }

        if (currentState == STATE_IDLE) {
            timeRemaining = focusDurationSecs;
            currentCycle = 1;
            isLongBreak = false;
        }
    }
    

    function saveState() as Void {
        Storage.setValue("state", currentState);
        Storage.setValue("prevState", previousState);
        Storage.setValue("rem", timeRemaining);
        Storage.setValue("tasks", completedTasks);
        Storage.setValue("intCount", interruptionCount);
        Storage.setValue("totFocus", totalFocusTime);
        Storage.setValue("totInt", totalInterruptionTime);
        Storage.setValue("cycle", currentCycle);
        Storage.setValue("longBrk", isLongBreak);
        
        stopTimer();
    }

    function loadState() as Void {
        var savedState = Storage.getValue("state");
        if (savedState != null) {
            currentState = savedState;
            previousState = Storage.getValue("prevState");
            timeRemaining = Storage.getValue("rem");
            completedTasks = Storage.getValue("tasks");
            interruptionCount = Storage.getValue("intCount");
            totalFocusTime = Storage.getValue("totFocus");
            totalInterruptionTime = Storage.getValue("totInt");
            
            var savedCycle = Storage.getValue("cycle");
            if (savedCycle != null) { currentCycle = savedCycle; }
            
            var savedLongBrk = Storage.getValue("longBrk");
            if (savedLongBrk != null) { isLongBreak = savedLongBrk; }
            
            if (currentState == STATE_FOCUS || currentState == STATE_BREAK || currentState == STATE_PAUSED) {                
                setUpdateMode(true);
            }
        }
    }
    

    function startSession() as Void {
        if (currentState == STATE_IDLE) {
            currentState = STATE_FOCUS;
            timeRemaining = focusDurationSecs;
            currentCycle = 1;
            isLongBreak = false;
            idlePauseSecs = 0;
            
            if (isRecordingEnabled && session == null && ActivityRecording has :createSession) {
                session = ActivityRecording.createSession({
                    :name=>"Pomodoro",
                    :sport=>ActivityRecording.SPORT_TRAINING
                });
                
                if (session != null) {
                    fitFocusTime = session.createField("focus_time", 0, FitContributor.DATA_TYPE_FLOAT, {:mesgType=>FitContributor.MESG_TYPE_SESSION, :units=>"s"});
                    fitInterruptionTime = session.createField("interruption_time", 1, FitContributor.DATA_TYPE_FLOAT, {:mesgType=>FitContributor.MESG_TYPE_SESSION, :units=>"s"});
                    fitTasks = session.createField("completed_tasks", 2, FitContributor.DATA_TYPE_UINT16, {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"tareas"});
                    session.start();
                }
            }
            setUpdateMode(true);
        } else if (currentState == STATE_PAUSED) {
            currentState = (previousState != STATE_IDLE) ? previousState : STATE_FOCUS;
            idlePauseSecs = 0;
            
            if (isRecordingEnabled && session != null && session has :start) {
                session.start();
            }
            updateFitFields();
            setUpdateMode(true);
        }
        WatchUi.requestUpdate();
    }

    function pauseSession() as Void {
        if (currentState == STATE_FOCUS || currentState == STATE_BREAK) {
            previousState = currentState;
            currentState = STATE_PAUSED;
            interruptionCount++;
            currentInterruptionTimer = 0;
            idlePauseSecs = 0;
            
            if (session != null && session has :stop) {
                session.stop();
            }
            updateFitFields();
            setUpdateMode(true);
            WatchUi.requestUpdate();
        }
    }

    function stopAndSaveSession() as Void {
        stopTimer();
        isInSleepMode = false;
        targetEndTime = null;
        
        if (session != null) {
            updateFitFields();
            if (session has :stop) { session.stop(); }
            if (session has :save) { session.save(); }
            session = null;
        }
        
        currentState = STATE_IDLE;
        previousState = STATE_IDLE;
        timeRemaining = focusDurationSecs;
        currentCycle = 1;
        isLongBreak = false;
        completedTasks = 0;
        interruptionCount = 0;
        totalFocusTime = 0;
        totalInterruptionTime = 0;
        idlePauseSecs = 0;
        
        Storage.clearValues();
        WatchUi.requestUpdate();
    }

    function adjustTasks(delta as Number) as Void {
        completedTasks += delta;
        if (completedTasks < 0) { completedTasks = 0; }
        updateFitFields();
        WatchUi.requestUpdate();
    }
    

    function setUpdateMode(dynamic as Boolean) as Void {
        if (currentState == STATE_IDLE) { 
            isInSleepMode = false;
            return; 
        }
        
        if (isRecordingEnabled) { 
            isInSleepMode = false;
            startTimer(1000, true);
            return; 
        }

        if (!dynamic && !isInSleepMode && currentState != STATE_PAUSED) {            
            isInSleepMode = true;
            var msRemaining = timeRemaining * 1000;
            targetEndTime = System.getTimer() + msRemaining;

            stopTimer();
            startTimer(msRemaining, false);

        } else if (dynamic && isInSleepMode) {            
            isInSleepMode = false;
            if (targetEndTime != null) {
                var now = System.getTimer();
                timeRemaining = (targetEndTime - now) / 1000;
                if (timeRemaining < 0) { timeRemaining = 0; }
            }
            startTimer(1000, true);
        }
    }

    private function startTimer(period as Number, repeat as Boolean) as Void {
        stopTimer();
        if (appTimer == null) {
            appTimer = new Timer.Timer();
        }
        var safePeriod = (period > 100) ? period : 100;
        appTimer.start(method(:onTimerTick), safePeriod, repeat);
    }

    private function stopTimer() as Void {
        if (appTimer != null) {
            appTimer.stop();
            appTimer = null;
        }
    }

    function onTimerTick() as Void {
        if (isInSleepMode) {            
            timeRemaining = 0;
            processPhaseChange();
            setUpdateMode(false); 
        } else {            
            if (currentState == STATE_FOCUS) {
                timeRemaining--;
                totalFocusTime++;
                if (timeRemaining <= 0) { processPhaseChange(); }
            } else if (currentState == STATE_BREAK) {
                timeRemaining--;
                if (timeRemaining <= 0) { processPhaseChange(); }
            } else if (currentState == STATE_PAUSED) {
                totalInterruptionTime++;
                currentInterruptionTimer++;
                idlePauseSecs++;
                                
                if (idlePauseSecs >= 900) { 
                    stopAndSaveSession(); 
                    return;
                }
            }
            
            updateFitFields();
            if (uiNeeds1HzUpdate) { WatchUi.requestUpdate(); }
        }
    }

    private function processPhaseChange() as Void {
        triggerAlert();
        if (currentState == STATE_FOCUS) {
            currentState = STATE_BREAK;
            if (currentCycle < cyclesPerSet) {
                isLongBreak = false;
                timeRemaining = breakDurationSecs;
                currentCycle++;
            } else {
                isLongBreak = true;
                timeRemaining = longBreakDurationSecs;
                currentCycle = 1;
            }
        } else if (currentState == STATE_BREAK) {
            currentState = STATE_FOCUS;
            timeRemaining = focusDurationSecs;
            isLongBreak = false;
        }
        
        if (isInSleepMode) {
            targetEndTime = System.getTimer() + (timeRemaining * 1000);
        }
    }

    private function updateFitFields() as Void {
        if (session != null && isRecordingEnabled) {
            if (fitFocusTime != null) { fitFocusTime.setData(totalFocusTime.toFloat()); }
            if (fitInterruptionTime != null) { fitInterruptionTime.setData(totalInterruptionTime.toFloat()); }
            if (fitTasks != null) { fitTasks.setData(completedTasks); }
        }
    }
    

    private function enableAccelerometer() as Void {
        if (isAccelEnabled && Sensor has :registerSensorDataListener) {
            var options = {:period => 1, :accelerometer => {:enabled => true, :sampleRate => 10}};
            try {
                Sensor.registerSensorDataListener(method(:onSensorData), options);
            } catch (e) {                
            }
        }
    }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        if (!isAccelEnabled || currentState != STATE_FOCUS) { return; }

        var data = sensorData.accelerometerData;
        if (data != null) {            
            var threshold = accelThreshold;
            var xArr = data.x;
            var yArr = data.y;
            var zArr = data.z;

            for (var i = 0; i < xArr.size(); i++) {
                var rawX = xArr[i];
                var rawY = yArr[i];
                var rawZ = zArr[i];
                
                var x = rawX < 0 ? -rawX : rawX;
                var y = rawY < 0 ? -rawY : rawY;
                var z = rawZ < 0 ? -rawZ : rawZ;

                if (x > threshold || y > threshold || z > threshold) {
                    triggerVibrateOnly();
                    break; 
                }
            }
        }
    }

    private function triggerAlert() as Void {
        if (Attention has :vibrate) {
            var vibeData = [new Attention.VibeProfile(100, 1000)];
            Attention.vibrate(vibeData);
        }
    }

    private function triggerVibrateOnly() as Void {
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 200)
            ];
            Attention.vibrate(vibeData);
        }
    }
}