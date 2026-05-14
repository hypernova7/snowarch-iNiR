import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    defaultConfig: ({
        placementStrategy: "leastBusy", preset: "default",
        size: 200, tempSize: 80, iconSize: 80,
        showTemp: true, showIcon: true, showCondition: false,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 100, y: 100
    })

    readonly property int shapeSize: Math.round((Config.getNestedValue("background.widgets.weather.size", 200)) * scaleFactor)
    readonly property int tempFontSize: Math.round((Config.getNestedValue("background.widgets.weather.tempSize", 80)) * scaleFactor)
    readonly property int weatherIconSize: Math.round((Config.getNestedValue("background.widgets.weather.iconSize", 80)) * scaleFactor)
    readonly property bool showTemp: Config.getNestedValue("background.widgets.weather.showTemp", true)
    readonly property bool showIcon: Config.getNestedValue("background.widgets.weather.showIcon", true)
    readonly property bool showCondition: Config.getNestedValue("background.widgets.weather.showCondition", false)
    readonly property int weatherPadding: Math.round((Config.getNestedValue("background.widgets.weather.padding", 20)) * scaleFactor)
    readonly property int tempFontWeight: Config.getNestedValue("background.widgets.weather.tempFontWeight", 500)
    readonly property real conditionOpacity: Config.getNestedValue("background.widgets.weather.conditionOpacity", 0.7)

    implicitHeight: backgroundShape.implicitHeight
    implicitWidth: backgroundShape.implicitWidth
    resizableAxes: ({ uniform: "size" })
    resizeMinWidth: 80
    resizeMinHeight: 80

    editPopoverContent: Component {
        GridLayout {
            columns: 3
            columnSpacing: 4
            rowSpacing: 4
            Repeater {
                model: [
                    { label: "Temp", icon: "thermostat", key: "showTemp", active: root.showTemp },
                    { label: "Icon", icon: "cloud", key: "showIcon", active: root.showIcon },
                    { label: "Text", icon: "text_fields", key: "showCondition", active: root.showCondition }
                ]
                SelectionGroupButton {
                    required property var modelData
                    Layout.fillWidth: true
                    leftmost: true; rightmost: true
                    buttonIcon: modelData.icon
                    buttonText: modelData.label
                    toggled: modelData.active
                    onClicked: Config.setNestedValue("background.widgets.weather." + modelData.key, !modelData.active)
                }
            }
        }
    }

    // Dim factor (0..1)
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.weather.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    StyledDropShadow {
        target: backgroundShape
    }

    MaterialShape {
        id: backgroundShape
        anchors.fill: parent
        shape: MaterialShape.Shape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: root.shapeSize
        opacity: 1.0 - root.dimFactor * 0.6

        StyledText {
            visible: root.showTemp
            font {
                pixelSize: root.tempFontSize
                family: Appearance.font.family.expressive
                weight: root.tempFontWeight
            }
            color: Appearance.colors.colPrimary
            text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: root.weatherPadding
                topMargin: Math.round(root.weatherPadding * 1.2)
            }
        }

        MaterialSymbol {
            visible: root.showIcon
            iconSize: root.weatherIconSize
            color: Appearance.colors.colOnPrimaryContainer
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: root.weatherPadding
                bottomMargin: Math.round(root.weatherPadding * 1.2)
            }
        }

        StyledText {
            visible: root.showCondition
            font {
                pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                family: Appearance.font.family.main
            }
            color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, root.conditionOpacity)
            text: Weather.data?.weatherDescription ?? ""
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Math.round(root.weatherPadding * 0.4)
            }
        }
    }
}
