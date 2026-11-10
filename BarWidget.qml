import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "fire1.clear-notifications"
  ipcTarget: "fire1.clear-notifications"

  // Third-party bar plugins only get a narrow notifications proxy (DND). Toast
  // count and dismiss APIs are not on that proxy, so count comes from the same
  // live.json the daemon writes, and actions go through omarchy-shell IPC.
  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property string livePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    + "/omarchy/notifications/live.json"
  property int toastCount: 0
  readonly property bool hasToasts: toastCount > 0
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb === true : false
  readonly property bool replaceStockSilence: truthySetting("replaceStockSilence", true)
  readonly property bool showSilenceToggle: truthySetting("showSilenceToggle", true)

  function truthySetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === 1) return true
    if (value === false || value === 0 || value === null || value === undefined) return false
    var text = String(value).trim().toLowerCase()
    if (text === "true" || text === "1" || text === "on" || text === "yes") return true
    if (text === "false" || text === "0" || text === "off" || text === "no") return false
    return !!fallback
  }

  property bool cursorActive: false
  property int cursorIndex: 0
  property bool settingsSeen: false
  property string lastSilenceMode: ""

  // Keep clear/dismiss/invoke clickable even if the count watcher lags: IPC is
  // cheap and returns none when the deck is empty.
  readonly property var actions: [
    { id: "clearAll", icon: "󰵙", labelKey: "action.clearAll", needsToasts: false },
    { id: "dismissOne", icon: "󰅙", labelKey: "action.dismissOne", needsToasts: false },
    { id: "history", icon: "󰋚", labelKey: "action.history", needsToasts: false },
    { id: "invokeLast", icon: "󰳾", labelKey: "action.invokeLast", needsToasts: false }
  ]

  readonly property int menuItemCount: actions.length + (showSilenceToggle ? 1 : 0)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function syncScript() {
    var url = Qt.resolvedUrl("bin/sync-stock-silence").toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    try { url = decodeURIComponent(url) } catch (e) {}
    return url
  }

  function syncStockSilence() {
    if (!settingsSeen) return
    var mode = replaceStockSilence ? "on" : "off"
    if (mode === lastSilenceMode) return
    lastSilenceMode = mode
    Quickshell.execDetached([syncScript(), mode])
  }

  function readLive(text) {
    try {
      var value = JSON.parse(String(text || "[]"))
      toastCount = Array.isArray(value) ? value.length : 0
    } catch (e) {
      toastCount = 0
    }
  }

  function runShell(method) {
    if (bar) bar.run("omarchy-shell notifications " + method)
  }

  function runAction(id) {
    if (id === "clearAll")
      runShell("dismissAll")
    else if (id === "dismissOne")
      runShell("dismissOne")
    else if (id === "history")
      runShell("showHistory")
    else if (id === "invokeLast")
      runShell("invokeLast")
    close()
  }

  FileView {
    path: root.livePath
    watchChanges: true
    printErrors: false
    onLoaded: root.readLive(text())
    onLoadFailed: root.readLive("[]")
    onFileChanged: reload()
  }

  function toggleDnd() {
    if (!notificationService) return
    notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
  }

  function moveCursor(dy) {
    cursorActive = true
    var max = menuItemCount - 1
    if (max < 0) return
    cursorIndex = Math.max(0, Math.min(max, cursorIndex + dy))
  }

  function activateCursor() {
    if (!cursorActive) {
      cursorActive = true
      return
    }
    if (showSilenceToggle && cursorIndex >= actions.length)
      toggleDnd()
    else
      runAction(actions[cursorIndex].id)
  }

  onSettingsChanged: {
    settingsSeen = true
    syncStockSilence()
  }

  Component.onCompleted: {
    // Settings may already be present before onSettingsChanged fires.
    Qt.callLater(function() {
      settingsSeen = true
      syncStockSilence()
    })
  }

  // Hot-reload and disable both destroy this item. Only restore stock
  // Silence when the addon is on and the plugin is leaving the bar, which
  // disable/remove do; a reload immediately re-applies `on` from onCompleted.
  Component.onDestruction: {
    if (replaceStockSilence)
      Quickshell.execDetached([syncScript(), "off"])
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    Qt.callLater(function() {
      if (panel.loadedContent) panel.loadedContent.forceActiveFocus()
    })
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.dnd ? "󰂛" : "󰂚"
    active: root.hasToasts || root.dnd
    tooltipText: root.dnd
      ? strings.t("tooltip.silenced")
      : (root.hasToasts
        ? strings.tn("tooltip.open", root.toastCount).arg(Commons.I18n.formatNumber(root.toastCount))
        : strings.t("tooltip.empty"))
    onPressed: function(b) {
      if (b === Qt.RightButton)
        root.runAction("clearAll")
      else if (b === Qt.MiddleButton)
        root.toggleDnd()
      else
        root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: strings.t("title")
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          text: root.hasToasts
            ? strings.tn("status.count", root.toastCount).arg(Commons.I18n.formatNumber(root.toastCount))
            : strings.t("status.empty")
          color: Qt.darker(root.bar.foreground, 1.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: parent.width
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.actions

            Button {
              required property var modelData
              required property int index
              width: parent.width
              leftAlign: true
              bordered: true
              iconText: modelData.icon
              text: strings.t(modelData.labelKey)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              verticalPadding: Style.space(10)
              enabled: !modelData.needsToasts || root.hasToasts
              opacity: enabled ? 1 : 0.45
              hasCursor: root.cursorActive && root.cursorIndex === index
              onHovered: function(on) {
                if (!on) return
                root.cursorActive = true
                root.cursorIndex = index
              }
              onClicked: if (enabled) root.runAction(modelData.id)
            }
          }
        }

        Toggle {
          visible: root.showSilenceToggle
          width: parent.width
          label: strings.t("action.silence")
          description: strings.t("action.silenceHint")
          checked: root.dnd
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          hasCursor: root.cursorActive && root.cursorIndex === root.actions.length
          onHovered: function(on) {
            if (!on) return
            root.cursorActive = true
            root.cursorIndex = root.actions.length
          }
          onClicked: root.toggleDnd()
        }
      }
    }
  }
}
