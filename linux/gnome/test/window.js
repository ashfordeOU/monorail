// A plain GTK 4 window for the UI tests: `gjs -m window.js --title "Monorail A"`.
//   --dialog    also opens a modal dialog for it (transient for the window)
//   --fixed     a window that can't be resized (it should be left floating)
//   --skip-taskbar  an X11 window kept out of the taskbar and switcher (left floating too)
// Run with GDK_BACKEND=x11 to open it through Xwayland instead of as a Wayland window.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';
import 'gi://GdkX11?version=4.0';

const args = ARGV;
const option = name => args.includes(name);
const value = (name, fallback) => {
    const i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
};
const title = value('--title', 'Monorail test window');

const app = new Gtk.Application({flags: Gio.ApplicationFlags.NON_UNIQUE});
app.connect('activate', () => {
    const window = new Gtk.ApplicationWindow({
        application: app,
        title,
        default_width: 420,
        default_height: 300,
        resizable: !option('--fixed'),
        child: new Gtk.Label({label: title}),
    });
    if (option('--skip-taskbar')) {
        // Only X11 has this hint (GDK_BACKEND=x11); it's set before the window is shown.
        window.connect_after('realize', () => window.get_surface().set_skip_taskbar_hint(true));
    }
    window.present();
    if (option('--dialog')) {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            const dialog = new Gtk.Window({
                title: `${title} dialog`,
                transient_for: window,
                modal: true,
                default_width: 320,
                default_height: 180,
                child: new Gtk.Label({label: 'A dialog: Monorail leaves it floating.'}),
            });
            dialog.present();
            return GLib.SOURCE_REMOVE;
        });
    }
});
app.run([]);
