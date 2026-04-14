import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // cfg_ aliasy – hodnoty pochází výhradně z plasmoid.configuration (main.xml defaults)
    // ŽÁDNÉ hardcoded value/checked na controls – přesně jako Dockio
    property alias cfg_rcPort:       rcPortSpin.value
    property alias cfg_mountBase:    mountBaseField.text
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_fetchOnStart: fetchOnStartCheck.checked
    property alias cfg_autoStartRcd: autoStartCheck.checked

    Kirigami.FormLayout {

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "RC Daemon"
        }

        QQC2.SpinBox {
            id: rcPortSpin
            Kirigami.FormData.label: "Port:"
            from: 1024
            to: 65535
            stepSize: 1
        }

        QQC2.CheckBox {
            id: autoStartCheck
            Kirigami.FormData.label: "Autostart:"
            text: "Spustit daemon automaticky pokud neběží"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Mount pointy"
        }

        QQC2.TextField {
            id: mountBaseField
            Kirigami.FormData.label: "Základní složka:"
            placeholderText: "$HOME/mnt/rclone"
            Layout.minimumWidth: 280
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.label: " "
            Layout.fillWidth: true
            text: "Každý remote se připojí jako podsložka (např. ~/mnt/rclone/gdrive)"
            visible: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Chování"
        }

        QQC2.SpinBox {
            id: pollSpin
            Kirigami.FormData.label: "Interval obnovy (s):"
            from: 5
            to: 300
            stepSize: 5
        }

        QQC2.CheckBox {
            id: fetchOnStartCheck
            Kirigami.FormData.label: "Načíst při startu:"
            text: "Načíst stav mountů při spuštění"
        }
    }
}
