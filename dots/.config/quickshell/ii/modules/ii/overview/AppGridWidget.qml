pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    required property var screen

    readonly property list<var> appList: {
        var apps = [];
        for (var app of DesktopEntries.applications.values) {
            if (!app.noDisplay && app.name && app.name.trim().length > 0) {
                apps.push(app);
            }
        }
        return apps.sort((a, b) => a.name.localeCompare(b.name));
    }

    implicitWidth: 880 + Appearance.sizes.elevationMargin * 2
    implicitHeight: 520 + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: appGridBackground
    }

    Rectangle {
        id: appGridBackground
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colBackgroundSurfaceContainer
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                MaterialSymbol {
                    text: "apps"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("All Applications")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: root.appList.length + " " + Translation.tr("installed")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOutline
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
                opacity: 0.5
            }

            // Grid of Installed Applications
            GridView {
                id: gridView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 120
                cellHeight: 102
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                model: ScriptModel {
                    values: root.appList
                }

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    width: gridView.cellWidth
                    height: gridView.cellHeight

                    RippleButton {
                        id: appItem
                        anchors.centerIn: parent
                        width: parent.width - 10
                        height: parent.height - 10

                        buttonRadius: Appearance.rounding.normal
                        colBackground: hovered ? Appearance.colors.colLayer1Hover : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active

                        onClicked: {
                            GlobalStates.overviewOpen = false;
                            delegateRoot.modelData.execute();
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            AppIcon {
                                Layout.alignment: Qt.AlignHCenter
                                source: delegateRoot.modelData.icon || "application-x-executable"
                                implicitSize: 42
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: delegateRoot.modelData.name || ""
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        StyledToolTip {
                            text: delegateRoot.modelData.name + (delegateRoot.modelData.comment ? ("\n" + delegateRoot.modelData.comment) : "")
                        }
                    }
                }
            }
        }
    }
}
