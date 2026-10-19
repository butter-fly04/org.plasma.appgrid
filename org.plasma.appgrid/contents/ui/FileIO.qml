import QtQuick
import QtQuick.Dialogs
import org.kde.plasma.plasma5support as P5Support

// Tiny file helper for the Backup page (QML cannot write files by itself):
// native file dialogs + `base64 -d >` / `cat` run through Plasma's executable engine.
// The Backup page loads this lazily, so if a module is missing there it only disables
// the file buttons; copy/paste still works.
Item {
    id: io

    signal saved(string path)
    signal loaded(string text)
    signal failed(string message)

    property string pendingText: ""
    property int seq: 0
    property var kinds: ({})

    function chooseSave(text) {
        pendingText = text
        saveDialog.open()
    }

    function chooseLoad() {
        loadDialog.open()
    }

    function localPath(url) {
        return decodeURIComponent(url.toString()).replace(/^file:\/\//, "")
    }

    function shellQuote(p) {
        return "'" + p.replace(/'/g, "'\\''") + "'"
    }

    // keep the payload pure ASCII so base64 is safe (JSON \uXXXX escapes round-trip)
    function ascii(t) {
        return t.replace(/[\u0080-￿]/g, function (c) {
            return "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4)
        })
    }

    function writeFile(path, text) {
        var cmd = "printf '%s' '" + Qt.btoa(ascii(text)) + "' | base64 -d > " + shellQuote(path) + " # w" + (++seq)
        kinds[cmd] = { kind: "write", path: path }
        ds.connectSource(cmd)
    }

    function readFile(path) {
        var cmd = "cat -- " + shellQuote(path) + " # r" + (++seq)
        kinds[cmd] = { kind: "read", path: path }
        ds.connectSource(cmd)
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            ds.disconnectSource(sourceName)
            var k = io.kinds[sourceName]
            delete io.kinds[sourceName]
            if (!k) {
                return
            }
            if (data["exit code"] !== 0) {
                var err = data["stderr"] ? data["stderr"].toString().trim() : ""
                io.failed(err.length > 0 ? err : "The file operation failed")
                return
            }
            if (k.kind === "write") {
                io.saved(k.path)
            } else {
                io.loaded(data["stdout"] ? data["stdout"].toString() : "")
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save launcher settings"
        fileMode: FileDialog.SaveFile
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        defaultSuffix: "json"
        onAccepted: io.writeFile(io.localPath(selectedFile), io.pendingText)
    }

    FileDialog {
        id: loadDialog
        title: "Load launcher settings"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        onAccepted: io.readFile(io.localPath(selectedFile))
    }
}
