// Monorail for GNOME (beta): keeps a strip per workspace and monitor, using the shared core
// (core/strip.js and core/layout.js, built from core-ts) for every decision about order, focus,
// widths, scrolling and frames. This file only connects the core to Mutter's windows.

import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

import {Strip} from './core/strip.js';
import {clampScroll, defaultLayoutConfig, layout, revealFocused} from './core/layout.js';

/** Strips kept while the extension is off (the screen is locked, or it's being updated), so
 * turning it back on puts every window back in the same order and width. Window ids only. */
let remembered = null;

/** The key of the strips that belong to no single workspace: with GNOME's default of workspaces
 * on the primary monitor only, every other monitor shows the same windows on every workspace, so
 * each of those monitors has one strip for all of them. */
const ALL_WORKSPACES = 'all-workspaces';

/** A parked window keeps this much of itself on its monitor (Mutter keeps 75 pixels on screen). */
const PARKED_ON_SCREEN = 76;

/** Fully maximised (both directions), on GNOME 45 to 49. */
const isMaximized = window => typeof window.is_maximized === 'function'
    ? window.is_maximized() : window.get_maximized() === Meta.MaximizeFlags.BOTH;
/** Maximised in either direction. */
const isPartlyMaximized = window => typeof window.get_maximized === 'function'
    ? window.get_maximized() !== 0 : window.is_maximized();

const sameFrame = (a, b) => Math.abs(a.x - b.x) <= 1 && Math.abs(a.y - b.y) <= 1 &&
    Math.abs(a.width - b.width) <= 1 && Math.abs(a.height - b.height) <= 1;

