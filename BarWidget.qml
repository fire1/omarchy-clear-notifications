import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "fire1.clear-notifications"
  ipcTarget: "fire1.clear-notifications"

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property int toastCount: notificationService && notificationService.toasts
    ? notificationService.toasts.count
    : 0
  readonly property bool hasToasts: toastCount > 0
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb === true : false

  property bool cursorActive: false
  property int cursorIndex: 0

  readonly property var actions: [
    { id: "clearAll", icon: "󰵙", labelKey: "action.clearAll", needsToasts: true },
    { id: "dismissOne", icon: "󰅙", labelKey: "action.dismissOne", needsToasts: true },
    { id: "history", icon: "󰋚", labelKey: "action.history", needsToasts: false },
    { id: "invokeLast", icon: "󰳾", labelKey: "action.invokeLast", needsToasts: true }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function runAction(id) {
    if (id === "clearAll") {
      if (notificationService && notificationService.clearAll)
        notificationService.clearAll("dismissed", true)
      else if (bar)
        bar.run("omarchy-shell notifications dismissAll")
    } else if (id === "dismissOne") {
      if (notificationService && notificationService.dismissNewest)
        notificationService.dismissNewest(true)
      else if (bar)
        bar.run("omarchy-shell notifications dismissOne")
    } else if (id === "history") {
      if (bar) bar.run("omarchy-shell notifications showHistory")
    } else if (id === "invokeLast") {
      if (notificationService && notificationService.actOnNewest)
        notificationService.actOnNewest()
      else if (bar)
        bar.run("omarchy-shell notifications invokeLast")
    }
    close()
  }

  function toggleDnd() {
    if (!notificationService) return
    notificationService.setDoNotDisturb(!notificationService.doNotDisturb)
  }

  function moveCursor(dy) {
    cursorActive = true
    // actions + DND toggle at the end
    var max = actions.length
    cursorIndex = Math.max(0, Math.min(max, cursorIndex + dy))
  }

  function activateCursor() {
    if (!cursorActive) {
      cursorActive = true
      return
    }
    if (cursorIndex >= actions.length)
      toggleDnd()
    else
      runAction(actions[cursorIndex].id)
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
