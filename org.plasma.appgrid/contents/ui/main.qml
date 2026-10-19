import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: main

    // id -> {name, icon, row}; built from the (read-only) system apps model
    property var appIndex: ({})
    property var allIds: []
    // OUR layout (persisted in this applet's own config, never in the system menu):
    //   [{type:"app", id}, {type:"group", name, items:[id,...]}]
    property var layout: []
    // layout filtered to installed apps, each entry carries idx = position in layout
    property var displayLayout: []
    property QtObject appsModel: null
    property QtObject dash: null
    property string dashError: ""
    property var hiddenSet: ({})            // app ids hidden via the settings page
    property var shownIds: []               // allIds minus hidden ones (used by search)
    readonly property string themeName: Plasmoid.configuration.theme
    readonly property int cfgIconSize: Plasmoid.configuration.iconSize
    readonly property int cfgHSpacing: Plasmoid.configuration.hSpacing
    readonly property int cfgVSpacing: Plasmoid.configuration.vSpacing
    readonly property var themeCustom: ({
        enabled: Plasmoid.configuration.useCustomColors,
        backdrop: Plasmoid.configuration.colorBackdrop,
        backdropOpacity: Plasmoid.configuration.colorBackdropOpacity,
        popup: Plasmoid.configuration.colorPopup,
        text: Plasmoid.configuration.colorText,
        accent: Plasmoid.configuration.colorAccent
    })

    // Same trick the stock Application Dashboard uses: the panel button is the
    // *full* representation and there is no compact one, so Plasma never opens
    // its own popup.
    preferredRepresentation: fullRepresentation
    compactRepresentation: null
    fullRepresentation: buttonComponent

    toolTipMainText: "App Grid Launcher"
    toolTipSubText: dashError

    Plasmoid.icon: Plasmoid.configuration.icon

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Reset Layout"
            icon.name: "edit-reset"
            onTriggered: main.resetLayout()
        }
    ]

    // ---- system app model (read only) -----------------------------------
    Kicker.RootModel {
        id: rootModel
        appNameFormat: 0 // app name only
        flat: true
        showSeparators: false
        appletInterface: main
        showAllApps: true
        showTopLevelItems: false
        onRefreshed: main.refreshModel()

        Component.onCompleted: {
            favoritesModel.initForClient("org.example.appgrid.favorites.instance-" + Plasmoid.id)
        }
    }

    function refreshModel() {
        // pick the child model holding the most entries ("All Applications")
        var best = null, bestCount = -1
        for (var r = 0; r < rootModel.count; r++) {
            var m = rootModel.modelForRow(r)
            if (m && m.count > bestCount) {
                best = m
                bestCount = m.count
            }
        }
        console.log("[appgrid] root rows:", rootModel.count, "apps in best model:", bestCount)
        appsModel = best
    }

    // hidden repeater: reads roles from the model into appIndex
    Repeater {
        id: appRepeater
        model: main.appsModel
        delegate: Item {
            required property int index
            required property string display
            required property var decoration
            required property string favoriteId
            width: 0
            height: 0
        }
        onItemAdded: rebuildTimer.restart()
        onItemRemoved: rebuildTimer.restart()
    }

    Timer {
        id: rebuildTimer
        interval: 50
        onTriggered: main.rebuild()
    }

    function rebuild() {
        var map = {}, ids = []
        for (var i = 0; i < appRepeater.count; i++) {
            var it = appRepeater.itemAt(i)
            if (!it || !it.favoriteId || map[it.favoriteId] !== undefined) {
                continue
            }
            map[it.favoriteId] = { name: it.display, icon: it.decoration, row: it.index }
            ids.push(it.favoriteId)
        }
        ids.sort(function (a, b) { return map[a].name.localeCompare(map[b].name) })
        appIndex = map
        allIds = ids
        publishCatalog(ids, map)
        console.log("[appgrid] indexed apps:", ids.length)
        computeDisplay()
    }

    function launch(fid) {
        var info = appIndex[fid]
        if (info && appsModel) {
            appsModel.trigger(info.row, "", null)
        }
    }

    // ---- layout logic ------------------------------------------------------
    function load() {
        try {
            var v = JSON.parse(Plasmoid.configuration.layoutJson)
            layout = Array.isArray(v) ? v : []
        } catch (e) {
            layout = []
        }
    }

    function loadHidden() {
        var m = {}
        try {
            var v = JSON.parse(Plasmoid.configuration.hiddenJson)
            if (Array.isArray(v)) {
                v.forEach(function (id) { m[id] = true })
            }
        } catch (e) {
            m = {}
        }
        hiddenSet = m
    }

    function isShown(id) {
        return appIndex[id] !== undefined && hiddenSet[id] !== true
    }

    property string lastSaved: ""

    function save() {
        lastSaved = JSON.stringify(layout)
        Plasmoid.configuration.layoutJson = lastSaved
    }

    // the settings page changed layoutJson (not us): pick it up
    function reloadFromConfig() {
        if (Plasmoid.configuration.layoutJson === lastSaved) {
            return
        }
        load()
        computeDisplay()
    }

    // let the settings page list installed apps (it cannot reach the system model itself)
    function publishCatalog(ids, map) {
        var cat = ids.map(function (id) {
            var ic = map[id].icon
            return { id: id, name: map[id].name, icon: (typeof ic === "string") ? ic : "" }
        })
        var s = JSON.stringify(cat)
        if (s !== Plasmoid.configuration.appCatalogJson) {
            Plasmoid.configuration.appCatalogJson = s
        }
    }

    function computeDisplay() {
        if (allIds.length > 0) {
            // append apps we have not placed yet (new installs); in memory until next save
            var placed = {}
            for (var i = 0; i < layout.length; i++) {
                var e = layout[i]
                if (e.type === "app") {
                    placed[e.id] = true
                } else {
                    for (var k = 0; k < e.items.length; k++) {
                        placed[e.items[k]] = true
                    }
                }
            }
            for (var n = 0; n < allIds.length; n++) {
                if (!placed[allIds[n]]) {
                    layout.push({ type: "app", id: allIds[n] })
                }
            }
        }
        var out = []
        for (var j = 0; j < layout.length; j++) {
            var en = layout[j]
            if (en.type === "app") {
                if (isShown(en.id)) {
                    out.push({ type: "app", id: en.id, idx: j })
                }
            } else {
                var items = en.items.filter(function (id) { return isShown(id) })
                if (items.length > 0) {
                    out.push({ type: "group", name: en.name, items: items, idx: j })
                }
            }
        }
        shownIds = allIds.filter(function (id) { return isShown(id) })
        displayLayout = out
    }

    function commit() {
        layout = layout.filter(function (e) { return e.type !== "group" || e.items.length > 0 })
        save()
        computeDisplay()
    }

    function findApp(fid) {
        for (var i = 0; i < layout.length; i++) {
            var e = layout[i]
            if (e.type === "app" && e.id === fid) {
                return { gi: -1, i: i }
            }
            if (e.type === "group") {
                var j = e.items.indexOf(fid)
                if (j >= 0) {
                    return { gi: i, i: j }
                }
            }
        }
        return null
    }

    function detach(fid) {
        var p = findApp(fid)
        if (!p) {
            return
        }
        if (p.gi < 0) {
            layout.splice(p.i, 1)
        } else {
            layout[p.gi].items.splice(p.i, 1)
        }
    }

    function idVisible(id) {
        return isShown(id)
    }

    function entryVisible(e) {
        if (e.type === "app") {
            return isShown(e.id)
        }
        return e.items.some(function (id) { return isShown(id) })
    }

    // swap with the nearest neighbour that is actually shown (skips uninstalled apps)
    function swapVisible(arr, i, d, vis) {
        var j = i + d
        while (j >= 0 && j < arr.length && !vis(arr[j])) {
            j += d
        }
        if (j < 0 || j >= arr.length) {
            return
        }
        var t = arr[i]
        arr[i] = arr[j]
        arr[j] = t
    }

    function moveApp(fid, delta) {
        var p = findApp(fid)
        if (!p) {
            return
        }
        if (p.gi < 0) {
            swapVisible(layout, p.i, delta, entryVisible)
        } else {
            swapVisible(layout[p.gi].items, p.i, delta, idVisible)
        }
        commit()
    }

    function moveGroup(gi, delta) {
        swapVisible(layout, gi, delta, entryVisible)
        commit()
    }

    // new group holding only `fid` (taken from wherever it is); returns the group's layout index
    function newGroup(fid, name) {
        var p = findApp(fid)
        if (!p) {
            return -1
        }
        var g = { type: "group", name: name.length > 0 ? name : "Group", items: [fid] }
        if (p.gi < 0) {
            layout.splice(p.i, 1, g)
        } else {
            layout[p.gi].items.splice(p.i, 1)
            layout.push(g)
        }
        commit()
        return layout.indexOf(g)
    }

    // drag-and-drop: app `a` joins top-level app `b` in a new group at b's place
    function groupApps(a, b) {
        if (a === b) {
            return -1
        }
        var pb = findApp(b)
        if (!findApp(a) || !pb || pb.gi >= 0) {
            return -1
        }
        var g = { type: "group", name: "Group", items: [b, a] }
        detach(a)
        var p2 = findApp(b)
        layout.splice(p2.i, 1, g)
        commit()
        return layout.indexOf(g)
    }

    function addToGroup(fid, gi) {
        var g = layout[gi]
        if (!g || g.type !== "group") {
            return
        }
        detach(fid)
        g.items.push(fid)
        commit()
    }

    function removeFromGroup(fid) {
        var p = findApp(fid)
        if (!p || p.gi < 0) {
            return
        }
        layout[p.gi].items.splice(p.i, 1)
        layout.splice(p.gi + 1, 0, { type: "app", id: fid })
        commit()
    }

    function renameGroup(gi, name) {
        if (layout[gi] && layout[gi].type === "group" && name.length > 0) {
            layout[gi].name = name
            commit()
        }
    }

    function ungroup(gi) {
        var g = layout[gi]
        if (!g || g.type !== "group") {
            return
        }
        var apps = g.items.map(function (id) { return { type: "app", id: id } })
        Array.prototype.splice.apply(layout, [gi, 1].concat(apps))
        commit()
    }

    function resetLayout() {
        layout = []
        commit()
    }

    // ---- dashboard window ----------------------------------------------------
    // Loaded lazily and defensively (like upstream's Qt.createComponent), so a
    // problem in GridDashboard.qml can never stop the panel button from showing.
    function loadDash() {
        var c = Qt.createComponent(Qt.resolvedUrl("GridDashboard.qml"))
        if (c.status === Component.Ready) {
            dash = c.createObject(main, { backend: main })
            if (!dash) {
                dashError = "Could not create the dashboard window"
            }
        } else {
            dashError = "Dashboard failed to load: " + c.errorString()
        }
        if (dashError.length > 0) {
            console.warn("[appgrid] " + dashError)
        }
    }

    function toggleDash() {
        if (dash) {
            dash.toggle()
        } else {
            console.warn("[appgrid] no dashboard window; " + dashError)
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            main.toggleDash()
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onLayoutJsonChanged() {
            main.reloadFromConfig()
        }
        function onHiddenJsonChanged() {
            main.loadHidden()
            main.computeDisplay()
        }
    }

    Component {
        id: buttonComponent

        Item {
            id: button
            readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

            Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : height
            Layout.minimumHeight: vertical ? width : Kirigami.Units.iconSizes.small

            Kirigami.Icon {
                anchors.fill: parent
                source: (Plasmoid.configuration.useCustomButtonImage && Plasmoid.configuration.customButtonImage) ? Plasmoid.configuration.customButtonImage : (Plasmoid.configuration.icon || "view-app-grid")
                active: mouse.containsMouse
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: main.toggleDash()
            }
        }
    }

    property var runner: null
    readonly property bool animations: Plasmoid.configuration.animations
    readonly property string powerActions: Plasmoid.configuration.powerActions

    function runPower(id) {
        if (!runner) {
            var c = Qt.createComponent(Qt.resolvedUrl("Runner.qml"))
            if (c.status === Component.Ready) {
                runner = c.createObject(main)
            } else {
                console.warn("[appgrid] power buttons unavailable: " + c.errorString())
                return
            }
        }
        var cmds = {
            lock: "loginctl lock-session",
            sleep: "systemctl suspend",
            hibernate: "systemctl hibernate",
            restart: "systemctl reboot",
            shutdown: "systemctl poweroff",
            logout: "dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout || qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout || qdbus-qt6 org.kde.LogoutPrompt /LogoutPrompt promptLogout || loginctl terminate-session self"
        }
        if (cmds[id]) {
            runner.run(cmds[id])
        }
    }

    Component.onCompleted: {
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = false
        }
        load()
        loadHidden()
        loadDash()
        rootModel.refresh()
    }
}
