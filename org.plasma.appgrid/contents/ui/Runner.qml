import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Fire-and-forget shell commands for the power / session buttons. Loaded lazily by main.qml so
// a missing module can only disable those buttons, never the launcher itself.
Item {
    id: runner

    property int seq: 0

    function run(cmd) {
        ds.connectSource(cmd + " # run" + (++seq))
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => ds.disconnectSource(sourceName)
    }
}
