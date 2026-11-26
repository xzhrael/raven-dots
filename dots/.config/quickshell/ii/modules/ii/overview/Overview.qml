import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    // Latch active view mode across exit animations so closing the app drawer doesn't flash workspaces
    property bool displayShowApps: false

    Connections {
        target: GlobalStates
        function onOverviewShowAppsChanged() {
            if (GlobalStates.overviewOpen) {
                overviewScope.displayShowApps = GlobalStates.overviewShowApps;
            }
        }
    }

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        property real openProgress: GlobalStates.overviewOpen ? 1 : 0

        Behavior on openProgress {
            NumberAnimation {
                duration: GlobalStates.overviewOpen ? 260 : 170
                easing.type: Easing.BezierSpline
                easing.bezierCurve: GlobalStates.overviewOpen
                    ? Appearance.animationCurves.emphasizedDecel
                    : Appearance.animationCurves.emphasizedAccel
            }
        }

        visible: GlobalStates.overviewOpen || openProgress > 0

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                    GlobalStates.overviewShowApps = false;
                } else {
                    overviewScope.displayShowApps = GlobalStates.overviewShowApps;
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Column {
            id: columnLayout
            visible: GlobalStates.overviewOpen || panelWindow.openProgress > 0
            opacity: panelWindow.openProgress
            // Composite into an offscreen layer only during fades so child shadows don't double-blend
            layer.enabled: panelWindow.openProgress > 0 && panelWindow.openProgress < 1
            transform: [
                Scale {
                    origin.x: columnLayout.width / 2
                    origin.y: 0
                    xScale: 0.95 + 0.05 * panelWindow.openProgress
                    yScale: 0.95 + 0.05 * panelWindow.openProgress
                },
                Translate {
                    y: -18 * (1 - panelWindow.openProgress)
                }
            ]
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                readonly property bool showMainPanel: panelWindow.searchingText == ""
                property real modeTransitionFactor: 1
                anchors.horizontalCenter: parent.horizontalCenter
                active: (GlobalStates.overviewOpen || panelWindow.openProgress > 0) && (Config?.options.overview.enable ?? true)
                visible: opacity > 0
                opacity: (showMainPanel ? 1 : 0) * modeTransitionFactor
                scale: (showMainPanel ? 1 : 0.96) * (0.97 + 0.03 * modeTransitionFactor)
                transformOrigin: Item.Top
                sourceComponent: overviewScope.displayShowApps ? appGridComp : overviewComp

                Behavior on modeTransitionFactor {
                    id: modeTransitionBehavior
                    NumberAnimation {
                        duration: 210
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                onLoaded: {
                    if (panelWindow.openProgress > 0.2) {
                        modeTransitionBehavior.enabled = false;
                        modeTransitionFactor = 0;
                        modeTransitionBehavior.enabled = true;
                        modeTransitionFactor = 1;
                    }
                }
            }
        }

        Component {
            id: overviewComp
            OverviewWidget {
                screen: panelWindow.screen
                captureActive: panelWindow.visible
            }
        }

        Component {
            id: appGridComp
            AppGridWidget {
                screen: panelWindow.screen
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            if (GlobalStates.overviewOpen && GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = true;
                GlobalStates.overviewOpen = true;
            }
        }
        function workspacesToggle() {
            if (GlobalStates.overviewOpen && !GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = false;
                GlobalStates.overviewOpen = true;
            }
        }
        function appDrawerToggle() {
            if (GlobalStates.overviewOpen && GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = true;
                GlobalStates.overviewOpen = true;
            }
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewShowApps = false;
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            GlobalStates.overviewShowApps = false;
            overviewScope.toggleClipboard();
        }
        function emojiToggle() {
            GlobalStates.overviewShowApps = false;
            overviewScope.toggleEmojis();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            if (GlobalStates.overviewOpen && GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = true;
                GlobalStates.overviewOpen = true;
            }
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            if (GlobalStates.overviewOpen && !GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = false;
                GlobalStates.overviewOpen = true;
            }
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            if (GlobalStates.overviewOpen && GlobalStates.overviewShowApps) {
                GlobalStates.overviewOpen = false;
            } else {
                GlobalStates.overviewShowApps = true;
                GlobalStates.overviewOpen = true;
            }
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
