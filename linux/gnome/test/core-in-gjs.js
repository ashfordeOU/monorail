// The shared core, as built into the extension, loads and runs in GJS (the engine GNOME Shell
// uses) and gives the same frames as in Node: `gjs -m core-in-gjs.js <built extension dir>`.

import System from 'system';

const dir = ARGV[0];
if (!dir) {
    printerr('usage: gjs -m core-in-gjs.js <built extension directory>');
    System.exit(2);
}
const {Strip} = await import(`file://${dir}/core/strip.js`);
const {defaultLayoutConfig, layout, revealFocused} = await import(`file://${dir}/core/layout.js`);
const {ACTIONS} = await import(`file://${dir}/core/generated/actions.js`);

let failures = 0;
const expect = (name, got, want) => {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) failures++;
    print(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `: got ${JSON.stringify(got)}, expected ${JSON.stringify(want)}`}`);
};

const config = defaultLayoutConfig();
const strip = new Strip();
for (const w of [1, 2, 3]) strip.insert(w, config.defaultWidth);
revealFocused(strip, config, 1280);
const frames = layout(strip, config, {x: 0, y: 32, width: 1280, height: 768}).map(p => [p.window, p.frame.x, p.frame.width, p.isParked]);
expect('three half-width windows on a 1280-wide screen', frames, [[1, -624, 628, true], [2, 8, 628, false], [3, 644, 628, false]]);
strip.moveFocus('left');
strip.moveFocus('left');
revealFocused(strip, config, 1280);
expect('focusing the first scrolls back', strip.scroll, 0);
strip.cycleWidth(config.widthPresets);
expect('cycle width', strip.columns[0].width, 2 / 3);
for (const name of ['focus-left', 'focus-right', 'focus-first', 'focus-last', 'move-left', 'move-right', 'cycle-width', 'cycle-width-backward', 'full-width'])
    expect(`shared action ${name} exists`, ACTIONS.some(a => a.name === name), true);

System.exit(failures ? 1 : 0);
