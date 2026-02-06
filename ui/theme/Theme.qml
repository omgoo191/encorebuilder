import QtQuick 2.15
import QtQuick.Controls.Material 2.15

QtObject {
    id: theme

    property int materialTheme: Material.Light
    readonly property bool isDark: materialTheme === Material.Dark

    readonly property color surface: isDark ? "#1e1e1e" : "#ffffff"
    readonly property color surfaceVariant: isDark ? "#2a2a2a" : "#f8fafc"
    readonly property color textPrimary: isDark ? "#f1f5f9" : "#1e293b"
    readonly property color textSecondary: isDark ? "#cbd5e1" : "#374151"
    readonly property color border: isDark ? "#475569" : "#e2e8f0"

    readonly property color success: isDark ? "#34d399" : "#22c55e"
    readonly property color warning: isDark ? "#fbbf24" : "#f59e0b"
    readonly property color danger: isDark ? "#f87171" : "#dc2626"
    readonly property color accent: isDark ? "#60a5fa" : "#3b82f6"
}
