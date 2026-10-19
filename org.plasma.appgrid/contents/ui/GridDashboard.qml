import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

Kicker.DashboardWindow {
    id: root

    property var backend
    readonly property string themeName: backend ? backend.themeName : "gnome"
    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property bool searching: query.length > 0

    property int openGroup: -1          // layout index of the opened group
    readonly property var powerDefs: ({
        lock: { name: "Lock screen", icon: "system-lock-screen" },
        sleep: { name: "Sleep", icon: "system-suspend" },
        hibernate: { name: "Hibernate", icon: "system-suspend-hibernate" },
        restart: { name: "Restart", icon: "system-reboot" },
        shutdown: { name: "Shut down", icon: "system-shutdown" },
        logout: { name: "Log out", icon: "system-log-out" }
    })
    readonly property var powerModel: {
        var ids = root.backend ? root.backend.powerActions.split(",") : []
        var r = []
        ids.forEach(function (id) {
            if (powerDefs[id]) {
                r.push({ id: id, name: powerDefs[id].name, icon: powerDefs[id].icon })
            }
        })
        return r
    }
    readonly property bool animOn: root.backend ? root.backend.animations : true
    readonly property int animMs: animOn ? 180 : 0
    property bool navActive: false      // keyboard selection is visible

    // in-window context menu state
    property var menuEntry: null
    property bool menuInGroup: false
    property point menuPos: Qt.point(0, 0)

    // rename prompt: layout index of the group being renamed, -1 = hidden
    property int renameIdx: -1

    readonly property bool mIsApp: menuEntry !== null && menuEntry.type === "app"
    readonly property bool mIsGroup: menuEntry !== null && menuEntry.type === "group"
    readonly property bool mCanMove: menuEntry !== null && (!searching || menuInGroup)
    readonly property var mTargets: computeTargets()

    // ---- sizing (icon size / spacing come from the settings; 0 / -1 = automatic) ----
    readonly property int cfgIcon: backend ? backend.cfgIconSize : 0
    readonly property int cfgH: backend ? backend.cfgHSpacing : -1
    readonly property int cfgV: backend ? backend.cfgVSpacing : -1
    readonly property int iconSz: cfgIcon > 0 ? cfgIcon : Kirigami.Units.iconSizes.huge
    readonly property int labelH: Math.round(Kirigami.Units.gridUnit * 2)
    readonly property int tileW: Math.round(iconSz * 1.4)
    readonly property int tileH: iconSz + 12 + labelH
    readonly property bool autoH: cfgH < 0
    readonly property int hGap: autoH ? Math.round(iconSz * 0.3) : cfgH
    readonly property int vGap: cfgV < 0 ? 0 : cfgV
    readonly property real sideMargin: Math.round(rootArea.width * 0.03)
    readonly property real availW: Math.max(1, rootArea.width - 2 * sideMargin)
    readonly property int cols: Math.max(1, Math.floor((availW + hGap) / (tileW + hGap)))
    // automatic spacing stretches the cells to fill the width; an explicit value is exact
    readonly property int cellW: autoH ? Math.floor(availW / cols) : tileW + hGap
    readonly property int cellH: tileH + vGap

    readonly property var viewEntries: computeView()
    readonly property var groupList: backend ? backend.displayLayout.filter(function (e) { return e.type === "group" }) : []
    readonly property var groupEntry: findGroup()

    function computeView() {
        if (!backend) {
            return []
        }
        if (query.length > 0) {
            var r = []
            for (var i = 0; i < backend.shownIds.length; i++) {
                var id = backend.shownIds[i]
                if (backend.appIndex[id].name.toLowerCase().indexOf(query) >= 0) {
                    r.push({ type: "app", id: id, idx: -1 })
                }
            }
            return r
        }
        return backend.displayLayout
    }

    function findGroup() {
        if (!backend || openGroup < 0) {
            return null
        }
        var d = backend.displayLayout
        for (var i = 0; i < d.length; i++) {
            if (d[i].idx === openGroup && d[i].type === "group") {
                return d[i]
            }
        }
        return null
    }

    // groups the menu's app could still be added to
    function computeTargets() {
        if (!backend || !mIsApp) {
            return []
        }
        var id = menuEntry.id
        return backend.displayLayout.filter(function (e) {
            return e.type === "group" && e.items.indexOf(id) < 0
        })
    }

    onGroupEntryChanged: {
        if (groupEntry === null) {
            openGroup = -1
        }
    }

    onQueryChanged: {
        navActive = false
        mainGrid.currentIndex = 0       // Enter launches the first result
    }

    function dismiss() {
        if (root.visible) {
            root.toggle()
        }
    }

    function activate(entry, viaKeyboard) {
        if (entry.type === "app") {
            backend.launch(entry.id)
            root.dismiss()
        } else {
            openGroup = entry.idx
            groupGrid.currentIndex = 0
            if (viaKeyboard) {
                navActive = true
            }
        }
    }

    // ---- keyboard navigation ----------------------------------------------------------
    // Typing goes to the search box (keyEventProxy); arrows etc. are handled here.
    function navigate(key) {
        var inGroup = groupEntry !== null
        var g = inGroup ? groupGrid : mainGrid
        var n = inGroup ? groupEntry.items.length : viewEntries.length
        if (n === 0) {
            return
        }
        var colsN = inGroup ? Math.max(1, Math.min(n, groupPanel.gcols)) : cols
        var rowsVisible = Math.max(1, Math.floor(g.height / cellH))
        var cur = g.currentIndex
        var firstTouch = !navActive && !(searching && !inGroup && cur >= 0 && cur < n)
        navActive = true
        if (cur < 0 || cur >= n) {
            cur = 0
            firstTouch = true
        }
        if (firstTouch) {
            // first key press only reveals the selection
            cur = (key === Qt.Key_End) ? n - 1 : 0
        } else {
            switch (key) {
            case Qt.Key_Left:
                cur = Math.max(0, cur - 1)
                break
            case Qt.Key_Right:
                cur = Math.min(n - 1, cur + 1)
                break
            case Qt.Key_Up:
                if (cur - colsN >= 0) {
                    cur -= colsN
                }
                break
            case Qt.Key_Down:
                if (cur + colsN < n) {
                    cur += colsN
                } else if (Math.floor(cur / colsN) < Math.floor((n - 1) / colsN)) {
                    cur = n - 1
                }
                break
            case Qt.Key_PageUp:
                cur = Math.max(0, cur - colsN * rowsVisible)
                break
            case Qt.Key_PageDown:
                cur = Math.min(n - 1, cur + colsN * rowsVisible)
                break
            case Qt.Key_Home:
                cur = 0
                break
            case Qt.Key_End:
                cur = n - 1
                break
            }
        }
        g.currentIndex = cur
        g.positionViewAtIndex(cur, GridView.Contain)
    }

    function currentEntry() {
        if (groupEntry !== null) {
            var i = groupGrid.currentIndex
            if (i >= 0 && i < groupEntry.items.length) {
                return { type: "app", id: groupEntry.items[i], idx: -1 }
            }
            return null
        }
        var j = mainGrid.currentIndex
        if (searching) {
            if (!navActive || j < 0 || j >= viewEntries.length) {
                j = 0
            }
        } else if (!navActive) {
            return null
        }
        return (j >= 0 && j < viewEntries.length) ? viewEntries[j] : null
    }

    function activateCurrent() {
        var e = currentEntry()
        if (e !== null) {
            activate(e, true)
        }
    }

    function menuForCurrent() {
        var e = currentEntry()
        if (e === null) {
            return
        }
        var inGroup = groupEntry !== null
        var g = inGroup ? groupGrid : mainGrid
        var item = g.itemAtIndex(g.currentIndex)
        if (!item) {
            return
        }
        var p = item.mapToItem(rootArea, item.width / 2, item.height / 2)
        showMenu(e, inGroup, p.x, p.y)
    }

    function handleKey(ev) {
        if (renameIdx >= 0 || menuEntry !== null) {
            return false
        }
        var typing = searchField.text.length > 0 && !navActive
        switch (ev.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_PageUp:
        case Qt.Key_PageDown:
            navigate(ev.key)
            return true
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Home:
        case Qt.Key_End:
            if (typing) {
                return false        // move the text cursor instead
            }
            navigate(ev.key)
            return true
        case Qt.Key_Tab:
            navigate(Qt.Key_Right)
            return true
        case Qt.Key_Backtab:
            navigate(Qt.Key_Left)
            return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activateCurrent()
            return true
        case Qt.Key_Menu:
            menuForCurrent()
            return true
        }
        return false
    }

    // ---- context menu -----------------------------------------------------------
    function showMenu(entry, inGroup, x, y) {
        menuEntry = entry
        menuInGroup = inGroup
        menuPos = Qt.point(x, y)
    }

    function closeMenu() {
        menuEntry = null
    }

    function menuOpen() {
        var e = menuEntry
        closeMenu()
        activate(e)
    }

    function menuMove(d) {
        var e = menuEntry
        closeMenu()
        if (e.type === "app") {
            backend.moveApp(e.id, d)
        } else {
            backend.moveGroup(e.idx, d)
        }
    }

    function menuNewGroup() {
        var e = menuEntry
        closeMenu()
        var gi = backend.newGroup(e.id, "Group")
        openGroup = -1
        if (gi >= 0) {
            startRename(gi)
        }
    }

    function menuAddTo(gi) {
        var e = menuEntry
        closeMenu()
        backend.addToGroup(e.id, gi)
        openGroup = -1
    }

    function menuRemoveFromGroup() {
        var e = menuEntry
        closeMenu()
        backend.removeFromGroup(e.id)
        openGroup = -1
    }

    function menuRename() {
        var e = menuEntry
        closeMenu()
        startRename(e.idx)
    }

    function menuUngroup() {
        var e = menuEntry
        closeMenu()
        backend.ungroup(e.idx)
        openGroup = -1
    }

    // ---- rename prompt --------------------------------------------------------------
    function startRename(gi) {
        var g = backend.layout[gi]
        nameField.text = g ? g.name : "Group"
        renameIdx = gi
        Qt.callLater(function () {
            nameField.forceActiveFocus()
            nameField.selectAll()
        })
    }

    function acceptName(name) {
        var n = name.trim()
        if (renameIdx >= 0 && n.length > 0) {
            backend.renameGroup(renameIdx, n)
        }
        cancelName()
    }

    function cancelName() {
        renameIdx = -1
        searchField.forceActiveFocus()
    }

    backgroundColor: pal.backdrop
    keyEventProxy: renameIdx >= 0 ? null : searchField

    onKeyEscapePressed: {
        if (renameIdx >= 0) {
            cancelName()
        } else if (menuEntry !== null) {
            closeMenu()
        } else if (searchField.text.length > 0) {
            searchField.text = ""
        } else if (openGroup >= 0) {
            openGroup = -1
        } else {
            root.dismiss()
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchField.forceActiveFocus()
            if (root.animOn) {
                openAnim.restart()
            } else {
                openAnim.stop()
                rootArea.opacity = 1
                rootArea.scale = 1
            }
        } else {
            searchField.text = ""
            openGroup = -1
            menuEntry = null
            renameIdx = -1
            navActive = false
            mainGrid.currentIndex = -1
        }
    }

    MouseArea {
        id: rootArea
        anchors.fill: parent
        transformOrigin: Item.Center

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: rootArea; property: "opacity"; from: 0; to: 1; duration: root.animMs * 1.4; easing.type: Easing.OutCubic }
            NumberAnimation { target: rootArea; property: "scale"; from: 1.04; to: 1; duration: root.animMs * 1.6; easing.type: Easing.OutCubic }
        }
        onClicked: {
            if (root.openGroup >= 0) {
                root.openGroup = -1
            } else {
                root.dismiss()
            }
        }

        AppTheme {
            id: pal
            theme: root.themeName
            custom: root.backend ? root.backend.themeCustom : ({})
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.sideMargin
            anchors.rightMargin: root.sideMargin
            anchors.topMargin: Kirigami.Units.gridUnit * 2
            anchors.bottomMargin: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.gridUnit

            Item {
                id: topBar
                Layout.fillWidth: true
                Layout.preferredHeight: searchField.implicitHeight

                Field {
                    id: searchField
                    colors: pal
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 20
                    placeholderText: "Search apps…"
                    Keys.onPressed: event => {
                        if (root.handleKey(event)) {
                            event.accepted = true
                        }
                    }
                    onAccepted: root.activateCurrent()
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: root.powerModel

                        delegate: IconBtn {
                            required property var modelData
                            colors: pal
                            width: topBar.height
                            height: topBar.height
                            iconName: modelData.icon
                            tip: modelData.name
                            boundsWidth: root.width
                            onClicked: {
                                root.dismiss()
                                if (root.backend) {
                                    root.backend.runPower(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            GridView {
                id: mainGrid
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.preferredWidth: root.cols * root.cellW
                cellWidth: root.cellW
                cellHeight: root.cellH
                clip: true
                currentIndex: -1
                interactive: contentHeight > height   // native wheel/touchpad scrolling
                boundsBehavior: Flickable.StopAtBounds
                model: root.viewEntries
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                delegate: Tile {
                    animated: root.animOn
                    required property var modelData
                    width: root.cellW
                    height: root.cellH
                    entry: modelData
                    backend: root.backend
                    colors: pal
                    iconSz: root.iconSz
                    selected: GridView.isCurrentItem && root.groupEntry === null
                              && (root.navActive || root.searching)
                    onActivated: root.activate(entry)
                    onMouseMoved: root.navActive = false
                    onMenuRequested: (mx, my) => {
                        var p = mapToItem(rootArea, mx, my)
                        root.showMenu(entry, false, p.x, p.y)
                    }
                }
            }
        }

        QQC2.Label {
            anchors.centerIn: parent
            visible: root.backend && root.backend.shownIds.length === 0
            color: pal.text
            text: root.backend && root.backend.allIds.length === 0 ? "Loading applications…" : "No apps to show"
        }

        // ---- opened group: wide, fully opaque ---------------------------------------------
        Rectangle {
            id: groupPanel
            visible: root.groupEntry !== null
            anchors.centerIn: parent
            readonly property int count: root.groupEntry ? root.groupEntry.items.length : 0
            width: Math.round(rootArea.width * 0.8)
            readonly property int gcols: Math.max(1, Math.floor((width - 64) / root.cellW))
            readonly property int grows: Math.max(1, Math.ceil(count / gcols))
            height: Math.min(rootArea.height * 0.85, 130 + grows * root.cellH)
            radius: 28
            color: pal.popupBg
            border.width: 1
            border.color: pal.popupBorder
            transformOrigin: Item.Center

            onVisibleChanged: {
                if (visible && root.animOn) {
                    groupAnim.restart()
                } else {
                    groupAnim.stop()
                    opacity = 1
                    scale = 1
                }
            }
            ParallelAnimation {
                id: groupAnim
                NumberAnimation { target: groupPanel; property: "opacity"; from: 0; to: 1; duration: root.animMs; easing.type: Easing.OutCubic }
                NumberAnimation { target: groupPanel; property: "scale"; from: 0.92; to: 1; duration: root.animMs * 1.3; easing.type: Easing.OutBack }
            }

            MouseArea {
                anchors.fill: parent   // swallow clicks so they do not close the group
                acceptedButtons: Qt.AllButtons
            }

            QQC2.Label {
                id: groupTitle
                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.groupEntry ? root.groupEntry.name : ""
                color: pal.text
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 1.5)
            }

            GridView {
                id: groupGrid
                anchors.top: groupTitle.bottom
                anchors.topMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, Math.min(groupPanel.count, groupPanel.gcols)) * root.cellW
                cellWidth: root.cellW
                cellHeight: root.cellH
                clip: true
                currentIndex: 0
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                model: root.groupEntry
                       ? root.groupEntry.items.map(function (id) { return { type: "app", id: id, idx: -1 } })
                       : []
                delegate: Tile {
                    animated: root.animOn
                    required property var modelData
                    width: root.cellW
                    height: root.cellH
                    entry: modelData
                    backend: root.backend
                    colors: pal
                    iconSz: root.iconSz
                    selected: GridView.isCurrentItem && root.navActive
                    onActivated: root.activate(entry)
                    onMouseMoved: root.navActive = false
                    onMenuRequested: (mx, my) => {
                        var p = mapToItem(rootArea, mx, my)
                        root.showMenu(entry, true, p.x, p.y)
                    }
                }
            }
        }

        // ---- context menu (plain QML, no popups) -------------------------------------------
        Item {
            id: menuLayer
            anchors.fill: parent
            visible: root.menuEntry !== null
            z: 1000

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeMenu()
            }

            Rectangle {
                id: menuBox
                x: Math.max(8, Math.min(root.menuPos.x, menuLayer.width - width - 8))
                y: Math.max(8, Math.min(root.menuPos.y, menuLayer.height - height - 8))
                width: Kirigami.Units.gridUnit * 14
                height: menuCol.implicitHeight + 16
                radius: 12
                color: pal.menuBg
                border.width: 1
                border.color: pal.popupBorder
                transformOrigin: Item.TopLeft

                Connections {
                    target: menuLayer
                    function onVisibleChanged() {
                        if (menuLayer.visible && root.animOn) {
                            menuAnim.restart()
                        } else {
                            menuAnim.stop()
                            menuBox.opacity = 1
                            menuBox.scale = 1
                        }
                    }
                }
                ParallelAnimation {
                    id: menuAnim
                    NumberAnimation { target: menuBox; property: "opacity"; from: 0; to: 1; duration: root.animMs * 0.7 }
                    NumberAnimation { target: menuBox; property: "scale"; from: 0.94; to: 1; duration: root.animMs * 0.8; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: menuCol
                    x: 8
                    y: 8
                    width: parent.width - 16

                    MenuRow {
                        colors: pal
                        text: root.mIsGroup ? "Open group" : "Open"
                        onTriggered: root.menuOpen()
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mCanMove
                        text: "Move earlier"
                        onTriggered: root.menuMove(-1)
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mCanMove
                        text: "Move later"
                        onTriggered: root.menuMove(1)
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mIsApp
                        text: "New group with this app…"
                        onTriggered: root.menuNewGroup()
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mIsApp && root.mTargets.length > 0
                        header: true
                        text: "Add to group"
                    }
                    Repeater {
                        model: root.mTargets
                        delegate: MenuRow {
                            required property var modelData
                            colors: pal
                            text: "    " + modelData.name
                            onTriggered: root.menuAddTo(modelData.idx)
                        }
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mIsApp && root.menuInGroup
                        text: "Remove from group"
                        onTriggered: root.menuRemoveFromGroup()
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mIsGroup
                        text: "Rename group…"
                        onTriggered: root.menuRename()
                    }
                    MenuRow {
                        colors: pal
                        visible: root.mIsGroup
                        text: "Ungroup"
                        onTriggered: root.menuUngroup()
                    }
                }
            }
        }

        // ---- rename prompt (plain QML, no dialog) ----------------------------------------------
        Item {
            id: renameLayer
            anchors.fill: parent
            visible: root.renameIdx >= 0
            z: 1100

            Rectangle {
                anchors.fill: parent
                color: pal.scrim
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.cancelName()
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height / 3)
                width: Kirigami.Units.gridUnit * 22
                height: renameCol.implicitHeight + 40
                radius: 18
                color: pal.popupBg
                border.width: 1
                border.color: pal.popupBorder

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: renameCol
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 12

                    QQC2.Label {
                        text: "Group name"
                        color: pal.text
                        font.bold: true
                    }
                    Field {
                        id: nameField
                        colors: pal
                        width: parent.width
                        placeholderText: "Group name"
                        onAccepted: root.acceptName(text)
                    }
                    Row {
                        spacing: 8
                        anchors.right: parent.right
                        Btn {
                            colors: pal
                            text: "Cancel"
                            onClicked: root.cancelName()
                        }
                        Btn {
                            colors: pal
                            primary: true
                            text: "OK"
                            onClicked: root.acceptName(nameField.text)
                        }
                    }
                }
            }
        }
    }
}
