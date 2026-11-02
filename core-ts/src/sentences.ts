// Plain sentences into commands ("slack and mail side by side on 3"). A port of MonorailCore's
// CommandParser, checked against tests/golden/sentences.json. Actions come from src/generated,
// made from spec/actions.json, which is generated from the Swift sources (same order, so the same one wins).

import type { Arrangement } from './arrangement.ts';
import { ACTIONS } from './generated/actions.ts';

export type NaturalCommand =
  | { pair: { apps: string[]; arrangement: Arrangement; workspace: number | null } }
  | { width: { app: string | null; share: number } }
  | { moveTo: { app: string | null; workspace: number } }
  | { switchTo: { workspace: number } }
  | { open: { app: string } }
  | { focusMode: boolean }
  | { action: string };

/** Every action, in the Swift core's order (generated from spec/actions.json). */
export const actions: readonly { name: string; title: string }[] = ACTIONS;

const numberWords: Record<string, number> = {
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9,
  first: 1, second: 2, third: 3, fourth: 4, fifth: 5,
};

const shares: [string, number][] = [
  ['full width', 1], ['full screen', 1], ['full', 1], ['whole screen', 1],
  ['three quarters', 0.75], ['3/4', 0.75], ['75%', 0.75],
  ['two thirds', 2 / 3], ['2/3', 2 / 3],
  ['half', 0.5], ['1/2', 0.5], ['50%', 0.5],
  ['one third', 1 / 3], ['a third', 1 / 3], ['third', 1 / 3], ['1/3', 1 / 3],
  ['quarter', 0.25], ['1/4', 0.25], ['25%', 0.25],
];

const arrangements: [string, Arrangement][] = [
  ['side by side', 'columns'], ['next to each other', 'columns'], ['beside', 'columns'], ['columns', 'columns'],
  ['stacked', 'stack'], ['on top of each other', 'stack'], ['above', 'stack'], ['up and down', 'stack'],
  ['grid', 'grid'], ['main left', 'mainLeft'], ['main on the left', 'mainLeft'], ['main top', 'mainTop'],
  ['spiral', 'spiral'], ['accordion', 'accordion'],
];

const isWordChar = (c: string | undefined) => c !== undefined && /[\p{L}\p{N}]/u.test(c);
const characters = (s: string) => [...s].length;

function isWordBoundary(text: string, start: number, end: number): boolean {
  return !isWordChar(text[start - 1]) && !isWordChar(text[end]);
}

/** Running apps named in the text, in the order they appear. */
export function mentionedApps(lower: string, apps: string[]): string[] {
  const found: [string, number][] = [];
  for (const app of apps) {
    const name = app.toLowerCase();
    const short = name.split(' ').filter(Boolean)[0] ?? name;
    for (const candidate of [name, short]) {
      if (characters(candidate) < 3) continue;
      const at = lower.indexOf(candidate);
      if (at >= 0 && isWordBoundary(lower, at, at + candidate.length)) {
        if (!found.some(([a]) => a === app)) found.push([app, at]);
        break;
      }
    }
  }
  return found.sort((a, b) => a[1] - b[1]).map(([app]) => app);
}

/** "on 3", "to workspace two", "workspace 4", "desktop 2" (1-based). */
export function workspaceNumber(lower: string): number | undefined {
  const tokens = lower.split(' ').filter(Boolean);
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const value = /^[+-]?\d+$/.test(token) ? Number(token) : numberWords[token];
    if (value === undefined || value < 1 || value > 9) continue;
    const previous = i > 0 ? tokens[i - 1] : '';
    if (['on', 'to', 'workspace', 'desktop', 'space', 'into', 'onto'].includes(previous)) return value;
  }
  return undefined;
}

/** Parses `text`; `apps` are the names of running apps. Workspaces are 1-based here. */
export function parse(text: string, apps: string[]): NaturalCommand | null {
  const lower = ' ' + text.toLowerCase().replaceAll(',', ' ').replaceAll('  ', ' ').trim() + ' ';
  const mentioned = mentionedApps(lower, apps);
  const workspace = workspaceNumber(lower);

  if (lower.includes(' focus mode') || lower.includes(' focus on ') || lower.endsWith(' focus ')) {
    if (lower.includes(' off') || lower.includes(' stop') || lower.includes(' end')) return { focusMode: false };
    if (lower.includes(' on') || lower.includes(' start') || lower.includes(' focus mode ')) return { focusMode: true };
  }
  if (mentioned.length >= 2) {
    const arrangement = arrangements.find(([phrase]) => lower.includes(' ' + phrase))?.[1] ?? 'columns';
    return { pair: { apps: mentioned, arrangement, workspace: workspace ?? null } };
  }
  const share = shares.find(([phrase]) => lower.includes(phrase))?.[1];
  if (share !== undefined) return { width: { app: mentioned[0] ?? null, share } };
  if (workspace !== undefined) {
    const moving = [' move ', ' send ', ' put ', ' throw '].some((w) => lower.includes(w));
    if (moving || mentioned[0] !== undefined) return { moveTo: { app: mentioned[0] ?? null, workspace } };
    return { switchTo: { workspace } };
  }
  if (mentioned[0] !== undefined && [' open ', ' launch ', ' start ', ' go to ', ' show ', ' focus '].some((w) => lower.includes(w))) {
    return { open: { app: mentioned[0] } };
  }
  // An action by its title or name ("show the overview", "undo").
  const words = lower.trim();
  const exact = actions.find((a) => words === a.name || words === a.title.toLowerCase() || words.replaceAll(' ', '-') === a.name);
  if (exact) return { action: exact.name };
  const within = actions.find((a) => words.includes(a.title.toLowerCase()) && characters(a.title) > 5);
  if (within) return { action: within.name };
  if (mentioned[0] !== undefined) return { open: { app: mentioned[0] } };
  return null;
}
