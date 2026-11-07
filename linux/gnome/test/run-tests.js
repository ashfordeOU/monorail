// UI tests for Monorail for GNOME (beta), run inside a real GNOME Shell (see run-ci.sh). Opens
// real GTK windows, presses the real shortcuts through a virtual keyboard, and reads every
// window's frame from inside the shell through the extension's test interface (MONORAIL_TEST=1).
// Expected positions are worked out here from the work area and spec/strip.md's defaults, not
// from the core, so a wrong core would fail too.
//
//   gjs -m run-tests.js [--report report.json]
// Exits 1 when any check fails.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import System from 'system';

const BUS_NAME = 'org.ashforde.Monorail.Test';
const OBJECT_PATH = '/org/ashforde/Monorail/Test';
const UUID = 'monorail@ashforde.org';
const here = GLib.path_get_dirname(GLib.filename_from_uri(import.meta.url)[0]);
const reportPath = ARGV.includes('--report') ? ARGV[ARGV.indexOf('--report') + 1] : null;

// spec/strip.md: 8-point gaps between slides and at the screen edges, new slides half the usable
// width, presets ¼ ⅓ ½ ⅔ ¾, a 4-point sliver for parked slides.
const GAP = 8;
const EDGE = 8;
// Mutter keeps at least 75 pixels of a window on screen, so a parked window is as far off screen
// as Mutter allows and hidden.
const MUTTER_MINIMUM_ON_SCREEN = 75;

// MONORAIL_CHECK_TIMEOUT (ms) and MONORAIL_FAIL_FAST=1 are for trying things out locally.
const TIMEOUT = Number(GLib.getenv('MONORAIL_CHECK_TIMEOUT') ?? 15000);
const FAIL_FAST = GLib.getenv('MONORAIL_FAIL_FAST') === '1';

const results = [];
const processes = [];
const loop = new GLib.MainLoop(null, false);

function log(line) {
    print(line);
}

const sleep = ms => new Promise(resolve => GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
    resolve();
    return GLib.SOURCE_REMOVE;
}));

function call(method, args = null, signature = null) {
    const reply = Gio.DBus.session.call_sync(BUS_NAME, OBJECT_PATH, BUS_NAME, method,
        args ? new GLib.Variant(signature, args) : null, null, Gio.DBusCallFlags.NONE, 5000, null);
    return reply.deepUnpack()[0];
}

const getState = () => JSON.parse(call('GetState'));
const pressKeys = keys => call('PressKeys', [keys], '(s)');
const closeWindow = title => call('CloseWindow', [title], '(s)');
const activateWorkspace = index => call('ActivateWorkspace', [index], '(i)');

function nameHasOwner() {
    const reply = Gio.DBus.session.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
        'org.freedesktop.DBus', 'NameHasOwner', new GLib.Variant('(s)', [BUS_NAME]),
        null, Gio.DBusCallFlags.NONE, 2000, null);
    return reply.deepUnpack()[0];
}

function open(title, extra = [], env = {}) {
    const launcher = new Gio.SubprocessLauncher({flags: Gio.SubprocessFlags.NONE});
    for (const [k, v] of Object.entries(env)) launcher.setenv(k, v, true);
    const proc = launcher.spawnv(['gjs', '-m', `${here}/window.js`, '--title', title, ...extra]);
    processes.push(proc);
    return proc;
}

function run(argv) {
    const proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE);
    const [, out] = proc.communicate_utf8(null, null);
    return {ok: proc.get_successful(), out: out ?? ''};
}

// MARK: Geometry

const fmt = f => (f ? `${f.x},${f.y} ${f.width}x${f.height}` : 'none');
const near = (a, b, tolerance = 1) => Math.abs(a - b) <= tolerance;
const frameIs = (f, e) => near(f.x, e.x) && near(f.y, e.y) && near(f.width, e.width) && near(f.height, e.height);
const right = f => f.x + f.width;