const intersects = (a, b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
const clamp = (value, min, max) => Math.max(min, Math.min(value, max));

export class Tiler {
    constructor(settings) {
        this._settings = settings;
        this.config = defaultLayoutConfig();
        this._readSettings();
        /** @type {Map<Meta.Workspace | ALL_WORKSPACES, Map<number, Strip>>} */
        this._strips = new Map();
        /** id → {window, workspace, monitor, signals} for every window being watched */
        this._watched = new Map();
        this._signals = [];
        this._layoutSource = 0;
    }

    _readSettings() {
        this.config.gap = this._settings.get_int('gap');
        this.config.edgeGap = this._settings.get_int('edge-gap');
        this.config.defaultWidth = this._settings.get_double('default-width');
    }

    enable() {
        const display = global.display;
        const connect = (object, signal, handler) => this._signals.push([object, object.connect(signal, handler)]);
        connect(display, 'window-created', (_d, window) => this._watch(window, true));
        connect(display, 'notify::focus-window', () => this._focusChanged());
        connect(display, 'grab-op-begin', (_d, window) => this._grabBegan(window));
        connect(display, 'grab-op-end', (_d, window) => this._grabEnded(window));
        connect(global.workspace_manager, 'workspace-removed', () => this._pruneWorkspaces());
        connect(global.workspace_manager, 'active-workspace-changed', () => this._workspaceChanged());
        connect(global.backend.get_monitor_manager(), 'monitors-changed', () => this._monitorsChanged());
        connect(this._settings, 'changed', () => {
            this._readSettings();
            this.scheduleLayout();
        });

        // Windows already open: back where they were if the extension was on before, otherwise
        // in the order they were opened.
        const order = remembered ?? [];
        const rank = id => {
            const i = order.findIndex(entry => entry.id === id);
            return i < 0 ? order.length : i;
        };
        const windows = global.get_window_actors()
            .map(actor => actor.get_meta_window())
            .filter(window => window)
            .sort((a, b) => rank(a.get_id()) - rank(b.get_id()) || a.get_stable_sequence() - b.get_stable_sequence());
        for (const window of windows) this._watch(window, false, order.find(entry => entry.id === window.get_id()));
        // Each strip (one per monitor and workspace) gets back its own focus and scroll.
        for (const saved of order.filter(entry => entry.focused)) {
            const entry = this._watched.get(saved.id);
            const strip = entry?.workspace ? this._stripFor(entry.workspace, entry.monitor, false) : undefined;
            if (strip?.focus(saved.id)) strip.scroll = saved.scroll;
        }
        remembered = null;
        this._focusChanged();
        this.layoutNow();
    }

    disable() {
        // Remember the strips, then bring every parked window back on screen.
        remembered = [];
        for (const monitors of this._strips.values()) {
            for (const strip of monitors.values()) {
                const focused = strip.focusedWindow;
                for (const column of strip.columns) {
                    for (const id of column.windows) {
                        remembered.push({id, width: column.width, isFullWidth: column.isFullWidth,
                            focused: id === focused, scroll: strip.scroll});
                    }
                }
            }
        }
        for (const entry of this._watched.values()) {
            this._setParked(entry, false);
            if (entry.workspace) this._bringOnScreen(entry.window, entry.monitor);
            this._unwatch(entry);
        }
        for (const [object, id] of this._signals) object.disconnect(id);
        this._signals = [];
        if (this._layoutSource) GLib.source_remove(this._layoutSource);
        this._layoutSource = 0;
        if (this._switchSource) GLib.source_remove(this._switchSource);
        this._switchSource = 0;
        if (this._later) global.compositor.get_laters().remove(this._later);
        this._later = 0;
        this._watched.clear();
        this._strips.clear();
    }

    // MARK: Which windows are tiled

    /** Normal, resizable windows that belong to one workspace and aren't dialogs. */
    isTileable(window) {
        if (window.get_window_type() !== Meta.WindowType.NORMAL) return false;
        if (window.get_transient_for() || window.is_attached_dialog()) return false;
        if (window.is_skip_taskbar() || window.is_override_redirect()) return false;
        if (!window.get_workspace()) return false;
        if (window.is_on_all_workspaces() && !this._sharedByMonitor(window)) return false;
        if (window.minimized || !window.allows_resize()) return false;
        return true;
    }

    /** On every workspace only because it's on a monitor that isn't the primary one (GNOME's
     * default: workspaces on the primary monitor only). */
    _sharedByMonitor(window) {
        return window.is_on_all_workspaces() && Meta.prefs_get_workspaces_only_on_primary() &&
            !window.is_on_primary_monitor();
    }

    /** The key of the strip for this workspace and monitor. */
    _keyFor(workspace, monitor) {
        return Meta.prefs_get_workspaces_only_on_primary() && monitor !== global.display.get_primary_monitor()
            ? ALL_WORKSPACES : workspace;
    }

    /** The real workspace behind a strip's key. */
    _workspaceOf(key) {
        return key === ALL_WORKSPACES ? global.workspace_manager.get_active_workspace() : key;
    }

    _watch(window, isNew, restore) {
        const id = window.get_id();
        if (this._watched.has(id)) return;
        const entry = {window, workspace: null, monitor: -1, signals: [], settle: 0, shown: !isNew};
        this._watched.set(id, entry);
        const refresh = () => this._refresh(entry);
        entry.signals.push(
            window.connect('unmanaged', () => this._forget(entry)),
            window.connect('workspace-changed', refresh),
            window.connect('notify::minimized', refresh),
            window.connect('notify::skip-taskbar', refresh),
            window.connect('notify::above', refresh),
            window.connect('notify::on-all-workspaces', refresh),
            window.connect('notify::window-type', refresh),
            window.connect('monitor-changed', () => this._monitorChanged(entry)),
        );
        if (isNew) {
            // A new window's type, parent and size are settled once it's shown (on Wayland, after
            // its first commit). A window opening on a workspace that isn't showing isn't shown
            // until that workspace is, so it's settled after a second at the latest.
            const settled = () => {
                if (entry.shown) return;
                entry.shown = true;
                if (entry.settle) GLib.source_remove(entry.settle);
                entry.settle = 0;
                this._refresh(entry);
            };
            entry.signals.push(window.connect('shown', settled));
            entry.settle = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
                entry.settle = 0;
                settled();
                return GLib.SOURCE_REMOVE;
            });
            return;
        }
        this._refresh(entry, restore);
    }

    _unwatch(entry) {
        for (const signal of entry.signals) entry.window.disconnect(signal);
        entry.signals = [];
        if (entry.settle) GLib.source_remove(entry.settle);
        entry.settle = 0;
    }

    _forget(entry) {
        const id = entry.window.get_id();
        this._unwatch(entry);
        this._watched.delete(id);
        this._takeOff(entry);
        this.scheduleLayout();
    }

    _stripFor(workspace, monitor, create) {
        let monitors = this._strips.get(workspace);
        if (!monitors) {
            if (!create) return undefined;
            monitors = new Map();
            this._strips.set(workspace, monitors);
        }
        let strip = monitors.get(monitor);
        if (!strip && create) {
            strip = new Strip();
            monitors.set(monitor, strip);
        }
        return strip;
    }

    _takeOff(entry) {
        if (!entry.workspace) return;
        this._setParked(entry, false);
        this._stripFor(entry.workspace, entry.monitor, false)?.remove(entry.window.get_id());
        entry.workspace = null;
        entry.monitor = -1;
        entry.placedParked = false;
        entry.requested = null;
    }

    /** Puts the window on the strip it belongs to, or takes it off when it shouldn't be tiled. */
    _refresh(entry, restore = undefined, followMonitor = false) {
        if (!entry.shown) return;
        const window = entry.window;
        // A parked window that had to wait over another monitor is still on its own strip, even if
        // Mutter now shows it on every workspace because of where it is.
        if (entry.workspace && entry.placedParked && !followMonitor &&
            this._sharedByMonitor(window) !== (entry.workspace === ALL_WORKSPACES)) return;
        const tileable = this.isTileable(window);
        const workspace = tileable ? (this._sharedByMonitor(window) ? ALL_WORKSPACES : window.get_workspace()) : null;
        // A tiled window stays on its monitor's strip unless it was moved to another monitor.
        const monitor = !tileable ? -1
            : !followMonitor && entry.workspace === workspace && entry.monitor >= 0 && entry.monitor < global.display.get_n_monitors()
                ? entry.monitor : window.get_monitor();
        if (entry.workspace === workspace && entry.monitor === monitor) return;
        // Moved from one monitor's strip to another's: it keeps its width, and takes that strip's
        // focus only if it has the keyboard focus (as with Super+Shift+arrow).
        const from = entry.workspace ? this._stripFor(entry.workspace, entry.monitor, false) : undefined;
        const at = from?.locate(window.get_id());
        const moved = tileable && at && entry.monitor !== monitor ? from.columns[at.column] : null;
        this._takeOff(entry);
        if (!tileable) {
            this.scheduleLayout();
            return;
        }
        if (isPartlyMaximized(window)) this._unmaximize(window);
        const strip = this._stripFor(workspace, monitor, true);
        const focused = global.display.focus_window === window;
        const width = restore ? restore.width : moved?.width ?? this.config.defaultWidth;
        strip.insert(window.get_id(), width, restore ? 'end' : 'afterFocused', restore || moved ? focused : true);
        if (restore?.isFullWidth) strip.columns[strip.locate(window.get_id()).column].isFullWidth = true;
        entry.workspace = workspace;
        entry.monitor = monitor;
        this.scheduleLayout();
    }

    _unmaximize(window) {
        try {
            window.unmaximize(Meta.MaximizeFlags.BOTH);
        } catch {
            window.unmaximize(); // GNOME 49 and later take no flags
        }
    }

    // MARK: Events

    _focusChanged() {
        const window = global.display.focus_window;
        const entry = window && this._watched.get(window.get_id());
        if (!entry?.workspace) return;
        const strip = this._stripFor(entry.workspace, entry.monitor, false);
        if (strip?.focus(window.get_id())) this.scheduleLayout();
    }

    _grabBegan(window) {
        const entry = window && this._watched.get(window.get_id());
        if (entry) entry.grabbed = true;
    }

    /** Moved to another monitor (Super+Shift+arrow, or the window menu): the window leaves its
     * strip, which closes the gap, and joins the strip of the monitor it's on now. Monorail's own
     * moves don't count, and a drag counts when it ends. */
    _monitorChanged(entry) {
        if (!entry.workspace || entry.grabbed || entry.placedParked) return;
        const window = entry.window;
        if (window.get_monitor() === entry.monitor) return;
        if (entry.requested && sameFrame(window.get_frame_rect(), entry.requested)) return;
        this._refresh(entry, undefined, true);
    }

    /** After a drag the window goes back in line; after a resize its column keeps the new width. */
    _grabEnded(window) {
        const entry = window && this._watched.get(window.get_id());
        if (!entry?.workspace) return;
        entry.grabbed = false;
        // Dragged to another monitor: it joins that monitor's strip.
        if (window.get_monitor() !== entry.monitor && !entry.placedParked) {
            this._refresh(entry, undefined, true);
            this.layoutNow();
            return;
        }
        const strip = this._stripFor(entry.workspace, entry.monitor, false);
        const area = this._workspaceOf(entry.workspace).get_work_area_for_monitor(entry.monitor);
        const frame = window.get_frame_rect();
        const at = strip?.locate(window.get_id());
        if (at && !strip.columns[at.column].isFullWidth) {
            const share = (frame.width + this.config.gap) / (Math.max(area.width - 2 * this.config.edgeGap, 1) + this.config.gap);
            if (Math.abs(share - strip.columns[at.column].width) > 0.01) strip.setWidth(share, window.get_id());
        }
        this.layoutNow();
    }

    /** Mutter shows a workspace's windows when switching to it, parked ones too: hide them again
     * once it has, and after the switch animation. */
    _workspaceChanged() {
        if (this._later) return;
        this._later = global.compositor.get_laters().add(Meta.LaterType.BEFORE_REDRAW, () => {
            this._later = 0;
            this.layoutNow();
            return GLib.SOURCE_REMOVE;
        });
        if (this._switchSource) GLib.source_remove(this._switchSource);
        this._switchSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
            this._switchSource = 0;
            this.layoutNow();
            return GLib.SOURCE_REMOVE;
        });
    }

    _pruneWorkspaces() {
        const manager = global.workspace_manager;
        const alive = new Set();
        for (let i = 0; i < manager.get_n_workspaces(); i++) alive.add(manager.get_workspace_by_index(i));
        for (const workspace of [...this._strips.keys()]) {
            if (workspace !== ALL_WORKSPACES && !alive.has(workspace)) this._strips.delete(workspace);
        }
    }

    _monitorsChanged() {
        // Windows on a monitor that's gone join the strip of the monitor they're on now.
        const count = global.display.get_n_monitors();
        for (const entry of this._watched.values()) {
            if (entry.workspace && entry.monitor >= count) {
                this._takeOff(entry);
                this._refresh(entry);
            }
        }
        this.scheduleLayout();
    }

    // MARK: Actions

    /** The strip of the focused window, or else of the active workspace's primary monitor. */
    focusedStrip() {
        const window = global.display.focus_window;
        const entry = window && this._watched.get(window.get_id());
        if (entry?.workspace) return this._stripFor(entry.workspace, entry.monitor, false);
        const workspace = global.workspace_manager.get_active_workspace();
        const monitor = global.display.get_current_monitor();
        return this._stripFor(this._keyFor(workspace, monitor), monitor, false);
    }

    /** Runs a shared action (spec/actions.json) on the focused strip. */
    perform(action) {
        const strip = this.focusedStrip();
        if (!strip || strip.isEmpty) return false;
        let changed = true;
        switch (action) {
        case 'focus-left': changed = strip.moveFocus('left'); break;
        case 'focus-right': changed = strip.moveFocus('right'); break;
        case 'focus-first': changed = strip.focus(strip.columns[0].windows[strip.columns[0].active]); break;
        case 'focus-last': {
            const last = strip.columns[strip.columns.length - 1];
            changed = strip.focus(last.windows[last.active]);
            break;
        }
        case 'move-left': changed = strip.moveFocused('left'); break;
        case 'move-right': changed = strip.moveFocused('right'); break;
        case 'cycle-width': strip.cycleWidth(this.config.widthPresets); break;
        case 'cycle-width-backward': strip.cycleWidth(this.config.widthPresets, false); break;
        case 'full-width': strip.toggleFullWidth(); break;
        default: return false;
        }
        this.layoutNow();
        const id = strip.focusedWindow;
        const window = id !== undefined ? this._watched.get(id)?.window : null;
        if (window && global.display.focus_window !== window) window.activate(global.get_current_time());
        return changed;
    }

    // MARK: Layout

    scheduleLayout() {
        if (this._layoutSource) return;
        this._layoutSource = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._layoutSource = 0;
            this.layoutNow();
            return GLib.SOURCE_REMOVE;
        });
    }

    /** Puts every tiled window where the core says, moving only those that aren't there yet. */
    layoutNow() {
        if (this._layoutSource) {
            GLib.source_remove(this._layoutSource);
            this._layoutSource = 0;
        }
        const active = global.workspace_manager.get_active_workspace();
        for (const [key, monitors] of this._strips) {
            for (const [monitor, strip] of monitors) {
                if (strip.isEmpty || monitor >= global.display.get_n_monitors()) continue;
                const area = this._workspaceOf(key).get_work_area_for_monitor(monitor);
                const viewport = {x: area.x, y: area.y, width: area.width, height: area.height};
                clampScroll(strip, this.config, viewport.width);
                revealFocused(strip, this.config, viewport.width);
                const showing = key === ALL_WORKSPACES || key === active;
                for (const placement of layout(strip, this.config, viewport)) {
                    const entry = this._watched.get(placement.window);
                    const window = entry?.window;
                    if (!window || window.is_fullscreen() || isMaximized(window)) continue;
                    // Mutter keeps at least 75 pixels of a window on screen, so a parked window
                    // would overlap its neighbour: it's hidden until it comes back.
                    this._setParked(entry, placement.isParked && showing);
                    entry.placedParked = placement.isParked;
                    const frame = placement.isParked ? this._parkingFrame(placement.frame, monitor, area) : placement.frame;
                    const requestedBefore = entry.requested;
                    entry.requested = frame;
                    if (sameFrame(window.get_frame_rect(), frame)) continue;
                    if (placement.isParked && requestedBefore && sameFrame(requestedBefore, frame)) continue;
                    // As a user move: Mutter would otherwise keep the whole window on screen.
                    window.move_resize_frame(true, frame.x, frame.y, frame.width, frame.height);
                }
            }
        }
    }

    /** Where a parked window waits: beside its monitor, as the core says, unless another monitor is
     * there. Then it waits just below its monitor (or above), so that it isn't over the other
     * monitor: Mutter would count it as that monitor's window. */
    _parkingFrame(frame, monitor, area) {
        const display = global.display;
        const others = [];
        for (let i = 0; i < display.get_n_monitors(); i++) {
            if (i !== monitor) others.push(display.get_monitor_geometry(i));
        }
        const free = f => !others.some(other => intersects(f, other));
        if (free(frame)) return frame;
        const x = clamp(frame.x, area.x, area.x + area.width - frame.width);
        const below = {x, y: area.y + area.height - PARKED_ON_SCREEN, width: frame.width, height: frame.height};
        if (free(below)) return below;
        const above = {x, y: area.y - frame.height + PARKED_ON_SCREEN, width: frame.width, height: frame.height};
        if (free(above)) return above;
        return frame;
    }

    _setParked(entry, parked) {
        const actor = entry.window.get_compositor_private();
        if (!actor) return;
        if (parked) {
            entry.parked = true;
            if (actor.visible) actor.hide();
        } else if (entry.parked) {
            entry.parked = false;
            const active = global.workspace_manager.get_active_workspace();
            if (!actor.visible && !entry.window.minimized && entry.window.located_on_workspace(active)) actor.show();
        }
    }

    _bringOnScreen(window, monitor) {
        if (monitor < 0 || monitor >= global.display.get_n_monitors() || !window.get_workspace()) return;
        const area = window.get_workspace().get_work_area_for_monitor(monitor);
        const frame = window.get_frame_rect();
        const width = Math.min(frame.width, area.width);
        const height = Math.min(frame.height, area.height);
        const x = clamp(frame.x, area.x, area.x + area.width - width);
        const y = clamp(frame.y, area.y, area.y + area.height - height);
        if (x !== frame.x || y !== frame.y || width !== frame.width || height !== frame.height)
            window.move_resize_frame(false, x, y, width, height);
    }

    // MARK: For the test interface

    state() {
        const manager = global.workspace_manager;
        const windows = global.get_window_actors().map(actor => actor.get_meta_window()).filter(w => w).map(window => {
            const entry = this._watched.get(window.get_id());
            const f = window.get_frame_rect();
            const parent = window.get_transient_for();
            return {
                id: window.get_id(),
                title: window.get_title(),
                wmClass: window.get_wm_class(),
                clientType: window.get_client_type() === Meta.WindowClientType.X11 ? 'x11' : 'wayland',
                type: window.get_window_type(),
                transientFor: parent ? parent.get_id() : null,
                resizable: window.allows_resize(),
                skipTaskbar: window.is_skip_taskbar(),
                tiled: Boolean(entry?.workspace),
                parked: Boolean(entry?.parked),
                visible: Boolean(window.get_compositor_private()?.visible),
                workspace: window.get_workspace()?.index() ?? -1,
                onAllWorkspaces: window.is_on_all_workspaces(),
                monitor: window.get_monitor(),
                stripMonitor: entry?.workspace ? entry.monitor : -1,
                minimized: window.minimized,
                focused: global.display.focus_window === window,
                frame: {x: f.x, y: f.y, width: f.width, height: f.height},
            };
        });
        const strips = [];
        for (const [key, monitors] of this._strips) {
            for (const [monitor, strip] of monitors) {
                strips.push({
                    // -1: the strip of a monitor that shows the same windows on every workspace
                    workspace: key === ALL_WORKSPACES ? -1 : key.index(),
                    monitor,
                    scroll: strip.scroll,
                    focusedColumn: strip.focusedColumn,
                    columns: strip.columns.map(c => ({windows: [...c.windows], width: c.width, isFullWidth: c.isFullWidth})),
                });
            }
        }
        const monitors = [];
        const active = manager.get_active_workspace();
        for (let i = 0; i < global.display.get_n_monitors(); i++) {
            const a = active.get_work_area_for_monitor(i);
            const g = global.display.get_monitor_geometry(i);
            monitors.push({
                index: i,
                primary: i === global.display.get_primary_monitor(),
                geometry: {x: g.x, y: g.y, width: g.width, height: g.height},
                workArea: {x: a.x, y: a.y, width: a.width, height: a.height},
            });
        }
        return {
            activeWorkspace: active.index(),
            workspaces: manager.get_n_workspaces(),
            workspacesOnlyOnPrimary: Meta.prefs_get_workspaces_only_on_primary(),
            config: this.config,
            monitors,
            windows,
            strips,
        };
    }
}
