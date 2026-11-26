import qs.services
import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int itemIndex: -1
    property int lastFocused: -1
    property real iconSize: 35
    property real countDotWidth: 10
    property real countDotHeight: 4
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"
    readonly property bool isBeingDragged: !isSeparator && appListRoot && appListRoot.dragIndex === root.itemIndex
    readonly property real targetShiftX: {
        if (isSeparator || !appListRoot || !appListRoot.isDragging) return 0;
        const from = appListRoot.dragIndex;
        const to = appListRoot.dragTargetIndex;
        if (root.itemIndex === from) return appListRoot.dragOffsetX;
        if (from < to && root.itemIndex > from && root.itemIndex <= to) return -appListRoot.dragSlotStep;
        if (from > to && root.itemIndex < from && root.itemIndex >= to) return appListRoot.dragSlotStep;
        return 0;
    }

    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    enabled: !isSeparator
    rippleEnabled: false
    colBackground: (!isSeparator && interactionArea.containsMouse)
        ? colBackgroundHover
        : ColorUtils.transparentize(Appearance?.colors.colLayer1Hover, 1)
    implicitWidth: isSeparator ? 1 : implicitHeight - topInset - bottomInset
    z: isBeingDragged ? 100 : 0
    scale: isBeingDragged ? 1.12 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    transform: Translate {
        id: dragTranslate
        x: root.targetShiftX
        y: root.isBeingDragged ? -5 : 0

        Behavior on x {
            enabled: !root.isBeingDragged
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    function activateOrLaunch() {
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length;
        appToplevel.toplevels[lastFocused].activate();
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
            bottomMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
        }
        sourceComponent: DockSeparator {}
    }

    // Unified interaction MouseArea overrides RippleButton's built-in MouseArea cleanly
    // so short hold + drag works reliably without triggering unwanted clicks.
    MouseArea {
        id: interactionArea
        anchors.fill: parent
        z: 10
        visible: !root.isSeparator
        hoverEnabled: true
        cursorShape: root.isBeingDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property real pressSceneX: 0
        property bool dragMoved: false

        Timer {
            id: holdTimer
            interval: 100
            repeat: false
            onTriggered: {
                if (interactionArea.pressedButtons & Qt.LeftButton && appListRoot && !appListRoot.isDragging) {
                    appListRoot.beginDrag(root.itemIndex, root.appToplevel.pinned, interactionArea.pressSceneX);
                }
            }
        }

        onEntered: {
            if (appListRoot && !appListRoot.isDragging && appToplevel.toplevels.length > 0) {
                appListRoot.lastHoveredButton = root;
                appListRoot.buttonHovered = true;
                root.lastFocused = appToplevel.toplevels.length - 1;
            }
        }

        onExited: {
            if (appListRoot && appListRoot.lastHoveredButton === root) {
                appListRoot.buttonHovered = false;
            }
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.altAction) root.altAction(mouse);
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                if (root.middleClickAction) root.middleClickAction();
                return;
            }
            if (mouse.button === Qt.LeftButton) {
                root.down = true;
                if (root.rippleEnabled) root.startRipple(mouse.x, mouse.y);
                dragMoved = false;
                pressSceneX = interactionArea.mapToItem(appListRoot, mouse.x, mouse.y).x;
                holdTimer.restart();
            }
        }

        onPositionChanged: (mouse) => {
            if (!(pressedButtons & Qt.LeftButton) || !appListRoot) return;
            const curX = interactionArea.mapToItem(appListRoot, mouse.x, mouse.y).x;
            if (Math.abs(curX - pressSceneX) > 6) {
                dragMoved = true;
                if (!appListRoot.isDragging) {
                    holdTimer.stop();
                    appListRoot.beginDrag(root.itemIndex, root.appToplevel.pinned, pressSceneX);
                }
            }
            if (appListRoot.isDragging) {
                appListRoot.updateDrag(curX);
            }
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return;
            holdTimer.stop();
            root.down = false;

            const wasDragging = appListRoot && appListRoot.isDragging;
            const moved = dragMoved;
            dragMoved = false;

            if (wasDragging) {
                appListRoot.endDrag(moved);
            }
            if (!moved) {
                root.activateOrLaunch();
            }
        }

        onCanceled: {
            holdTimer.stop();
            root.down = false;
            dragMoved = false;
            if (appListRoot && appListRoot.isDragging) {
                appListRoot.endDrag(false);
            }
        }
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        TaskbarApps.togglePin(appToplevel.appId);
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.centerIn: parent

            DropShadow {
                anchors.fill: iconImageLoader
                source: iconImageLoader
                horizontalOffset: 0
                verticalOffset: root.isBeingDragged ? 6 : 2
                radius: root.isBeingDragged ? 12 : 7
                samples: 25
                spread: 0.15
                color: Qt.rgba(0, 0, 0, root.isBeingDragged ? 0.65 : 0.42)
                opacity: (appListRoot && appListRoot.isDragging) ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }
            }

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                active: !root.isSeparator
                sourceComponent: IconImage {
                    source: Quickshell.iconPath(AppSearch.guessIcon(appToplevel.appId), "image-missing")
                    implicitSize: root.iconSize
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

            RowLayout {
                spacing: 3
                anchors {
                    top: iconImageLoader.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                Repeater {
                    model: Math.min(appToplevel.toplevels.length, 3)
                    delegate: Rectangle {
                        required property int index
                        radius: Appearance.rounding.full
                        implicitWidth: (appToplevel.toplevels.length <= 3) ? 
                            root.countDotWidth : root.countDotHeight // Circles when too many
                        implicitHeight: root.countDotHeight
                        color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                    }
                }
            }
        }
    }
}