class Geometry {
    constructor(workArea) {
        this.area = workArea;
        this.usable = workArea.width - 2 * EDGE;
        this.x0 = workArea.x + EDGE;
        this.y0 = workArea.y + EDGE;
        this.height = workArea.height - 2 * EDGE;
    }

    width(share) {
        return Math.round(share * (this.usable + GAP) - GAP);
    }

    frame(x, share) {
        return {x, y: this.y0, width: this.width(share), height: this.height};
    }

    onScreen(f) {
        return f.x >= this.area.x - 1 && right(f) <= this.area.x + this.area.width + 1;
    }

    /** Off screen (as far as Mutter allows) and hidden. */
    parked(w) {
        const f = w.frame;
        const edge = MUTTER_MINIMUM_ON_SCREEN + 1;
        return w.parked && !w.visible &&
            (right(f) <= this.area.x + edge || f.x >= this.area.x + this.area.width - edge);
    }
}

const windowNamed = (state, title) => state.windows.find(w => w.title === title);
const stripOf = (state, workspace, monitor = 0) => state.strips.find(s => s.workspace === workspace && s.monitor === monitor);

/** The visible parts of two tiled windows overlap. */
function overlapping(state, geometry) {
    const tiled = state.windows.filter(w => w.tiled && w.visible && w.workspace === state.activeWorkspace);
    const clip = f => {
        const x1 = Math.max(f.x, geometry.area.x);
        const x2 = Math.min(right(f), geometry.area.x + geometry.area.width);
        return {x1, x2, y1: f.y, y2: f.y + f.height};
    };
    for (let i = 0; i < tiled.length; i++) {
        for (let j = i + 1; j < tiled.length; j++) {
            const a = clip(tiled[i].frame);
            const b = clip(tiled[j].frame);
            if (a.x2 <= a.x1 || b.x2 <= b.x1) continue;
            if (Math.min(a.x2, b.x2) > Math.max(a.x1, b.x1) && Math.min(a.y2, b.y2) > Math.max(a.y1, b.y1))
                return `${tiled[i].title} (${fmt(tiled[i].frame)}) overlaps ${tiled[j].title} (${fmt(tiled[j].frame)})`;
        }
    }
    return null;
}

// MARK: Checks

/** Waits until `problem(state)` returns nothing (passed) or the time runs out (failed). */
async function check(name, problem, timeoutMs = TIMEOUT, {offline = false} = {}) {
    const start = GLib.get_monotonic_time();
    let last = 'never checked';
    let state = null;
    while (true) {
        try {
            state = offline ? null : getState();
            last = problem(state);
        } catch (e) {
            last = `error: ${e.message}`;
        }
        if (!last) break;
        if ((GLib.get_monotonic_time() - start) / 1000 > timeoutMs) break;
        await sleep(150);
    }
    const passed = !last;
    const ms = Math.round((GLib.get_monotonic_time() - start) / 1000);
    results.push({name, passed, detail: passed ? null : last, ms});
    log(`${passed ? 'PASS' : 'FAIL'}  ${name}${passed ? '' : `\n      ${last}`}`);
    if (!passed && state) {
        for (const w of state.windows)
            log(`      - ${w.title} [${w.clientType}${w.tiled ? ', tiled' : ''}${w.parked ? ', parked' : ''}${w.visible ? '' : ', hidden'}${w.focused ? ', focused' : ''}] ws ${w.workspace} ${fmt(w.frame)}`);
        for (const s of state.strips)
            log(`      - strip ws ${s.workspace} monitor ${s.monitor}: ${JSON.stringify(s.columns.map(c => c.windows))} focused ${s.focusedColumn} scroll ${s.scroll}`);
    }
    if (!passed && FAIL_FAST) throw new Error('stopping at the first failure (MONORAIL_FAIL_FAST=1)');
    return passed;
}

/** A list of problems → the first one, or null. */
const first = (...problems) => problems.find(p => p) ?? null;

