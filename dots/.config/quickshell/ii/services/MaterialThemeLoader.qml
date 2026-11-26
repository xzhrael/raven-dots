pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property bool hasInitialLoad: false
    property string lastAppliedContent: ""
    property var startColors: ({})
    property var targetColors: ({})
    property real colorBlendProgress: 1.0

    function reapplyTheme() {
        themeFileView.reload()
    }

    function interpolateColor(c1, c2, t) {
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * t,
            c1.g + (c2.g - c1.g) * t,
            c1.b + (c2.b - c1.b) * t,
            c1.a + (c2.a - c1.a) * t
        );
    }

    NumberAnimation on colorBlendProgress {
        id: paletteBlendAnim
        running: false
        from: 0
        to: 1
        duration: 340
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveEffects
    }

    onColorBlendProgressChanged: {
        const t = colorBlendProgress;
        for (const key in targetColors) {
            if (startColors[key] !== undefined) {
                Appearance.m3colors[key] = interpolateColor(startColors[key], targetColors[key], t);
            }
        }
    }

    function applyColors(fileContent) {
        if (!fileContent || fileContent.trim().length === 0 || fileContent === root.lastAppliedContent)
            return;

        let json;
        try {
            json = JSON.parse(fileContent);
        } catch (e) {
            return;
        }

        const nextTargets = {};
        for (const key in json) {
            if (Object.prototype.hasOwnProperty.call(json, key)) {
                const camelCaseKey = key.replace(/_([a-z])/g, g => g[1].toUpperCase());
                const m3Key = `m3${camelCaseKey}`;
                if (Appearance.m3colors[m3Key] !== undefined) {
                    nextTargets[m3Key] = Qt.color(json[key]);
                }
            }
        }

        root.lastAppliedContent = fileContent;

        if (!root.hasInitialLoad) {
            for (const m3Key in nextTargets) {
                Appearance.m3colors[m3Key] = nextTargets[m3Key];
            }
            if (nextTargets.m3background !== undefined) {
                Appearance.m3colors.darkmode = (nextTargets.m3background.hslLightness < 0.5);
            }
            root.targetColors = nextTargets;
            root.hasInitialLoad = true;
            return;
        }

        paletteBlendAnim.stop();
        const nextStarts = {};
        for (const m3Key in nextTargets) {
            nextStarts[m3Key] = Qt.color(Appearance.m3colors[m3Key]);
        }
        root.startColors = nextStarts;
        root.targetColors = nextTargets;
        if (nextTargets.m3background !== undefined) {
            Appearance.m3colors.darkmode = (nextTargets.m3background.hslLightness < 0.5);
        }
        paletteBlendAnim.restart();
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: 25
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
        }
        onLoadFailed: root.resetFilePathNextTime();
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode;
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", currentlyDark ? "light" : "dark", "--noswitch"]);
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"

        onPressed: {
            root.toggleLightDark();
        }
    }

    IpcHandler {
        target: "theme"

        function toggleLightDark(): void {
            root.toggleLightDark();
        }
    }
}
