// A second, test-only extension for Monorail's UI tests (run-ci.sh installs it next to Monorail;
// it never ships). It reads windows straight from Mutter, so the tests can see where windows are
// while Monorail is turned off, and it moves windows and the pointer as a person would. Nothing
// here uses Monorail's code. Only exported when GNOME Shell was started with MONORAIL_TEST=1.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const BUS_NAME = 'org.ashforde.Monorail.Probe';
const OBJECT_PATH = '/org/ashforde/Monorail/Probe';
const INTERFACE = `
<node>
  <interface name="org.ashforde.Monorail.Probe">
    <method name="GetWindows">
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="MoveToMonitor">
      <arg type="s" direction="in" name="title"/>
      <arg type="i" direction="in" name="monitor"/>
      <arg type="b" direction="out" name="found"/>
    </method>
    <method name="Activate">
      <arg type="s" direction="in" name="title"/>
      <arg type="b" direction="out" name="found"/>
    </method>
    <method name="MovePointer">
      <arg type="d" direction="in" name="x"/>
      <arg type="d" direction="in" name="y"/>
      <arg type="b" direction="out" name="done"/>
    </method>
  </interface>
</node>`;

const windows = () => global.get_window_actors().map(actor => actor.get_meta_window()).filter(w => w);
const named = title => windows().find(w => w.get_title() === title);

class Probe {
    constructor() {
        this._pointer = null; // made when first needed: only the several-monitor checks move it
        this._object = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._object.export(Gio.DBus.session, OBJECT_PATH);
        this._owner = Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, null, null, null);
    }

    destroy() {
        Gio.bus_unown_name(this._owner);
        this._object.unexport();
        this._pointer = null;
    }

    GetWindows() {
        const display = global.display;
        const monitors = [];
        for (let i = 0; i < display.get_n_monitors(); i++) {
            const g = display.get_monitor_geometry(i);
            monitors.push({index: i, geometry: {x: g.x, y: g.y, width: g.width, height: g.height}});
        }
        return JSON.stringify({
            activeWorkspace: global.workspace_manager.get_active_workspace().index(),
            monitors,
            windows: windows().map(window => {
                const f = window.get_frame_rect();
                return {
                    id: window.get_id(),
                    title: window.get_title(),
                    workspace: window.get_workspace()?.index() ?? -1,
                    monitor: window.get_monitor(),
                    visible: Boolean(window.get_compositor_private()?.visible),
                    minimized: window.minimized,
                    frame: {x: f.x, y: f.y, width: f.width, height: f.height},
                };
            }),
        });
    }

    /** As Super+Shift+Left/Right or the window menu's "Move to Monitor" would. */
    MoveToMonitor(title, monitor) {
        const window = named(title);
        if (!window) return false;
        window.move_to_monitor(monitor);
        return true;
    }

    Activate(title) {
        const window = named(title);
        if (!window) return false;
        window.activate(global.get_current_time());
        return true;
    }

    /** New windows open on the monitor with the pointer. */
    MovePointer(x, y) {
        this._pointer ??= Clutter.get_default_backend().get_default_seat()
            .create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
        this._pointer.notify_absolute_motion(GLib.get_monotonic_time(), x, y);
        return true;
    }
}

export default class MonorailTestProbe extends Extension {
    enable() {
        if (GLib.getenv('MONORAIL_TEST') === '1') this._probe = new Probe();
    }

    disable() {
        this._probe?.destroy();
        this._probe = null;
    }
}