function expectFrame(state, title, expected) {
    const w = windowNamed(state, title);
    if (!w) return `${title} isn't open`;
    if (!w.tiled) return `${title} isn't tiled`;
    if (!frameIs(w.frame, expected)) return `${title} is at ${fmt(w.frame)}, expected ${fmt(expected)}`;
    return null;
}

function expectFocused(state, title) {
    const w = windowNamed(state, title);
    if (!w) return `${title} isn't open`;
    if (!w.focused) return `${title} doesn't have focus (${state.windows.find(x => x.focused)?.title ?? 'nothing'} has)`;
    return null;
}

function expectOrder(state, titles) {
    const strip = stripOf(state, state.activeWorkspace);
    const ids = titles.map(t => windowNamed(state, t)?.id);
    const got = strip ? strip.columns.map(c => c.windows[0]) : [];
    const names = got.map(id => state.windows.find(w => w.id === id)?.title ?? id);
    return JSON.stringify(got) === JSON.stringify(ids) ? null : `strip order is ${names.join(', ')}, expected ${titles.join(', ')}`;
}

/** GNOME 46 switches workspace with Super+Alt+Left/Right and moves windows with Super+Shift+Alt. */
function gnomeShortcutProblem(monorailOn) {
    const wm = new Gio.Settings({schema_id: 'org.gnome.desktop.wm.keybindings'});
    for (const key of ['switch-to-workspace-left', 'switch-to-workspace-right', 'move-to-workspace-left', 'move-to-workspace-right']) {
        const now = wm.get_strv(key);
        const original = wm.get_default_value(key).deepUnpack();
        const clashing = original.filter(a => /<Super>/i.test(a) && /<Alt>/i.test(a) && /(Left|Right)$/.test(a));
        if (monorailOn) {
            if (now.some(a => clashing.includes(a))) return `${key} still has ${JSON.stringify(now)}`;
            if (now.length !== original.length - clashing.length) return `${key} lost more than the clashing keys: ${JSON.stringify(now)}`;
        } else if (JSON.stringify(now) !== JSON.stringify(original)) {
            return `${key} is ${JSON.stringify(now)}, expected ${JSON.stringify(original)}`;
        }
    }
    return null;
}

// MARK: The tests

