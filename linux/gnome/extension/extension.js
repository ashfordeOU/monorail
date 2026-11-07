// Monorail for GNOME (beta): scrolling tiling for GNOME Shell 45 and later.

import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {ACTIONS} from './core/generated/actions.js';
import {Tiler} from './tiler.js';
import {TestInterface} from './testing.js';
import {giveBack, takeOver} from './shortcuts.js';

/** The shortcuts this beta offers: shared action names (spec/actions.json), each a key in the schema. */
export const SHORTCUT_ACTIONS = [
    'focus-left', 'focus-right', 'focus-first', 'focus-last',
    'move-left', 'move-right', 'cycle-width', 'cycle-width-backward', 'full-width',
];

export default class MonorailExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._tiler = new Tiler(this._settings);
        this._tiler.enable();

        const known = new Set(ACTIONS.map(action => action.name));
        const actions = SHORTCUT_ACTIONS.filter(action => known.has(action)); // only shared actions
        if (this._settings.get_boolean('take-over-gnome-shortcuts'))
            takeOver(this._settings, actions.flatMap(action => this._settings.get_strv(action)));
        this._shortcuts = [];
        for (const action of actions) {
            Main.wm.addKeybinding(action, this._settings, Meta.KeyBindingFlags.NONE,
                Shell.ActionMode.NORMAL, () => this._tiler.perform(action));
            this._shortcuts.push(action);
        }

        // A D-Bus interface for the automated UI tests only, never in a normal session.
        if (GLib.getenv('MONORAIL_TEST') === '1') this._test = new TestInterface(this._tiler, this.metadata);
    }

    disable() {
        this._test?.destroy();
        this._test = null;
        for (const action of this._shortcuts ?? []) Main.wm.removeKeybinding(action);
        this._shortcuts = null;
        if (this._settings) giveBack(this._settings);
        this._tiler?.disable();
        this._tiler = null;
        this._settings = null;
    }
}
