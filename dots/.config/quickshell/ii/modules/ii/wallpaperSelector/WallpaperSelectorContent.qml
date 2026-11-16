import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property bool useDarkMode: Appearance.m3colors.darkmode

    implicitHeight: Appearance.sizes.wallpaperSelectorHeight
    implicitWidth: Appearance.sizes.wallpaperSelectorWidth

    function updateThumbnails() {
        const thumbnailSizeName = "x-large";
        Wallpapers.generateThumbnail(thumbnailSizeName);
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            root.updateThumbnails();
        }
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0];
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            Wallpapers.select(filePath, root.useDarkMode);
            if (filterField) filterField.text = "";
        }
    }

    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            root.handleFilePasting(event);
        } else if (event.key === Qt.Key_Left) {
            carousel.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            carousel.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (carousel.currentItem) {
                carousel.currentItem.triggerApply();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (filterField.text.length > 0) {
                filterField.text = filterField.text.substring(0, filterField.text.length - 1);
            }
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0 && !filterField.activeFocus) {
                filterField.text += event.text;
                filterField.cursorPosition = filterField.text.length;
                filterField.forceActiveFocus();
                event.accepted = true;
            }
        }
    }

    StyledRectangularShadow {
        target: wallpaperBackground
    }

    Rectangle {
        id: wallpaperBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Top Header Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 12

                RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.larger
                        text: "wallpaper"
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: Translation.tr("Wallpaper Carousel")
                        font {
                            pixelSize: Appearance.font.pixelSize.large
                            weight: Font.DemiBold
                        }
                        color: Appearance.colors.colOnLayer0
                    }

                    // Folder badge
                    Rectangle {
                        radius: height / 2
                        implicitHeight: 28
                        implicitWidth: badgeDirLayout.implicitWidth + 16
                        color: Appearance.colors.colSecondaryContainer

                        RowLayout {
                            id: badgeDirLayout
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.small
                                text: "folder"
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSecondaryContainer
                                text: {
                                    const dir = Wallpapers.effectiveDirectory;
                                    const parts = dir.split("/").filter(p => p.length > 0);
                                    return parts.length > 0 ? parts[parts.length - 1] : "Root";
                                }
                            }

                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                text: `(${carousel.count})`
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Actions Toolbar
                Toolbar {
                    ToolbarTextField {
                        id: filterField
                        placeholderText: focus ? Translation.tr("Search wallpapers") : Translation.tr("Hit \"/\" to search")
                        font.pixelSize: Appearance.font.pixelSize.small
                        onTextChanged: {
                            Wallpapers.searchQuery = text;
                        }
                    }

                    IconToolbarButton {
                        implicitWidth: height
                        onClicked: {
                            Wallpapers.randomFromCurrentFolder(root.useDarkMode);
                        }
                        text: "ifl"
                        StyledToolTip {
                            text: Translation.tr("Pick random wallpaper")
                        }
                    }

                    IconToolbarButton {
                        implicitWidth: height
                        onClicked: root.useDarkMode = !root.useDarkMode
                        text: root.useDarkMode ? "dark_mode" : "light_mode"
                        StyledToolTip {
                            text: Translation.tr("Toggle light/dark theme")
                        }
                    }

                    IconToolbarButton {
                        implicitWidth: height
                        onClicked: {
                            Wallpapers.openFallbackPicker(root.useDarkMode);
                            GlobalStates.wallpaperSelectorOpen = false;
                        }
                        text: "open_in_new"
                        StyledToolTip {
                            text: Translation.tr("Open system file picker")
                        }
                    }

                    ToolbarPairedFab {
                        iconText: "close"
                        onClicked: GlobalStates.wallpaperSelectorOpen = false;
                        StyledToolTip {
                            text: Translation.tr("Close")
                        }
                    }
                }
            }

            // Center Area: Carousel
            Item {
                id: carouselContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledIndeterminateProgressBar {
                    visible: Wallpapers.thumbnailGenerationRunning && value == 0
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                }

                StyledProgressBar {
                    visible: Wallpapers.thumbnailGenerationRunning && value > 0
                    value: Wallpapers.thumbnailGenerationProgress
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                }

                ListView {
                    id: carousel
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 24
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    snapMode: ListView.SnapToItem
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: (width - 480) / 2
                    preferredHighlightEnd: (width + 480) / 2
                    highlightFollowsCurrentItem: true
                    keyNavigationWraps: true
                    model: Wallpapers.folderModel

                    Component.onCompleted: {
                        root.updateThumbnails();
                    }

                    // Mouse wheel horizontal scroll handler
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            const delta = (wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y) * 2;
                            carousel.contentX = Math.max(0, Math.min(carousel.contentWidth - carousel.width, carousel.contentX - delta));
                        }
                    }

                    delegate: Item {
                        id: cardDelegate
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === carousel.currentIndex
                        readonly property bool isCurrentlyActive: modelData.filePath === Config.options.background.wallpaperPath

                        width: 480
                        height: carousel.height - 30
                        anchors.verticalCenter: parent.verticalCenter

                        scale: isCurrent ? 1.04 : (cardMouseArea.containsMouse ? 1.0 : 0.94)
                        opacity: isCurrent ? 1.0 : (cardMouseArea.containsMouse ? 0.92 : 0.72)

                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        function triggerApply() {
                            root.selectWallpaperPath(modelData.filePath);
                        }

                        StyledRectangularShadow {
                            target: cardBox
                            radius: Appearance.rounding.large
                        }

                        Rectangle {
                            id: cardBox
                            anchors.fill: parent
                            radius: Appearance.rounding.large
                            color: Appearance.colors.colLayer1
                            border.width: isCurrent ? 3 : 1
                            border.color: isCurrent ? Appearance.colors.colPrimary : (cardMouseArea.containsMouse ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1Border)
                            clip: true

                            Item {
                                anchors.fill: parent

                                ThumbnailImage {
                                    id: thumbImg
                                    anchors.fill: parent
                                    generateThumbnail: false
                                    sourcePath: modelData.filePath
                                    cache: true
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true

                                    onStatusChanged: {
                                        if (status === Image.Error && source !== modelData.filePath) {
                                            source = modelData.filePath;
                                        }
                                    }

                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: cardBox.width
                                            height: cardBox.height
                                            radius: Appearance.rounding.large
                                        }
                                    }
                                }

                                // Bottom gradient overlay for clear title readability
                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                    }
                                    height: 80
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15) }
                                    }
                                }

                                // Details and Badge
                                RowLayout {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        margins: 16
                                    }
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                        font {
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: cardDelegate.isCurrent ? Font.DemiBold : Font.Normal
                                        }
                                        color: Appearance.colors.colOnLayer0
                                        text: modelData.fileName
                                    }

                                    Rectangle {
                                        visible: cardDelegate.isCurrentlyActive || cardDelegate.isCurrent
                                        radius: height / 2
                                        implicitHeight: 28
                                        implicitWidth: badgeTextLayout.implicitWidth + 16
                                        color: cardDelegate.isCurrentlyActive ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary

                                        RowLayout {
                                            id: badgeTextLayout
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MaterialSymbol {
                                                iconSize: Appearance.font.pixelSize.small
                                                text: cardDelegate.isCurrentlyActive ? "check" : "touch_app"
                                                color: cardDelegate.isCurrentlyActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                                            }

                                            StyledText {
                                                font {
                                                    pixelSize: Appearance.font.pixelSize.smaller
                                                    weight: Font.Medium
                                                }
                                                color: cardDelegate.isCurrentlyActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                                                text: cardDelegate.isCurrentlyActive ? Translation.tr("Active") : Translation.tr("Double click")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                carousel.currentIndex = index;
                            }

                            onDoubleClicked: {
                                cardDelegate.triggerApply();
                            }
                        }
                    }
                }
            }

            // Bottom Footer Info
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.small
                    text: "mouse"
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Drag mouse or scroll wheel to browse • Double-click wallpaper to apply • Hit Esc to close")
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: `${carousel.count > 0 ? (carousel.currentIndex + 1) : 0} / ${carousel.count}`
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && (typeof monitorIsFocused === "undefined" || monitorIsFocused)) {
                filterField.forceActiveFocus();
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() {
            GlobalStates.wallpaperSelectorOpen = false;
        }
    }
}
