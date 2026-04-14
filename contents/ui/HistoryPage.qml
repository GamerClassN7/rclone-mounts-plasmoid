// HistoryPage.qml – záložka s historií naposledy přenesených souborů

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: page
    spacing: 0

    // Hlavička: titulek + tlačítko vymazat
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        spacing: 0

        PlasmaComponents.Label {
            text: transferHistory.length > 0
                  ? transferHistory.length + " přenesených souborů"
                  : ""
            font.pixelSize: 11
            opacity: 0.6
            Layout.fillWidth: true
        }

        PlasmaComponents.ToolButton {
            icon.name: "edit-clear-history"
            visible: transferHistory.length > 0
            display: PlasmaComponents.ToolButton.IconOnly
            onClicked: transferHistory = []
            PlasmaComponents.ToolTip { text: "Vymazat historii" }
        }

        PlasmaComponents.ToolButton {
            icon.name: "view-refresh"
            display: PlasmaComponents.ToolButton.IconOnly
            onClicked: checkTransfers()
            PlasmaComponents.ToolTip { text: "Obnovit" }
        }
    }

    // Oddělovač
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: "#20808080"
    }

    // Seznam přenesených souborů
    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        background: null

        contentItem: ListView {
            id: histList
            clip: true
            highlight: PlasmaExtras.Highlight {}
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            currentIndex: -1
            model: transferHistory

            delegate: PlasmaComponents.ItemDelegate {
                id: hDel
                width: histList.width
                height: Kirigami.Units.gridUnit * 3.2
                hoverEnabled: true

                property var    entry:    modelData
                property bool   hasError: entry.error && entry.error !== ""
                property string fileName: {
                    var n = entry.name || ""
                    // Zobrazit jen poslední část cesty
                    var slash = n.lastIndexOf("/")
                    return slash >= 0 ? n.substring(slash + 1) : n
                }
                property string filePath: {
                    var n = entry.name || ""
                    var slash = n.lastIndexOf("/")
                    return slash > 0 ? n.substring(0, slash) : ""
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    // Stavová ikona (OK / chyba)
                    Kirigami.Icon {
                        source: hDel.hasError ? "dialog-error-symbolic"
                                              : "checkmark-symbolic"
                        width:  Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                        color:  hDel.hasError ? Kirigami.Theme.negativeTextColor
                                              : Kirigami.Theme.positiveTextColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Název souboru + cesta
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        PlasmaComponents.Label {
                            text: hDel.fileName || "(neznámý soubor)"
                            font.bold: false
                            elide: Text.ElideLeft
                            Layout.fillWidth: true
                        }

                        PlasmaComponents.Label {
                            text: {
                                var parts = []
                                if (hDel.filePath) parts.push(hDel.filePath)
                                if (hDel.hasError) parts.push("⚠ " + hDel.entry.error)
                                else parts.push(formatSize(hDel.entry.size || hDel.entry.bytes || 0))
                                return parts.join("  •  ")
                            }
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            opacity: 0.65
                            elide: Text.ElideLeft
                            Layout.fillWidth: true
                            color: hDel.hasError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        }
                    }

                    // Čas
                    PlasmaComponents.Label {
                        text: formatRelTime(hDel.entry.completedAt || hDel.entry.startedAt || "")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.72
                        opacity: 0.5
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#25808080"
                }
            }

            // Prázdný stav
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 4)
                visible: histList.count === 0
                icon.name: "view-history"
                text: "Žádná historie přenosů"
                explanation: rcRunning
                             ? "Historie se zobrazí po dokončení prvního přenosu"
                             : "Spusť RC daemon pro sledování přenosů"
            }
        }
    }

    // Stavový řádek dole
    PlasmaExtras.PlasmoidHeading {
        Layout.fillWidth: true
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: rcRunning ? "Daemon běží na :" + rcPort : "Daemon neběží"
                font.pixelSize: 11
                opacity: 0.7
                Layout.fillWidth: true
            }
            PlasmaComponents.BusyIndicator {
                visible: loading
                running: loading
                width: 18; height: 18
            }
        }
    }
}