async function main() {
    let state = null;
    await check('the extension is running inside GNOME Shell and answers', s => {
        state = s;
        return s.extension.uuid === UUID ? null : `unexpected extension ${s.extension.uuid}`;
    });
    if (!state) return;
    await check('GNOME\'s clashing shortcuts are taken over while Monorail is on', () => gnomeShortcutProblem(true));
    await check('GNOME Shell has finished starting and shows the desktop (it starts in the overview)', s => {
        if (s.startingUp) return `GNOME Shell is still starting (${s.framesDrawn} frames drawn)`;
        if (s.overview) {
            call('HideOverview');
            return 'the overview is showing';
        }
        return null;
    }, Math.max(TIMEOUT, 60000));
    log(`      GNOME Shell ${state.shell}, Monorail ${state.extension.version}, work area ${fmt(state.monitors[0].workArea)}`);
    const g = new Geometry(state.monitors[0].workArea);
    const half = g.width(0.5);
    const second = g.x0 + half + GAP;

    await check('the defaults are the shared ones (8-point gaps, half-width slides)', s =>
        s.config.gap === GAP && s.config.edgeGap === EDGE && s.config.defaultWidth === 0.5 ? null
            : `gap ${s.config.gap}, edge gap ${s.config.edgeGap}, default width ${s.config.defaultWidth}`);

    open('Monorail A');
    await check('a new window is tiled: half width, full work-area height, at the left edge', s =>
        expectFrame(s, 'Monorail A', g.frame(g.x0, 0.5)));

    open('Monorail B');
    await check('a second window opens beside it, side by side, same width and height', s => first(
        expectFrame(s, 'Monorail A', g.frame(g.x0, 0.5)),
        expectFrame(s, 'Monorail B', g.frame(second, 0.5)),
        overlapping(s, g)));

    open('Monorail C');
    await check('a third window scrolls the strip: it shows whole and the first is parked off screen', s => {
        const a = windowNamed(s, 'Monorail A');
        return first(
            expectFrame(s, 'Monorail B', g.frame(g.x0, 0.5)),
            expectFrame(s, 'Monorail C', g.frame(second, 0.5)),
            expectOrder(s, ['Monorail A', 'Monorail B', 'Monorail C']),
            a && !g.parked(a) ? `Monorail A isn't parked: ${fmt(a.frame)}` : null,
            overlapping(s, g));
    });
    // New windows don't always get focus (focus stealing prevention); the shortcuts need one.
    await check('the newest window has focus', s => expectFocused(s, 'Monorail C'));

    pressKeys('Super_L+Alt_L+Left');
    await check('Super+Alt+Left moves focus to the window on the left (already whole: no scroll)', s => first(
        expectFocused(s, 'Monorail B'),
        expectFrame(s, 'Monorail B', g.frame(g.x0, 0.5)),
        expectFrame(s, 'Monorail C', g.frame(second, 0.5))));

    pressKeys('Super_L+Alt_L+Left');
    await check('Super+Alt+Left again scrolls the strip back to show the first window', s => {
        const c = windowNamed(s, 'Monorail C');
        return first(
            expectFocused(s, 'Monorail A'),
            expectFrame(s, 'Monorail A', g.frame(g.x0, 0.5)),
            expectFrame(s, 'Monorail B', g.frame(second, 0.5)),
            c && !g.parked(c) ? `Monorail C isn't parked: ${fmt(c.frame)}` : null,
            overlapping(s, g));
    });

    pressKeys('Super_L+Alt_L+Right');
    pressKeys('Super_L+Alt_L+Right');
    await check('Super+Alt+Right twice scrolls forward to the last window', s => first(
        expectFocused(s, 'Monorail C'),
        expectFrame(s, 'Monorail C', g.frame(second, 0.5)),
        expectFrame(s, 'Monorail B', g.frame(g.x0, 0.5))));

    pressKeys('Super_L+Alt_L+Shift_L+Left');
    await check('Super+Alt+Shift+Left moves the focused column left, keeping focus', s => first(
        expectOrder(s, ['Monorail A', 'Monorail C', 'Monorail B']),
        expectFocused(s, 'Monorail C'),
        expectFrame(s, 'Monorail C', g.frame(g.x0, 0.5)),
        expectFrame(s, 'Monorail B', g.frame(second, 0.5))));

    pressKeys('Super_L+Alt_L+Shift_L+Right');
    await check('Super+Alt+Shift+Right moves it back', s => first(
        expectOrder(s, ['Monorail A', 'Monorail B', 'Monorail C']),
        expectFocused(s, 'Monorail C'),
        expectFrame(s, 'Monorail C', g.frame(second, 0.5))));

    closeWindow('Monorail B');
    await check('closing a window closes the gap: the others sit side by side again', s => first(
        windowNamed(s, 'Monorail B') ? 'Monorail B is still open' : null,
        expectOrder(s, ['Monorail A', 'Monorail C']),
        expectFrame(s, 'Monorail A', g.frame(g.x0, 0.5)),
        expectFrame(s, 'Monorail C', g.frame(second, 0.5)),
        overlapping(s, g)));

    // Focus C for the width shortcuts (closing B may have moved focus).
    call('Action', ['focus-last'], '(s)');
    await check('focus is on the last window again', s => expectFocused(s, 'Monorail C'));

    pressKeys('Super_L+Alt_L+w');
    await check('Super+Alt+W cycles the width to the next preset (two thirds), still whole on screen', s => {
        const c = windowNamed(s, 'Monorail C');
        return first(
            c && !near(c.frame.width, g.width(2 / 3)) ? `Monorail C is ${c.frame.width} wide, expected ${g.width(2 / 3)}` : null,
            c && !g.onScreen(c.frame) ? `Monorail C isn't whole on screen: ${fmt(c.frame)}` : null,
            c && !near(right(c.frame), g.x0 + g.usable) ? `Monorail C should end at the right edge: ${fmt(c.frame)}` : null,
            overlapping(s, g));
    });

    pressKeys('Super_L+Alt_L+f');
    await check('Super+Alt+F makes it full width', s => expectFrame(s, 'Monorail C', g.frame(g.x0, 1)));

    pressKeys('Super_L+Alt_L+f');
    await check('Super+Alt+F again gives it back its width', s => {
        const c = windowNamed(s, 'Monorail C');
        return c && near(c.frame.width, g.width(2 / 3)) && g.onScreen(c.frame) ? null : `Monorail C is at ${fmt(c?.frame)}`;
    });

    pressKeys('Super_L+Alt_L+Shift_L+w');
    await check('Super+Alt+Shift+W cycles the width back (to half)', s => first(
        expectFrame(s, 'Monorail A', g.frame(g.x0, 0.5)),
        expectFrame(s, 'Monorail C', g.frame(second, 0.5))));

    open('Monorail D', ['--dialog']);
    await check('a dialog is left floating; its window is tiled', s => {
        const d = windowNamed(s, 'Monorail D');
        const dialog = windowNamed(s, 'Monorail D dialog');
        if (!d || !dialog) return 'the window or its dialog isn\'t open yet';
        return first(
            d.tiled ? null : 'Monorail D isn\'t tiled',
            dialog.tiled ? 'the dialog was tiled' : null,
            dialog.transientFor === d.id ? null : 'the dialog isn\'t transient for its window',
            near(dialog.frame.height, g.height, 4) ? `the dialog was stretched to full height: ${fmt(dialog.frame)}` : null,
            stripOf(s, s.activeWorkspace).columns.length === 3 ? null : 'the strip should have three columns (A, C, D)',
            overlapping(s, g));
    });

    open('Monorail E', ['--fixed']);
    await check('a window that can\'t be resized is left floating', s => {
        const e = windowNamed(s, 'Monorail E');
        if (!e) return 'Monorail E isn\'t open yet';
        return first(
            e.resizable ? 'Monorail E is resizable' : null,
            e.tiled ? 'Monorail E was tiled' : null,
            stripOf(s, s.activeWorkspace).columns.length === 3 ? null : 'the strip changed');
    });
    closeWindow('Monorail E');

    // Each workspace has its own strip.
    let before = getState();
    activateWorkspace(1);
    await check('switching to the second workspace', s => (s.activeWorkspace === 1 ? null : `on workspace ${s.activeWorkspace}`));
    open('Monorail F');
    await check('a window on the second workspace starts its own strip, at the left edge', s => {
        const f = windowNamed(s, 'Monorail F');
        const strip = stripOf(s, 1);
        return first(
            f && f.workspace !== 1 ? `Monorail F opened on workspace ${f.workspace}` : null,
            expectFrame(s, 'Monorail F', g.frame(g.x0, 0.5)),
            strip && strip.columns.length === 1 ? null : 'workspace 2 should have a strip of one',
            stripOf(s, 0)?.columns.length === 3 ? null : 'the first workspace\'s strip changed');
    });
    await check('the first workspace\'s windows didn\'t move', s => {
        for (const w of before.windows.filter(x => x.tiled && x.workspace === 0)) {
            const now = s.windows.find(x => x.id === w.id);
            if (!now || !frameIs(now.frame, w.frame)) return `${w.title} moved from ${fmt(w.frame)} to ${fmt(now?.frame)}`;
        }
        return null;
    });
    activateWorkspace(0);
    await check('back on the first workspace', s => (s.activeWorkspace === 0 ? null : `on workspace ${s.activeWorkspace}`));

    // An X11 app through Xwayland.
    open('Monorail X11', [], {GDK_BACKEND: 'x11'});
    await check('an X11 window (through Xwayland) is tiled like the others', s => {
        const x = windowNamed(s, 'Monorail X11');
        if (!x) return 'Monorail X11 isn\'t open yet';
        return first(
            x.clientType === 'x11' ? null : `it opened as a ${x.clientType} window`,
            x.tiled ? null : 'it isn\'t tiled',
            x.tiled && !near(x.frame.width, half) ? `it is ${x.frame.width} wide, expected ${half}` : null,
            x.tiled && !near(x.frame.height, g.height) ? `it is ${x.frame.height} high, expected ${g.height}` : null,
            x.tiled && !g.onScreen(x.frame) ? `it isn't whole on screen: ${fmt(x.frame)}` : null,
            overlapping(s, g));
    }, 25000);

    open('Monorail skip taskbar', ['--skip-taskbar'], {GDK_BACKEND: 'x11'});
    await check('a window kept out of the taskbar is left floating', s => {
        const w = windowNamed(s, 'Monorail skip taskbar');
        if (!w) return 'it isn\'t open yet';
        return first(
            w.skipTaskbar ? null : 'it isn\'t marked skip-taskbar',
            w.tiled ? 'it was tiled' : null,
            near(w.frame.height, g.height, 4) ? `it was stretched to full height: ${fmt(w.frame)}` : null);
    }, 25000);
    closeWindow('Monorail skip taskbar');

    // Turned off and on (as on locking the screen), the strip comes back the same.
    before = getState();
    const order = stripOf(before, 0)?.columns.map(c => c.windows[0]);
    const off = run(['gnome-extensions', 'disable', UUID]);
    let gone = false;
    for (let i = 0; i < 50 && !gone; i++) {
        gone = !nameHasOwner();
        if (!gone) await sleep(100);
    }
    results.push({name: 'turning the extension off removes its shortcuts and test interface', passed: off.ok && gone,
        detail: off.ok && gone ? null : `disable: ${off.out.trim()} interface gone: ${gone}`});
    log(`${off.ok && gone ? 'PASS' : 'FAIL'}  turning the extension off removes its shortcuts and test interface`);
    await check('turned off, GNOME has its own shortcuts back, in their old places', () => gnomeShortcutProblem(false),
        TIMEOUT, {offline: true});
    run(['gnome-extensions', 'enable', UUID]);
    await check('turned back on, every window is back on the strip in the same order', s => {
        const now = stripOf(s, 0)?.columns.map(c => c.windows[0]);
        return JSON.stringify(now) === JSON.stringify(order) ? null : `order ${JSON.stringify(now)}, expected ${JSON.stringify(order)}`;
    });
    await check('and laid out as before', s => {
        for (const w of before.windows.filter(x => x.tiled && x.workspace === 0)) {
            const now = s.windows.find(x => x.id === w.id);
            if (!now || !frameIs(now.frame, w.frame)) return `${w.title} moved from ${fmt(w.frame)} to ${fmt(now?.frame)}`;
        }
        return null;
    });
}

main().catch(e => {
    results.push({name: 'the test run itself', passed: false, detail: `${e}\n${e.stack}`});
    log(`FAIL  the test run itself: ${e}\n${e.stack}`);
}).finally(() => {
    for (const proc of processes) proc.force_exit();
    const failed = results.filter(r => !r.passed);
    log(`\n${results.length - failed.length} of ${results.length} checks passed`);
    if (reportPath) {
        const report = {passed: failed.length === 0, checks: results};
        GLib.file_set_contents(reportPath, JSON.stringify(report, null, 2));
    }
    loop.quit();
    System.exit(failed.length === 0 && results.length > 0 ? 0 : 1);
});
loop.run();
