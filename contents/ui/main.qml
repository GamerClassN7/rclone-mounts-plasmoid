// Rclone Mounts Plasmoid – KDE Plasma 6 / Qt 6

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    switchWidth:  Kirigami.Units.gridUnit * 5
    switchHeight: Kirigami.Units.gridUnit * 5

    Plasmoid.status: rcRunning
                     ? PlasmaCore.Types.ActiveStatus
                     : PlasmaCore.Types.PassiveStatus

    toolTipMainText: "Rclone Mounts"
    toolTipSubText: rcRunning
                    ? (Object.keys(activeMounts).length + " / " + remotes.length + " mounted")
                    : "RC daemon is not running"

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: rcRunning ? "Stop RC Daemon" : "Start RC Daemon"
            icon.name: rcRunning ? "media-playback-stop" : "media-playback-start"
            onTriggered: {
                if (rcRunning) {
                    exe.run("pkill -f 'rclone rcd.*" + rcPort + "' 2>&1 || true")
                    rcRunning = false
                    activeMounts = {}
                } else {
                    startDaemon()
                }
            }
        }
    ]

    // ── Konfigurace ──────────────────────────────────────────────────────────
    property string mountBase: {
        var base = plasmoid.configuration.mountBase !== ""
                   ? plasmoid.configuration.mountBase
                   : "$HOME/mnt/rclone"
        if (homeDir !== "") {
            base = base.replace(/\$HOME/g, homeDir).replace(/^~/, homeDir)
        }
        return base
    }
    property int    rcPort:       plasmoid.configuration.rcPort > 0
                                  ? plasmoid.configuration.rcPort : 5572
    property string rcAddr:       "localhost:" + rcPort
    property int    pollInterval: plasmoid.configuration.pollInterval > 0
                                  ? plasmoid.configuration.pollInterval : 10
    property bool   autoStartRcd: plasmoid.configuration.autoStartRcd

    // ── Stav ─────────────────────────────────────────────────────────────────
    property string homeDir:         ""
    property var    remotes:         []
    property var    activeMounts:    ({})
    property bool   rcRunning:       false
    property bool   loading:         true
    property string errorMsg:        ""
    property string filterText:      ""
    property var    remoteTypes:     ({})
    property var    transferHistory: []   // dokončené přenosy
    property var    activeTransfers: []   // právě probíhající

    // ── Pomocné funkce ───────────────────────────────────────────────────────
    function formatSize(bytes) {
        if (!bytes || bytes < 0) return "?"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    // Relativní čas ve stylu "před 2 min"
    function formatRelTime(isoStr) {
        if (!isoStr) return ""
        try {
            var d   = new Date(isoStr)
            var now = new Date()
            var sec = Math.floor((now - d) / 1000)
            if (sec < 5)     return "just now"
            if (sec < 60)    return sec + "s ago"
            if (sec < 3600)  return Math.floor(sec / 60) + " min ago"
            if (sec < 86400) return Math.floor(sec / 3600) + " hr ago"
            return Math.floor(sec / 86400) + " d ago"
        } catch(e) { return "" }
    }

    // Čas dokončení ve formátu HH:MM (ignoruje zero date z Go)
    function formatTime(isoStr) {
        if (!isoStr) return ""
        try {
            var d = new Date(isoStr)
            if (isNaN(d.getTime()) || d.getFullYear() < 2000) return ""
            return d.getHours().toString().padStart(2, "0") + ":"
                 + d.getMinutes().toString().padStart(2, "0")
        } catch(e) { return "" }
    }

    // Relativní čas – ignoruje zero date
    function safeRelTime(isoStr) {
        if (!isoStr) return ""
        try {
            var d = new Date(isoStr)
            if (isNaN(d.getTime()) || d.getFullYear() < 2000) return ""
            return formatRelTime(isoStr)
        } catch(e) { return "" }
    }

    // Vytáhne nejlepší dostupný timestamp z objektu přenosu
    // rclone používá snake_case: completed_at, started_at
    function bestTime(entry) {
        var candidates = [entry.completed_at, entry.completedAt,
                          entry.started_at,   entry.startedAt,
                          entry.timestamp]
        for (var i = 0; i < candidates.length; i++) {
            var t = candidates[i]
            if (t && formatTime(t) !== "") return t
        }
        return ""
    }

    // Rychlost přenosu (2 desetinná místa)
    function formatSpeed(bps) {
        if (!bps || bps <= 0) return ""
        if (bps < 1024)       return bps.toFixed(2) + " B/s"
        if (bps < 1048576)    return (bps / 1024).toFixed(2) + " KB/s"
        if (bps < 1073741824) return (bps / 1048576).toFixed(2) + " MB/s"
        return (bps / 1073741824).toFixed(2) + " GB/s"
    }

    function remoteIcon(remote) {
        var t = remoteTypes[remote] || ""
        switch(t) {
            case "drive":     return "folder-gdrive"
            case "dropbox":   return "folder-dropbox"
            case "onedrive":  return "folder-onedrive"
            case "owncloud":  return "folder-owncloud"
            case "nextcloud": return "folder-owncloud"
            case "sftp":      return "folder-network"
            case "ftp":       return "folder-network"
            case "smb":       return "folder-network"
            case "nfs":       return "folder-network"
            case "webdav":    return "folder-network"
            case "http":      return "folder-network"
            case "local":     return "folder"
            case "s3":        return "folder-cloud"
            case "b2":        return "folder-cloud"
            case "box":       return "folder-cloud"
            case "mega":      return "folder-cloud"
            case "pcloud":    return "folder-cloud"
            default:          return "folder-cloud"
        }
    }

    // ── Příkazy ──────────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: exe
        engine: "executable"
        connectedSources: []
        onNewData: function(src, data) {
            handleOutput(src, data["exit code"], data["stdout"].trim(), data["stderr"].trim())
            disconnectSource(src)
        }
        function run(cmd) { connectSource(cmd) }
    }

    function handleOutput(cmd, code, out, err) {
        loading = false
        if (cmd.indexOf("echo $HOME") !== -1) {
            if (code === 0) homeDir = out
            fetchRemotes()
            return
        }
        if (cmd.indexOf("listremotes") !== -1) {
            if (code === 0 && out !== "") {
                var lines = out.split("\n").filter(function(l){ return l.trim() !== "" })
                var names = []
                var types = {}
                lines.forEach(function(line) {
                    var parts = line.trim().split(/\s+/)
                    var name = parts[0]
                    var type = parts[1] || ""
                    names.push(name)
                    types[name] = type
                })
                remotes = names
                remoteTypes = types
            } else {
                remotes = []
                remoteTypes = {}
            }
            return
        }
        if (cmd.indexOf("mount/listmounts") !== -1) {
            if (code === 0) {
                rcRunning = true
                errorMsg = ""
                try {
                    var p = JSON.parse(out)
                    var nm = {}
                    if (p.mountPoints) {
                        p.mountPoints.forEach(function(m){ nm[m.Fs] = m.MountPoint })
                    }
                    activeMounts = nm
                } catch(e) {
                    activeMounts = {}
                }
            } else {
                rcRunning = false
                activeMounts = {}
                errorMsg = "RC daemon is not running on port " + rcPort + "."
            }
            return
        }
        if (cmd.indexOf("mount/mount") !== -1 || cmd.indexOf("mount/unmount") !== -1) {
            errorMsg = (code !== 0) ? "Error: " + err : ""
            Qt.callLater(checkDaemon)
            return
        }
        if (cmd.indexOf("core/stats") !== -1 && cmd.indexOf("core/transferred") === -1) {
            if (code === 0) {
                try {
                    var sp = JSON.parse(out)
                    // Zobrazuj všechny probíhající přenosy (i bytes=0 na začátku uploadu)
                    // vyřaď jen 100% dokončené (než je přesune core/transferred)
                    activeTransfers = sp.transferring
                        ? sp.transferring.filter(function(t) {
                            return (t.percentage || 0) < 100
                          })
                        : []
                } catch(e) { activeTransfers = [] }
            } else {
                activeTransfers = []
            }
            return
        }
        if (cmd.indexOf("core/transferred") !== -1) {
            if (code === 0) {
                try {
                    var tp = JSON.parse(out)
                    if (tp.transferred && tp.transferred.length > 0) {
                        // Deduplikuj: jeden záznam na soubor, akumuluj bajty z chunků
                        var byName = {}
                        tp.transferred.forEach(function(t) {
                            if (t.checked && !(t.error && t.error !== "")) return  // přeskoč verifikace bez chyby
                            var name = t.name || ""
                            // Přeskoč temp soubory (qt_temp.*, .tmp, ~*, atd.) pokud nemají chybu
                            var baseName = name.substring(name.lastIndexOf("/") + 1)
                            var isTmp = /^qt_temp\.|^\..*[a-zA-Z0-9]{5,}$|^\.~lock\.|^~|\.part$/.test(baseName)
                            if (isTmp && !(t.error && t.error !== "")) return
                            var prev = byName[name]
                            if (!prev) {
                                byName[name] = Object.assign({}, t)
                            } else {
                                // Sloučit chunky: akumuluj bytes, propaguj error, ponech nejnovější timestamp
                                var merged = Object.assign({}, prev)
                                merged.bytes = (prev.bytes || 0) + (t.bytes || 0)
                                merged.size  = t.size || prev.size
                                if (t.error && t.error !== "") merged.error = t.error
                                var tNew = new Date(t.completed_at    || t.started_at    || "")
                                var tOld = new Date(prev.completed_at || prev.started_at || "")
                                if (!isNaN(tNew) && tNew > tOld) {
                                    merged.completed_at = t.completed_at
                                    merged.started_at   = t.started_at
                                }
                                byName[name] = merged
                            }
                        })
                        // Seřaď sestupně (nejnovější první)
                        var deduped = Object.keys(byName).map(function(k){ return byName[k] })
                        deduped.sort(function(a, b) {
                            var ta = new Date(a.completed_at || a.started_at || "")
                            var tb = new Date(b.completed_at || b.started_at || "")
                            return tb - ta
                        })
                        transferHistory = deduped.slice(0, 100)
                    }
                } catch(e) {}
            }
            return
        }
        if (cmd.indexOf("rcd") !== -1) {
            daemonStartTimer.start()
        }
    }

    function fetchRemotes()   { loading = true; exe.run("rclone listremotes --long") }
    function checkDaemon()    { exe.run("rclone rc mount/listmounts --rc-addr=" + rcAddr + " 2>&1") }
    function checkTransfers() { if (rcRunning) exe.run("rclone rc core/transferred --rc-addr=" + rcAddr + " 2>&1") }
    function checkStats()     { if (rcRunning) exe.run("rclone rc core/stats --rc-addr=" + rcAddr + " 2>&1") }
    function startDaemon()    { errorMsg = "Starting..."; exe.run("rclone rcd --rc-addr=" + rcAddr + " --rc-no-auth &") }
    function openFolder(path) { exe.run("xdg-open '" + path + "'") }

    // Vytáhne čitelnou část chyby – odstraní JSON blok "Details: [...]" od rclone/Google API
    function cleanError(errStr) {
        if (!errStr) return ""
        var di = errStr.indexOf("\nDetails:")
        var clean = di > 0 ? errStr.substring(0, di).trim() : errStr
        var nl = clean.indexOf("\n")
        return nl > 0 ? clean.substring(0, nl).trim() : clean
    }

    // Zkusí znovu nahrát soubory selháním přes VFS refresh na všech aktivních mountech
    function retryFailed() {
        var mounts = Object.keys(activeMounts)
        mounts.forEach(function(fs) {
            exe.run("rclone rc vfs/refresh dir=/ recursive=true fs=" + fs + " --rc-addr=" + rcAddr + " 2>&1")
        })
        Qt.callLater(checkTransfers)
    }

    function doMount(remote) {
        var path = mountBase + "/" + remote.replace(/:$/, "")
        errorMsg = "Mounting " + remote + "..."
        exe.run("mkdir -p '" + path + "' && rclone rc mount/mount fs=" + remote
                + " mountPoint='" + path + "' --rc-addr=" + rcAddr)
    }
    function doUnmount(mp) {
        errorMsg = "Unmounting..."
        exe.run("rclone rc mount/unmount mountPoint='" + mp + "' --rc-addr=" + rcAddr)
    }

    // Pomalý timer: kontrola mountů + dokončených přenosů
    Timer {
        interval: pollInterval * 1000
        running: true; repeat: true
        onTriggered: { checkDaemon(); checkTransfers() }
    }
    // Rychlý timer: aktivní přenosy (každé 2 s)
    Timer {
        interval: 2000
        running: rcRunning; repeat: true
        onTriggered: checkStats()
    }
    Timer { id: daemonStartTimer; interval: 2500; onTriggered: checkDaemon() }
    Component.onCompleted: {
        exe.run("echo $HOME")
        if (plasmoid.configuration.fetchOnStart) checkDaemon()
    }
    onRcRunningChanged: {
        if (!rcRunning && autoStartRcd) startDaemon()
    }

    // ════════════════════════════════════════════════════════════════════════
    //  KOMPAKTNÍ ZOBRAZENÍ
    // ════════════════════════════════════════════════════════════════════════
    compactRepresentation: MouseArea {
        id: compactRoot
        property bool wasExpanded: false
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        onPressed:  wasExpanded = root.expanded
        onClicked:  root.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.fill: parent
            active: compactRoot.containsMouse
            source: "folder-cloud"
        }

        Rectangle {
            visible: Object.keys(activeMounts).length > 0
            anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
            width: 8; height: 8; radius: 4
            color: Kirigami.Theme.positiveTextColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    //  PLNÉ ZOBRAZENÍ
    // ════════════════════════════════════════════════════════════════════════
    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth:  Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24
        Layout.maximumWidth:  Kirigami.Units.gridUnit * 34
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        collapseMarginsHint: true

        // StackView zůstává jako ve funkční verzi – tab bar je uvnitř MainPage
        QQC2.StackView {
            id: stack
            anchors.fill: parent
            initialItem: MainPage {}
        }
    }
}
