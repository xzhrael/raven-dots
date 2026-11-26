pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    // Session-scoped order for unpinned running apps (keeps separator boundary intact)
    property var unpinnedOrder: []

    function isPinned(appId) {
        return Config.options.dock.pinnedApps.indexOf(appId) !== -1;
    }

    function togglePin(appId) {
        if (root.isPinned(appId)) {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appId)
        } else {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.concat([appId])
        }
    }

    function reorderApp(fromIndex, toIndex) {
        const currentApps = root.apps;
        if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;
        if (fromIndex >= currentApps.length || toIndex >= currentApps.length) return;

        const sepIdx = currentApps.findIndex(a => a.appId === "SEPARATOR");
        const movingEntry = currentApps[fromIndex];
        if (!movingEntry || movingEntry.appId === "SEPARATOR") return;

        if (movingEntry.pinned) {
            const pinned = Array.from(Config.options.dock.pinnedApps);
            const maxIdx = sepIdx >= 0 ? sepIdx - 1 : pinned.length - 1;
            const clampedTo = Math.max(0, Math.min(toIndex, maxIdx));
            if (fromIndex === clampedTo || fromIndex >= pinned.length) return;
            const [item] = pinned.splice(fromIndex, 1);
            pinned.splice(clampedTo, 0, item);
            Config.options.dock.pinnedApps = pinned;
        } else {
            const startIdx = sepIdx >= 0 ? sepIdx + 1 : 0;
            const clampedTo = Math.max(startIdx, Math.min(toIndex, currentApps.length - 1));
            const subFrom = fromIndex - startIdx;
            const subTo = clampedTo - startIdx;
            if (subFrom === subTo || subFrom < 0) return;

            let runningIds = [];
            for (let i = startIdx; i < currentApps.length; i++) {
                runningIds.push(currentApps[i].appId);
            }
            const [item] = runningIds.splice(subFrom, 1);
            runningIds.splice(subTo, 0, item);
            root.unpinnedOrder = runningIds;
        }
    }

    property list<var> apps: {
        var map = new Map();

        // Pinned apps
        const pinnedApps = Config.options?.dock.pinnedApps ?? [];
        for (const appId of pinnedApps) {
            if (!map.has(appId.toLowerCase())) map.set(appId.toLowerCase(), ({
                pinned: true,
                toplevels: []
            }));
        }

        // Separator
        if (pinnedApps.length > 0) {
            map.set("SEPARATOR", { pinned: false, toplevels: [] });
        }

        // Ignored apps
        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));
        // Open windows
        var unpinnedMap = new Map();
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            const key = toplevel.appId.toLowerCase();
            if (map.has(key)) {
                map.get(key).toplevels.push(toplevel);
            } else {
                if (!unpinnedMap.has(key)) {
                    unpinnedMap.set(key, { pinned: false, toplevels: [] });
                }
                unpinnedMap.get(key).toplevels.push(toplevel);
            }
        }

        var values = [];

        for (const [key, value] of map) {
            values.push(appEntryComp.createObject(null, { appId: key, toplevels: value.toplevels, pinned: value.pinned }));
        }

        // Append unpinned running apps respecting session unpinnedOrder
        const order = root.unpinnedOrder ?? [];
        for (const orderedKey of order) {
            if (unpinnedMap.has(orderedKey)) {
                const val = unpinnedMap.get(orderedKey);
                values.push(appEntryComp.createObject(null, { appId: orderedKey, toplevels: val.toplevels, pinned: false }));
                unpinnedMap.delete(orderedKey);
            }
        }
        for (const [key, value] of unpinnedMap) {
            values.push(appEntryComp.createObject(null, { appId: key, toplevels: value.toplevels, pinned: false }));
        }

        return values;
    }

    component TaskbarAppEntry: QtObject {
        id: wrapper
        required property string appId
        required property list<var> toplevels
        required property bool pinned
    }
    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
