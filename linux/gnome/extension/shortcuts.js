// GNOME already uses some of Monorail's shortcuts: Super+Alt+Left/Right switch workspace and
// Super+Shift+Alt+Left/Right move a window to the next workspace (each also has Super+Page Up/Down
// and Ctrl+Alt+arrows). While Monorail is on, it takes over just those keys and gives them back
// exactly when it's turned off. What it took is kept in its own settings (`released-shortcuts`),
// so it's given back even if GNOME Shell stopped before Monorail was turned off.
// Turn off `take-over-gnome-shortcuts` to leave GNOME's shortcuts alone.

import Gio from 'gi://Gio';

/** The places GNOME keeps window and shell shortcuts. */
const GNOME_SCHEMAS = [
    'org.gnome.desktop.wm.keybindings',
    'org.gnome.shell.keybindings',
    'org.gnome.mutter.keybindings',
    'org.gnome.mutter.wayland.keybindings',
];

const MODIFIER_NAMES = {
    super: 'super', alt: 'alt', mod1: 'alt', shift: 'shift', control: 'control', ctrl: 'control',
    primary: 'control', meta: 'meta', hyper: 'hyper', mod4: 'super',
};

/** "<Super><Shift><Alt>Left" and "<Alt><Super><Shift>left" are the same shortcut. */
export function normalise(accelerator) {
    const modifiers = [];
    const key = accelerator.replace(/<([^>]+)>/g, (_m, name) => {
        modifiers.push(MODIFIER_NAMES[name.toLowerCase()] ?? name.toLowerCase());
        return '';
    });
    return `${[...new Set(modifiers)].sort().join('+')}|${key.toLowerCase()}`;
}

function schemaIfInstalled(id) {
    const source = Gio.SettingsSchemaSource.get_default();
    return source?.lookup(id, true) ? new Gio.Settings({schema_id: id}) : null;
}

/** Takes `accelerators` away from GNOME's own shortcuts; returns what it took. */
export function takeOver(settings, accelerators) {
    const wanted = new Set(accelerators.map(normalise));
    const taken = JSON.parse(settings.get_string('released-shortcuts') || '[]');
    for (const id of GNOME_SCHEMAS) {
        const gnome = schemaIfInstalled(id);
        if (!gnome) continue;
        for (const key of gnome.settings_schema.list_keys()) {
            if (gnome.settings_schema.get_key(key).get_value_type().dup_string() !== 'as') continue;
            const current = gnome.get_strv(key);
            const kept = current.filter(accel => !wanted.has(normalise(accel)));
            if (kept.length === current.length) continue;
            current.forEach((accel, index) => {
                if (wanted.has(normalise(accel))) taken.push({schema: id, key, accel, index});
            });
            gnome.set_strv(key, kept);
        }
    }
    settings.set_string('released-shortcuts', JSON.stringify(taken));
    Gio.Settings.sync();
    return taken;
}

/** Gives GNOME back every shortcut Monorail took. */
export function giveBack(settings) {
    const taken = JSON.parse(settings.get_string('released-shortcuts') || '[]');
    // Back in their old places (first taken, first given back, so the indices line up).
    for (const {schema, key, accel, index} of [...taken].sort((a, b) => (a.index ?? 0) - (b.index ?? 0))) {
        const gnome = schemaIfInstalled(schema);
        if (!gnome || !gnome.settings_schema.has_key(key)) continue;
        const current = gnome.get_strv(key);
        if (current.some(a => normalise(a) === normalise(accel))) continue;
        current.splice(Math.min(index ?? current.length, current.length), 0, accel);
        gnome.set_strv(key, current);
    }
    settings.set_string('released-shortcuts', '[]');
    Gio.Settings.sync();
}
