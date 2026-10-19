import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Layout editor. Everything here is saved in this widget's own config (layoutJson,
// hiddenJson); the system application menu is never modified.
KCM.SimpleKCM {
    id: page

    property string cfg_layoutJson
    property string cfg_layoutJsonDefault
    property string cfg_hiddenJson
    property string cfg_hiddenJsonDefault
    property string cfg_appCatalogJson
    property string cfg_appCatalogJsonDefault

    property var catalog: ({})        // id -> {id, name, icon}
    property var catalogIds: []
    property var layout: []           // [{type:"app", id} | {type:"group", name, gid, items:[id]}]
    property var hidden: ({})         // id -> true for apps hidden from the launcher
    property var collapsed: ({})      // gid -> true when the group's apps are folded away here
    property string lastWritten: ""
    property string lastHiddenWritten: ""

    readonly property string filter: filterField.text.trim().toLowerCase()
    readonly property bool filtering: filter.length > 0
    readonly property bool ready: catalogIds.length > 0
    readonly property var groups: groupsList()

    onCfg_layoutJsonChanged: {
        if (cfg_layoutJson !== lastWritten) {
            reload()
        }
    }
    onCfg_hiddenJsonChanged: {
        if (cfg_hiddenJson !== lastHiddenWritten) {
            reload()
        }
    }
    onCfg_appCatalogJsonChanged: reload()
    Component.onCompleted: reload()

    // ---- data helpers --------------------------------------------------------------
    function nameOf(id) {
        return catalog[id] ? catalog[id].name : id
    }

    function iconOf(id) {
        var c = catalog[id]
        return (c && c.icon) ? c.icon : id.replace(/\.desktop$/, "")
    }

    function newGid() {
        return "g" + Date.now().toString(36) + Math.random().toString(36).slice(2, 7)
    }

    function groupsList() {
        var r = []
        for (var i = 0; i < layout.length; i++) {
            if (layout[i].type === "group") {
                r.push({ gi: i, name: layout[i].name })
            }
        }
        return r
    }

    function matches(e) {
        if (!filtering) {
            return true
        }
        if (e.type === "app") {
            return nameOf(e.id).toLowerCase().indexOf(filter) >= 0
        }
        if (e.name.toLowerCase().indexOf(filter) >= 0) {
            return true
        }
        return e.items.some(function (id) { return nameOf(id).toLowerCase().indexOf(filter) >= 0 })
    }

    function itemMatches(id) {
        return !filtering || nameOf(id).toLowerCase().indexOf(filter) >= 0
    }

    function isShown(id) {
        return hidden[id] !== true
    }

    function isCollapsed(gid) {
        return collapsed[gid] === true
    }

    function groupAllHidden(g) {
        return g.items.length > 0 && g.items.every(function (id) { return hidden[id] === true })
    }

    function reload() {
        var cat = []
        try {
            cat = JSON.parse(cfg_appCatalogJson)
        } catch (e) {
            cat = []
        }
        var map = {}, ids = []
        for (var i = 0; i < cat.length; i++) {
            map[cat[i].id] = cat[i]
            ids.push(cat[i].id)
        }
        var saved = []
        try {
            saved = JSON.parse(cfg_layoutJson)
            if (!Array.isArray(saved)) {
                saved = []
            }
        } catch (e2) {
            saved = []
        }
        var h = {}
        try {
            var hv = JSON.parse(cfg_hiddenJson)
            if (Array.isArray(hv)) {
                hv.forEach(function (id) { h[id] = true })
            }
        } catch (e3) {
            h = {}
        }
        hidden = h
        catalog = map
        catalogIds = ids
        if (ids.length === 0) {
            layout = saved       // cannot normalize yet; editing is disabled until the catalog exists
            return
        }
        // keep only installed apps, each exactly once, and append apps not placed yet
        var placed = {}, out = []
        saved.forEach(function (e) {
            if (e.type === "app") {
                if (map[e.id] && !placed[e.id]) {
                    placed[e.id] = true
                    out.push({ type: "app", id: e.id })
                }
            } else if (e.type === "group") {
                var items = (e.items || []).filter(function (id) {
                    if (!map[id] || placed[id]) {
                        return false
                    }
                    placed[id] = true
                    return true
                })
                out.push({ type: "group", name: e.name || "Group", gid: e.gid || newGid(), items: items })
            }
        })
        ids.forEach(function (id) {
            if (!placed[id]) {
                out.push({ type: "app", id: id })
            }
        })
        layout = out
    }

    // ---- drag and drop (drag the grip at the left of a row) ---------------------------------
    property var dragSrc: null
    property var dropInfo: null          // {t, mode, x, y, w, h} while hovering a valid target
    property string ghostText: ""
    property string ghostIcon: ""
    property point ghostPos: Qt.point(0, 0)
    property real lastSceneY: 0
    readonly property bool dragging: dragSrc !== null

    function dragStart(info, text, icon) {
        dragSrc = info
        ghostText = text
        ghostIcon = icon
        dropInfo = null
        autoScroll.start()
    }

    function hitTest(p) {
        for (var n = 0; n < rep.count; n++) {
            var d = rep.itemAt(n)
            if (!d || !d.visible) {
                continue
            }
            for (var c = 0; c < d.children.length; c++) {
                var ch = d.children[c]
                if (ch.dnd === undefined || !ch.visible || ch.height <= 0) {
                    continue
                }
                var l = ch.mapFromItem(wrap, p.x, p.y)
                if (l.x >= 0 && l.x <= ch.width && l.y >= 0 && l.y <= ch.height) {
                    var top = ch.mapToItem(wrap, 0, 0)
                    return { t: ch.dnd, f: l.y / ch.height, x: top.x, y: top.y, w: ch.width, h: ch.height }
                }
            }
        }
        return null
    }

    function sameTarget(a, b) {
        if (a.kind === "group") {
            return b.kind === "group" && a.gid === b.gid
        }
        return b.kind !== "group" && a.id === b.id
    }

    function computeDrop(p) {
        var hit = hitTest(p)
        if (!hit || !dragSrc) {
            return null
        }
        var t = hit.t, src = dragSrc, mode = ""
        if (sameTarget(src, t)) {
            return null
        }
        if (src.kind === "group") {
            if (t.kind === "item") {
                return null
            }
            mode = hit.f < 0.5 ? "before" : "after"
        } else if (t.kind === "group") {
            mode = hit.f < 0.3 ? "before" : "into"
        } else {
            mode = hit.f < 0.5 ? "before" : "after"
        }
        return { t: t, mode: mode, x: hit.x, y: hit.y, w: hit.w, h: hit.h }
    }

    function dragMove(sx, sy) {
        if (!dragging) {
            return
        }
        lastSceneY = sy
        var p = wrap.mapFromItem(null, sx, sy)
        ghostPos = Qt.point(p.x + 14, p.y + 10)
        dropInfo = computeDrop(p)
    }

    function dragEnd(sx, sy) {
        if (!dragging) {
            return
        }
        var p = wrap.mapFromItem(null, sx, sy)
        var drop = computeDrop(p)
        var src = dragSrc
        dragCancel()
        if (drop) {
            applyDrop(src, drop.t, drop.mode)
        }
    }

    function dragCancel() {
        autoScroll.stop()
        dragSrc = null
        dropInfo = null
    }

    function gidIndex(gid) {
        for (var i = 0; i < layout.length; i++) {
            if (layout[i].type === "group" && layout[i].gid === gid) {
                return i
            }
        }
        return -1
    }

    function appIndex(id) {
        for (var i = 0; i < layout.length; i++) {
            if (layout[i].type === "app" && layout[i].id === id) {
                return i
            }
        }
        return -1
    }

    function applyDrop(src, t, mode) {
        var obj
        if (src.kind === "item") {
            obj = { type: "app", id: layout[src.gi].items.splice(src.k, 1)[0] }
        } else {
            obj = layout.splice(src.i, 1)[0]
        }
        var after = mode === "after" ? 1 : 0
        if (t.kind === "item") {
            var gi = gidIndex(t.gid)
            if (gi < 0) { return }
            layout[gi].items.splice(layout[gi].items.indexOf(t.id) + after, 0, obj.id)
        } else if (t.kind === "group" && mode === "into") {
            var gj = gidIndex(t.gid)
            if (gj < 0) { return }
            layout[gj].items.push(obj.id)
        } else {
            var idx = t.kind === "group" ? gidIndex(t.gid) : appIndex(t.id)
            if (idx < 0) { return }
            layout.splice(idx + after, 0, obj)
        }
        commit()
    }

    Timer {
        id: autoScroll
        interval: 16
        repeat: true
        onTriggered: {
            var f = page.flickable
            if (!f) {
                return
            }
            var vy = page.lastSceneY - f.mapToItem(null, 0, 0).y
            var edge = Kirigami.Units.gridUnit * 2
            var step = 0
            if (vy < edge) {
                step = -Math.ceil((edge - vy) / 4)
            } else if (vy > f.height - edge) {
                step = Math.ceil((vy - (f.height - edge)) / 4)
            }
            if (step !== 0) {
                f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY + step))
            }
        }
    }

    // ---- edit operations (all end in commit) ---------------------------------------
    function commit() {
        var y = page.flickable ? page.flickable.contentY : 0
        var s = JSON.stringify(layout)
        lastWritten = s
        cfg_layoutJson = s
        layout = layout.slice()
        Qt.callLater(function () {
            if (page.flickable) {
                page.flickable.contentY = y
            }
        })
    }

    function swapAt(arr, i, d) {
        var j = i + d
        if (j < 0 || j >= arr.length) {
            return false
        }
        var t = arr[i]
        arr[i] = arr[j]
        arr[j] = t
        return true
    }

    function moveEntry(i, d) {
        if (swapAt(layout, i, d)) {
            commit()
        }
    }

    function moveItem(gi, ii, d) {
        if (swapAt(layout[gi].items, ii, d)) {
            commit()
        }
    }

    function addToGroup(i, gi) {
        var e = layout[i], g = layout[gi]
        if (!e || e.type !== "app" || !g || g.type !== "group") {
            return
        }
        layout.splice(i, 1)
        g.items.push(e.id)
        commit()
    }

    function moveItemToGroup(gi, ii, gj) {
        var g2 = layout[gj]
        if (!g2 || g2.type !== "group" || gi === gj) {
            return
        }
        var id = layout[gi].items.splice(ii, 1)[0]
        g2.items.push(id)
        commit()
    }

    function removeFromGroup(gi, ii) {
        var id = layout[gi].items.splice(ii, 1)[0]
        layout.splice(gi + 1, 0, { type: "app", id: id })
        commit()
    }

    function ungroup(gi) {
        var apps = layout[gi].items.map(function (id) { return { type: "app", id: id } })
        Array.prototype.splice.apply(layout, [gi, 1].concat(apps))
        commit()
    }

    function renameGroup(gi, name) {
        var n = name.trim()
        if (n.length > 0 && layout[gi].name !== n) {
            layout[gi].name = n
            commit()
        }
    }

    function createGroup(name) {
        var n = name.trim()
        layout.unshift({ type: "group", name: n.length > 0 ? n : "Group", gid: newGid(), items: [] })
        newGroupField.text = ""
        commit()
    }

    function resetAll() {
        lastWritten = "[]"
        cfg_layoutJson = "[]"
        lastHiddenWritten = "[]"
        cfg_hiddenJson = "[]"
        reload()
    }

    // ---- show / hide (hidden apps stay in the layout but are not shown in the launcher) ----
    function setShownMany(ids, on) {
        var h = {}
        for (var k in hidden) {
            h[k] = true
        }
        ids.forEach(function (id) {
            if (on) {
                delete h[id]
            } else {
                h[id] = true
            }
        })
        hidden = h
        var s = JSON.stringify(Object.keys(h).sort())
        lastHiddenWritten = s
        cfg_hiddenJson = s
    }

    function setShown(id, on) {
        setShownMany([id], on)
    }

    // ---- collapse / expand groups in this page only ------------------------------------------
    function toggleCollapsed(gid) {
        var c = {}
        for (var k in collapsed) {
            c[k] = collapsed[k]
        }
        c[gid] = !collapsed[gid]
        collapsed = c
    }

    function setAllCollapsed(v) {
        var c = {}
        layout.forEach(function (e) {
            if (e.type === "group") {
                c[e.gid] = v
            }
        })
        collapsed = c
    }

    component Grip: Item {
        id: grip
        signal begin()
        signal moved(real sx, real sy)
        signal ended(real sx, real sy)
        signal canceled()

        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: "handle-sort"
            opacity: ma.containsMouse || ma.pressed ? 1 : 0.55
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: grip.begin()
            onPositionChanged: mouse => {
                if (pressed) {
                    var g = mapToItem(null, mouse.x, mouse.y)
                    grip.moved(g.x, g.y)
                }
            }
            onReleased: mouse => {
                var g = mapToItem(null, mouse.x, mouse.y)
                grip.ended(g.x, g.y)
            }
            onCanceled: grip.canceled()
            QQC2.ToolTip.text: "Drag to reorder, or drop onto a group to add it"
            QQC2.ToolTip.visible: containsMouse && !pressed
            QQC2.ToolTip.delay: 600
        }
    }

    // ---- one app row (used at top level and inside groups) --------------------------
    component AppRow: RowLayout {
        id: ar

        property string label
        property string iconName
        property bool shown: true
        property bool canUp: false
        property bool canDown: false
        property bool inGroup: false
        property var targets: []          // [{gi, name}]
        property var dnd: ({})

        signal shownToggled(bool on)
        signal moveUp()
        signal moveDown()
        signal moveToGroup(int gi)
        signal moveOut()
        signal dragBegin()
        signal dragMoved(real sx, real sy)
        signal dragEnded(real sx, real sy)
        signal dragCanceled()

        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.preferredWidth: ar.inGroup ? Kirigami.Units.gridUnit * 2 : 0
        }
        Grip {
            onBegin: ar.dragBegin()
            onMoved: (sx, sy) => ar.dragMoved(sx, sy)
            onEnded: (sx, sy) => ar.dragEnded(sx, sy)
            onCanceled: ar.dragCanceled()
        }
        QQC2.CheckBox {
            checked: ar.shown
            onToggled: ar.shownToggled(checked)
            QQC2.ToolTip.text: "Show in launcher"
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: 600
        }
        Kirigami.Icon {
            source: ar.iconName
            fallback: "application-x-executable"
            opacity: ar.shown ? 1 : 0.4
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: ar.label
            elide: Text.ElideRight
            opacity: ar.shown ? 1 : 0.5
        }
        QQC2.ToolButton {
            icon.name: "go-up"
            enabled: ar.canUp
            onClicked: ar.moveUp()
            QQC2.ToolTip.text: "Move up"
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: 600
        }
        QQC2.ToolButton {
            icon.name: "go-down"
            enabled: ar.canDown
            onClicked: ar.moveDown()
            QQC2.ToolTip.text: "Move down"
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: 600
        }
        QQC2.Button {
            visible: ar.inGroup
            text: "Remove from group"
            onClicked: ar.moveOut()
        }
        QQC2.ComboBox {
            enabled: ar.targets.length > 0
            model: ar.targets
            textRole: "name"
            currentIndex: -1
            displayText: ar.inGroup ? "Move to group…" : "Add to group…"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            onActivated: i => {
                ar.moveToGroup(ar.targets[i].gi)
                currentIndex = -1
            }
        }
    }

    // ---- page ---------------------------------------------------------------------------
    Item {
        id: wrap
        implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Arrange, group and hide the apps shown in this launcher. These settings are stored in this widget only; the system application menu is not changed. Untick an app to hide it from the launcher. Changes apply when you press Apply or OK."
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !page.ready
            type: Kirigami.MessageType.Warning
            text: "The application list isn't available yet. Open the launcher once, then reopen these settings."
        }

        RowLayout {
            Layout.fillWidth: true
            enabled: page.ready

            QQC2.TextField {
                id: filterField
                Layout.fillWidth: true
                placeholderText: "Filter apps… (moving up/down is disabled while filtering)"
            }
            QQC2.Button {
                text: "Collapse groups"
                icon.name: "arrow-right"
                onClicked: page.setAllCollapsed(true)
            }
            QQC2.Button {
                text: "Expand groups"
                icon.name: "arrow-down"
                onClicked: page.setAllCollapsed(false)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            enabled: page.ready

            QQC2.TextField {
                id: newGroupField
                Layout.fillWidth: true
                placeholderText: "New group name"
                onAccepted: page.createGroup(text)
            }
            QQC2.Button {
                text: "Create group"
                icon.name: "folder-new"
                onClicked: page.createGroup(newGroupField.text)
            }
            QQC2.Button {
                text: "Reset layout"
                icon.name: "edit-reset"
                onClicked: page.resetAll()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Repeater {
            id: rep
            model: page.ready ? page.layout : []

            delegate: ColumnLayout {
                id: entry

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 0
                visible: page.matches(modelData)

                // top-level app
                AppRow {
                    Layout.fillWidth: true
                    visible: entry.modelData.type === "app"
                    label: entry.modelData.type === "app" ? page.nameOf(entry.modelData.id) : ""
                    iconName: entry.modelData.type === "app" ? page.iconOf(entry.modelData.id) : ""
                    shown: entry.modelData.type === "app" ? page.isShown(entry.modelData.id) : true
                    canUp: !page.filtering && entry.index > 0
                    canDown: !page.filtering && entry.index < page.layout.length - 1
                    targets: page.groups
                    dnd: ({ kind: "app", i: entry.index, id: entry.modelData.type === "app" ? entry.modelData.id : "" })
                    onDragBegin: page.dragStart(dnd, label, iconName)
                    onDragMoved: (sx, sy) => page.dragMove(sx, sy)
                    onDragEnded: (sx, sy) => page.dragEnd(sx, sy)
                    onDragCanceled: page.dragCancel()
                    onShownToggled: on => page.setShown(entry.modelData.id, on)
                    onMoveUp: page.moveEntry(entry.index, -1)
                    onMoveDown: page.moveEntry(entry.index, 1)
                    onMoveToGroup: gi => page.addToGroup(entry.index, gi)
                }

                // group header
                RowLayout {
                    Layout.fillWidth: true
                    id: groupHead
                    visible: entry.modelData.type === "group"
                    spacing: Kirigami.Units.smallSpacing
                    property var dnd: ({ kind: "group", i: entry.index, gid: entry.modelData.type === "group" ? entry.modelData.gid : "" })

                    Grip {
                        onBegin: page.dragStart(groupHead.dnd, entry.modelData.name, "folder")
                        onMoved: (sx, sy) => page.dragMove(sx, sy)
                        onEnded: (sx, sy) => page.dragEnd(sx, sy)
                        onCanceled: page.dragCancel()
                    }
                    QQC2.ToolButton {
                        icon.name: page.isCollapsed(entry.modelData.gid) ? "arrow-right" : "arrow-down"
                        onClicked: page.toggleCollapsed(entry.modelData.gid)
                        QQC2.ToolTip.text: page.isCollapsed(entry.modelData.gid) ? "Show the apps in this group" : "Fold away the apps in this group"
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: 600
                    }
                    Kirigami.Icon {
                        source: "folder"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: entry.modelData.type === "group" ? entry.modelData.name : ""
                        font.bold: true
                        onEditingFinished: page.renameGroup(entry.index, text)
                    }
                    QQC2.Label {
                        text: entry.modelData.type === "group" ? entry.modelData.items.length + " apps" : ""
                        opacity: 0.6
                    }
                    QQC2.ToolButton {
                        icon.name: (entry.modelData.type === "group" && page.groupAllHidden(entry.modelData)) ? "view-visible" : "view-hidden"
                        enabled: entry.modelData.type === "group" && entry.modelData.items.length > 0
                        onClicked: page.setShownMany(entry.modelData.items, page.groupAllHidden(entry.modelData))
                        QQC2.ToolTip.text: (entry.modelData.type === "group" && page.groupAllHidden(entry.modelData)) ? "Show every app in this group" : "Hide every app in this group"
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: 600
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: !page.filtering && entry.index > 0
                        onClicked: page.moveEntry(entry.index, -1)
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: !page.filtering && entry.index < page.layout.length - 1
                        onClicked: page.moveEntry(entry.index, 1)
                    }
                    QQC2.Button {
                        text: "Ungroup"
                        onClicked: page.ungroup(entry.index)
                    }
                }

                // apps inside the group (hidden while folded away, unless filtering)
                Repeater {
                    model: entry.modelData.type === "group" ? entry.modelData.items : []

                    delegate: AppRow {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        visible: (page.filtering || !page.isCollapsed(entry.modelData.gid)) && page.itemMatches(modelData)
                        inGroup: true
                        label: page.nameOf(modelData)
                        iconName: page.iconOf(modelData)
                        shown: page.isShown(modelData)
                        canUp: !page.filtering && index > 0
                        canDown: !page.filtering && index < entry.modelData.items.length - 1
                        targets: page.groups.filter(function (g) { return g.gi !== entry.index })
                        dnd: ({ kind: "item", gi: entry.index, k: index, id: modelData, gid: entry.modelData.gid })
                        onDragBegin: page.dragStart(dnd, label, iconName)
                        onDragMoved: (sx, sy) => page.dragMove(sx, sy)
                        onDragEnded: (sx, sy) => page.dragEnd(sx, sy)
                        onDragCanceled: page.dragCancel()
                        onShownToggled: on => page.setShown(modelData, on)
                        onMoveUp: page.moveItem(entry.index, index, -1)
                        onMoveDown: page.moveItem(entry.index, index, 1)
                        onMoveOut: page.removeFromGroup(entry.index, index)
                        onMoveToGroup: gi => page.moveItemToGroup(entry.index, index, gi)
                    }
                }

                Item {
                    Layout.preferredHeight: Kirigami.Units.smallSpacing
                    visible: entry.modelData.type === "group"
                }
            }
        }
    }

    // drop indicator + floating label while dragging
    Rectangle {
        visible: page.dropInfo !== null
        z: 50
        x: page.dropInfo ? page.dropInfo.x : 0
        y: page.dropInfo ? (page.dropInfo.mode === "after" ? page.dropInfo.y + page.dropInfo.h - 1
                            : (page.dropInfo.mode === "before" ? page.dropInfo.y - 1 : page.dropInfo.y)) : 0
        width: page.dropInfo ? page.dropInfo.w : 0
        height: page.dropInfo ? (page.dropInfo.mode === "into" ? page.dropInfo.h : 3) : 0
        radius: 2
        color: page.dropInfo && page.dropInfo.mode === "into" ? "transparent" : Kirigami.Theme.highlightColor
        border.width: page.dropInfo && page.dropInfo.mode === "into" ? 2 : 0
        border.color: Kirigami.Theme.highlightColor
    }

    Rectangle {
        visible: page.dragging
        z: 60
        x: page.ghostPos.x
        y: page.ghostPos.y
        width: ghostRow.implicitWidth + Kirigami.Units.largeSpacing * 2
        height: ghostRow.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: 6
        opacity: 0.92
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.highlightColor

        RowLayout {
            id: ghostRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: page.ghostIcon
                fallback: "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.Label {
                text: page.ghostText
            }
        }
    }
    }
}
