// MainPage.qml – hlavní obsah widgetu s tab barem Mounts / Historie

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: page
    spacing: 0

    // ── Tab bar ─────────────────────────────────────────────────────────────
    PlasmaComponents.TabBar {
        id: tabBar
        Layout.fillWidth: true
        currentIndex: 0
        onCurrentIndexChanged: {
            if (currentIndex === 1) { checkTransfers(); checkStats() }
        }

        PlasmaComponents.TabButton {
            icon.name: "folder-cloud"
            text: "Mounts"
        }
        PlasmaComponents.TabButton {
            icon.name: "view-history"
            text: "History"
        }
    }

    // ── Obsah záložek ────────────────────────────────────────────────────────
    StackLayout {
        id: tabContent
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabBar.currentIndex

        // ════════════════════════════════
        //  TAB 0 – Mounts
        // ════════════════════════════════
        ColumnLayout {
            spacing: 0

            // Hledání + refresh
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaExtras.SearchField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    placeholderText: "Search remote..."
                    onTextChanged: filterText = text.toLowerCase()
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: { fetchRemotes(); checkDaemon() }
                    display: QQC2.AbstractButton.IconOnly
                    PlasmaComponents.ToolTip { text: "Refresh" }
                }
            }

            // Banner: daemon neběží
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                visible: !rcRunning
                type: Kirigami.MessageType.Error
                text: errorMsg !== "" ? errorMsg : "RC daemon is not running — click ▶ to start"
            }

            // Banner: chyba mount/unmount
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                visible: rcRunning && errorMsg !== ""
                type: Kirigami.MessageType.Error
                text: errorMsg
            }

            // Seznam remotes
            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: null

                contentItem: ListView {
                    id: remoteList
                    clip: true
                    highlight: PlasmaExtras.Highlight {}
                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    currentIndex: -1

                    model: remotes.filter(function(r) {
                        return filterText === ""
                            || r.toLowerCase().indexOf(filterText) !== -1
                    })

                    delegate: PlasmaComponents.ItemDelegate {
                        id: del
                        width: remoteList.width
                        height: Kirigami.Units.gridUnit * 3.5
                        hoverEnabled: true

                        property string remote:     modelData
                        property string remoteName: remote.replace(/:$/, "")
                        property bool   mounted:    activeMounts.hasOwnProperty(remote)
                        property string mountPath:  mounted ? activeMounts[remote]
                                                            : (mountBase + "/" + remoteName)

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: remoteIcon(del.remote)
                                width:  Kirigami.Units.iconSizes.medium
                                height: Kirigami.Units.iconSizes.medium
                                opacity: del.mounted ? 1.0 : 0.45
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                PlasmaComponents.Label {
                                    text: del.remoteName
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: del.mounted ? del.mountPath : "Not mounted"
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.75
                                    elide: Text.ElideRight
                                    opacity: 0.7
                                    Layout.fillWidth: true
                                }
                            }

                            // Otevřít složku – vždy viditelné, disabled když není připojeno
                            PlasmaComponents.ToolButton {
                                icon.name: "document-open-folder"
                                enabled: del.mounted
                                opacity: del.mounted ? 1.0 : 0.3
                                display: QQC2.AbstractButton.IconOnly
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: openFolder(del.mountPath)
                                PlasmaComponents.ToolTip {
                                    text: del.mounted ? "Open folder" : "Mount first"
                                }
                            }

                            PlasmaComponents.Button {
                                text: del.mounted ? "Unmount" : "Mount"
                                icon.name: del.mounted ? "media-eject" : "media-playback-start"
                                highlighted: del.mounted
                                enabled: rcRunning
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: del.mounted
                                           ? doUnmount(del.mountPath)
                                           : doMount(del.remote)
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#30808080"
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - (Kirigami.Units.largeSpacing * 4)
                        visible: remoteList.count === 0 && !loading
                        icon.name: filterText !== "" ? "edit-find" : "folder-cloud"
                        text: filterText !== "" ? "No remotes match" : "No rclone remotes"
                        explanation: filterText !== "" ? "" : "Configure them: rclone config"
                    }
                }
            }

            // Status bar (Mounts tab)
            PlasmaExtras.PlasmoidHeading {
                Layout.fillWidth: true
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        text: Object.keys(activeMounts).length + " / " + remotes.length + " mounted"
                        font.pixelSize: 11
                        opacity: 0.7
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.BusyIndicator {
                        visible: loading
                        running: loading
                        width: 18; height: 18
                    }
                    PlasmaComponents.Label {
                        text: ":" + rcPort
                        font.pixelSize: 10
                        opacity: 0.4
                    }
                }
            }
        }

        // ════════════════════════════════
        //  TAB 1 – Historie přenosů
        // ════════════════════════════════
        ColumnLayout {
            spacing: 0

            // ── Aktivní přenosy ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: activeTransfers.length > 0

                // Nadpis sekce
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "Transfer in progress"
                        font.pixelSize: 11
                        font.bold: true
                        opacity: 0.8
                        Layout.fillWidth: true
                    }
                }

                // Řádky aktivních přenosů
                Repeater {
                    model: activeTransfers
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        spacing: 2

                        property var t: modelData
                        property string fname: {
                            var n = t.name || ""
                            var s = n.lastIndexOf("/")
                            return s >= 0 ? n.substring(s + 1) : n
                        }
                        // percentage může být 0 i v půlce uploadu (mount) → dopočítej z bytes/size
                        property real pct: {
                            var p = t.percentage || 0
                            if (p > 0) return p
                            var sz = t.size || 0
                            var by = t.bytes || 0
                            return (sz > 0 && by > 0) ? Math.min(99, by / sz * 100) : 0
                        }
                        // animace jen pokud neznáme velikost (VFS mount); known size → fill bar od 0%
                        property bool indeterminate: pct === 0 && (t.size || 0) <= 0
                        property string speed: formatSpeed(t.speed || 0)
                        // Směr: upload = lokální zdroj → remote; download = remote → lokální cíl
                        property bool isUpload: {
                            var src = t.srcFs || t.src_fs || ""
                            var dst = t.dstFs || t.dst_fs || ""
                            if (src !== "" && src.charAt(0) === "/") return true
                            if (dst !== "" && dst.charAt(0) === "/") return false
                            return true  // výchozí: upload (zápis přes mount)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: isUpload ? "go-up" : "go-down"
                                width: Kirigami.Units.iconSizes.small
                                height: Kirigami.Units.iconSizes.small
                                color: isUpload ? Kirigami.Theme.positiveTextColor
                                               : Kirigami.Theme.highlightColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            PlasmaComponents.Label {
                                text: fname
                                elide: Text.ElideLeft
                                Layout.fillWidth: true
                                font.pixelSize: Kirigami.Units.gridUnit * 0.85
                            }
                            PlasmaComponents.Label {
                                text: indeterminate ? (speed ? speed : "…")
                                                    : pct.toFixed(0) + "%" + (speed ? "  " + speed : "")
                                font.pixelSize: 11
                                opacity: 0.6
                            }
                        }

                        // Progress bar – determinate nebo animovaný indeterminate
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1
                            color: "#20808080"
                            clip: true

                            // Determinate fill
                            Rectangle {
                                visible: !indeterminate
                                width: parent.width * (pct / 100)
                                height: parent.height
                                radius: parent.radius
                                color: Kirigami.Theme.highlightColor
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }

                            // Indeterminate pulse (upload přes mount – neznámá velikost)
                            Rectangle {
                                id: indBar
                                visible: indeterminate
                                width: parent.width * 0.35
                                height: parent.height
                                radius: parent.radius
                                color: Kirigami.Theme.highlightColor
                                x: -width
                                SequentialAnimation on x {
                                    running: indeterminate
                                    loops: Animation.Infinite
                                    NumberAnimation { to: indBar.parent.width; duration: 1000; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: -indBar.width;      duration: 0 }
                                }
                            }
                        }

                        // Oddělení od dalšího záznamu
                        Item { Layout.fillWidth: true; height: 4 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#30808080"
                    Layout.bottomMargin: 2
                }
            }

            // ── Záhlaví dokončených přenosů ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: 0
                visible: transferHistory.length > 0 || activeTransfers.length === 0

                PlasmaComponents.Label {
                    text: transferHistory.length > 0
                          ? transferHistory.length + " completed transfers"
                          : "No transfers yet"
                    font.pixelSize: 11
                    opacity: 0.55
                    Layout.fillWidth: true
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: { checkTransfers(); checkStats() }
                    PlasmaComponents.ToolTip { text: "Refresh" }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh-symbolic"
                    display: QQC2.AbstractButton.IconOnly
                    visible: {
                        for (var i = 0; i < transferHistory.length; i++) {
                            if (transferHistory[i].error && transferHistory[i].error !== "") return true
                        }
                        return false
                    }
                    onClicked: retryFailed()
                    PlasmaComponents.ToolTip { text: "Retry failed transfers" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#18808080"
            }

            // ── Seznam dokončených přenosů ───────────────────────────────────
            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: null

                contentItem: ListView {
                    id: histList
                    clip: true
                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    currentIndex: -1
                    model: transferHistory

                    delegate: PlasmaComponents.ItemDelegate {
                        id: hDel
                        width: histList.width
                        height: Kirigami.Units.gridUnit * 3.4
                        hoverEnabled: true
                        highlighted: false
                        onClicked: histList.currentIndex = -1

                        property var    entry:    modelData
                        property bool   hasError: entry.error && entry.error !== ""
                        property string fileName: {
                            var n = entry.name || ""
                            var slash = n.lastIndexOf("/")
                            return slash >= 0 ? n.substring(slash + 1) : n
                        }
                        property string filePath: {
                            var n = entry.name || ""
                            var slash = n.lastIndexOf("/")
                            return slash > 0 ? n.substring(0, slash) : ""
                        }
                        property string doneAt: bestTime(entry)
                        // Jen čitelná část chyby (bez JSON bloků)
                        property string shortError: cleanError(entry.error || "")

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            // Stavová ikona
                            Kirigami.Icon {
                                source: hDel.hasError ? "dialog-error-symbolic"
                                                      : "checkmark-symbolic"
                                width:  Kirigami.Units.iconSizes.small
                                height: Kirigami.Units.iconSizes.small
                                color:  hDel.hasError ? Kirigami.Theme.negativeTextColor
                                                      : Kirigami.Theme.positiveTextColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Název + meta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                PlasmaComponents.Label {
                                    text: hDel.fileName || "(unknown file)"
                                    elide: Text.ElideLeft
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents.Label {
                                    text: {
                                        var parts = []
                                        if (hDel.hasError) parts.push(hDel.shortError)
                                        else parts.push(formatSize(hDel.entry.size || hDel.entry.bytes || 0))
                                        if (hDel.filePath) parts.push(hDel.filePath)
                                        return parts.join("  •  ")
                                    }
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.75
                                    opacity: 0.65
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: hDel.hasError ? Kirigami.Theme.negativeTextColor
                                                         : Kirigami.Theme.textColor

                                    PlasmaComponents.ToolTip {
                                        visible: hDel.hovered && hDel.hasError
                                        text: hDel.hasError ? cleanError(hDel.entry.error) : ""
                                    }
                                }
                            }

                            // Čas: HH:MM + relativní čas pod tím
                            // Pokud rclone timestamp nemá (mount provoz), ukáže jen "–"
                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: Kirigami.Units.gridUnit * 3.5

                                PlasmaComponents.Label {
                                    text: formatTime(hDel.doneAt) || "–"
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.85
                                    font.bold: true
                                    opacity: 0.75
                                    horizontalAlignment: Text.AlignRight
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents.Label {
                                    text: safeRelTime(hDel.doneAt)
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.68
                                    opacity: 0.45
                                    horizontalAlignment: Text.AlignRight
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#20808080"
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - (Kirigami.Units.largeSpacing * 4)
                        visible: histList.count === 0 && activeTransfers.length === 0
                        icon.name: "view-history"
                        text: "No transfer history"
                        explanation: rcRunning
                                     ? "History will appear after the first transfer completes"
                                     : "Start the RC daemon to monitor transfers"
                    }
                }
            }

            // Status bar (Historie tab)
            PlasmaExtras.PlasmoidHeading {
                Layout.fillWidth: true
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        text: rcRunning ? "Daemon running · :" + rcPort : "Daemon not running"
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
    } // StackLayout
}
