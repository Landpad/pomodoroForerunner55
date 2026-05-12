import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;

class PomodoroView extends WatchUi.View {
    private var manager;
    var currentPage as Number = 0; // Páginas: 0 a 3
    private const TOTAL_PAGES = 4;

    function initialize(pomodoroManager) {
        View.initialize();
        manager = pomodoroManager;
    }

    // Se ejecuta en cada ciclo (cada 1 segundo gracias al Timer del Manager)
    function onUpdate(dc as Dc) as Void {
        // Fondo negro limpio
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        // 1. Dibujar puntitos indicadores de página en la parte inferior
        drawPageIndicator(dc, width, height);

        // 2. Dibujar el contenido según la página actual
        if (currentPage == 0) {
            drawTimerPage(dc, width, height);
        } else if (currentPage == 1) {
            drawClockPage(dc, width, height);
        } else if (currentPage == 2) {
            drawInterruptionPage(dc, width, height);
        } else if (currentPage == 3) {
            drawTasksPage(dc, width, height);
        }
    }

    
    private function drawTimerPage(dc as Dc, width as Number, height as Number) as Void {
            var stateStr = "READY";
            var stateColor = Graphics.COLOR_WHITE;
            var blockStr = "";

            if (manager.currentState == 1) { // FOCUS
                stateStr = "FOCUS";
                stateColor = Graphics.COLOR_RED;
                blockStr = Lang.format("BLOCK $1$/$2$", [manager.currentCycle, manager.cyclesPerSet]);
            } else if (manager.currentState == 2) { // BREAK
                stateStr = manager.isLongBreak ? "LONG BREAK" : "SHORT BREAK";
                stateColor = Graphics.COLOR_GREEN;
            } else if (manager.currentState == 3) { // PAUSED
                stateStr = "PAUSED";
                stateColor = Graphics.COLOR_ORANGE;
                blockStr = Lang.format("BLOCK $1$/$2$", [manager.currentCycle, manager.cyclesPerSet]);
            }

            // Etiqueta de Estado principal
            dc.setColor(stateColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.10, Graphics.FONT_XTINY, stateStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Subtítulo indicando el Bloque actual (Solo visible en Focus o Pausa)
            if (!blockStr.equals("")) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, height * 0.20, Graphics.FONT_XTINY, blockStr, Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Tiempo Restante (MM:SS) ajustado ligeramente en Y para que todo respire
            var mins = manager.timeRemaining / 60;
            var secs = manager.timeRemaining % 60;
            var timeStr = Lang.format("$1$:$2$", [mins.format("%02d"), secs.format("%02d")]);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.38, Graphics.FONT_NUMBER_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Hora actual pequeña debajo
            var clockTime = System.getClockTime();
            var clockStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.72, Graphics.FONT_MEDIUM, clockStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

    // --- PÁGINA 1: HORA Y BATERÍA ---
    private function drawClockPage(dc as Dc, width as Number, height as Number) as Void {
        var clockTime = System.getClockTime();
        var clockStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.32, Graphics.FONT_NUMBER_MEDIUM, clockStr, Graphics.TEXT_JUSTIFY_CENTER);

        var stats = System.getSystemStats();
        var batStr = Lang.format("Battery: $1$%", [stats.battery.format("%d")]);
        
        // Cambiar color de batería si está baja
        var batColor = stats.battery > 20 ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.65, Graphics.FONT_SMALL, batStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- PÁGINA 2: MÉTRICAS DE INTERRUPCIÓN ---
    private function drawInterruptionPage(dc as Dc, width as Number, height as Number) as Void {
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.15, Graphics.FONT_XTINY, "INTERRUPTIONS", Graphics.TEXT_JUSTIFY_CENTER);

        // Número de interrupciones
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.32, Graphics.FONT_NUMBER_MEDIUM, manager.interruptionCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Tiempo total interrumpido
        var intMins = manager.totalInterruptionTime / 60;
        var intSecs = manager.totalInterruptionTime % 60;
        var totStr = Lang.format("Total: $1$:$2$", [intMins.format("%02d"), intSecs.format("%02d")]);
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.68, Graphics.FONT_SMALL, totStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- PÁGINA 3: GESTIÓN DE TAREAS ---
    private function drawTasksPage(dc as Dc, width as Number, height as Number) as Void {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.15, Graphics.FONT_XTINY, "TASKS COMPLETED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.32, Graphics.FONT_NUMBER_MEDIUM, manager.completedTasks.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Ayuda visual de botones físicos
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.68, Graphics.FONT_XTINY, "START (+1) | HOLD UP (-1)", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- DIBUJADO DE PAGINACIÓN ---
    private function drawPageIndicator(dc as Dc, width as Number, height as Number) as Void {
        var dotSpacing = 14;
        var startX = (width - (TOTAL_PAGES * dotSpacing)) / 2 + (dotSpacing / 2);
        var yPos = height - 15;

        for (var i = 0; i < TOTAL_PAGES; i++) {
            if (i == currentPage) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(startX + (i * dotSpacing), yPos, 3);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(startX + (i * dotSpacing), yPos, 2);
            }
        }
    }

    // Métodos llamados por el Delegate para cambiar de pantalla
    function nextPage() as Void {
        currentPage = (currentPage + 1) % TOTAL_PAGES;
        WatchUi.requestUpdate();
    }

    function prevPage() as Void {
        currentPage = (currentPage - 1 + TOTAL_PAGES) % TOTAL_PAGES;
        WatchUi.requestUpdate();
    }
}