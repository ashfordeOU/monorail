// A small D-Bus interface for the automated UI tests (linux/gnome/test). Only exported when
// GNOME Shell was started with MONORAIL_TEST=1; a normal session never has it.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Config from 'resource:///org/gnome/shell/misc/config.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const BUS_NAME = 'org.ashforde.Monorail.Test';
const OBJECT_PATH = '/org/ashforde/Monorail/Test';
const INTERFACE = `
<node>
  <interface name="org.ashforde.Monorail.Test">
    <method name="GetState">
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="Action">
      <arg type="s" direction="in" name="name"/>
      <arg type="b" direction="out" name="changed"/>
    </method>
    <method name="PressKeys">
      <arg type="s" direction="in" name="keys"/>
      <arg type="b" direction="out" name="sent"/>
    </method>
    <method name="CloseWindow">
      <arg type="s" direction="in" name="title"/>
      <arg type="b" direction="out" name="found"/>
    </method>
    <method name="HideOverview">
      <arg type="b" direction="out" name="wasVisible"/>
    </method>
    <method name="ActivateWorkspace">
      <arg type="i" direction="in" name="index"/>
      <arg type="b" direction="out" name="done"/>
    </method>
  </interface>
</node>`;

export class TestInterface {
    constructor(tiler, metadata) {
        this._tiler = tiler;
        this._metadata = metadata;
        this._keyboard = Clutter.get_default_backend().get_default_seat()
            .create_virtual_device(Clutter.InputDeviceType.KEYBOARD_DEVICE);
        // Frames the stage has drawn: a stuck compositor shows up in the report.
        this._frames = 0;
        this._paintSignal = global.stage.connect('after-paint', () => this._frames++);
        this._object = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._object.export(Gio.DBus.session, OBJECT_PATH);
        this._owner = Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, null, null, null);
    }

    destroy() {
        Gio.bus_unown_name(this._owner);
        this._object.unexport();
        global.stage.disconnect(this._paintSignal);
        this._keyboard = null;
    }

    GetState() {
        return JSON.stringify({
            extension: {uuid: this._metadata.uuid, version: this._metadata['version-name'] ?? null},
            shell: Config.PACKAGE_VERSION,
            startingUp: Main.layoutManager._startingUp,
            overview: Main.overview.visible,
            framesDrawn: this._frames,
            ...this._tiler.state(),
        });
    }

    Action(name) {
        return this._tiler.perform(name);
    }

    /** Presses keys through a virtual keyboard, as a person would: "Super_L+Alt_L+Right". */
    PressKeys(keys) {
        const keyvals = keys.split('+').map(name => {
            const keyval = Clutter[`KEY_${name}`];
            if (keyval === undefined) throw new Error(`unknown key ${name}`);
            return keyval;
        });
        let time = GLib.get_monotonic_time();
        for (const keyval of keyvals) this._keyboard.notify_keyval(time++, keyval, Clutter.KeyState.PRESSED);
        for (const keyval of [...keyvals].reverse()) this._keyboard.notify_keyval(time++, keyval, Clutter.KeyState.RELEASED);
        return true;
    }

    CloseWindow(title) {
        const window = global.get_window_actors().map(actor => actor.get_meta_window())
            .find(w => w && w.get_title() === title);
        if (!window) return false;
        window.delete(global.get_current_time());
        return true;
    }

    /** GNOME Shell starts in the Activities overview; the tests work on the desktop. */
    HideOverview() {
        const visible = Main.overview.visible;
        Main.overview.hide();
        return visible;
    }

    ActivateWorkspace(index) {
        const workspace = global.workspace_manager.get_workspace_by_index(index);
        if (!workspace) return false;
        workspace.activate(global.get_current_time());
        return true;
    }
}
