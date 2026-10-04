/**
 * Per-session background colour.
 *
 * Two layers:
 *  1. A per-session theme tint (works everywhere, including inside herdr/tmux).
 *     It recolours pi's background surfaces - message bubbles, tool boxes and
 *     selections - to a dark hue that is unique to the session.
 *  2. A best-effort OSC 11 terminal background. This only shows on terminals
 *     that honour it; pane emulators such as herdr keep their own background,
 *     so this is a bonus rather than the primary mechanism.
 *
 * The swatch is chosen once per session id and persisted both in the session
 * (so resuming restores it) and in a small local state file (so concurrent
 * sessions avoid each other's colours).
 *
 * Commands:
 *   /session-bg            report the session colour and re-apply it
 *   /session-bg next|prev  cycle to the next/previous swatch (persists)
 *   /session-bg random     pick a different swatch (persists)
 *   /session-bg pick       choose a swatch from a list
 *   /session-bg <name>     apply a named swatch (e.g. teal, wine)
 *   /session-bg test       flash a magenta OSC 11 background (diagnostic)
 *   /session-bg reset      reset the OSC 11 terminal background
 */

import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Theme, getAgentDir } from "@earendil-works/pi-coding-agent";

/* ------------------------------------------------------------------ palette */

interface Swatch {
	key: string;
	h: number;
	s: number;
}

/** Hue/saturation pairs; lightness is derived per surface so all stay dark. */
const SWATCHES: Swatch[] = [
	{ key: "ink", h: 232, s: 14 },
	{ key: "indigo", h: 252, s: 34 },
	{ key: "grape", h: 276, s: 30 },
	{ key: "plum", h: 300, s: 28 },
	{ key: "mauve", h: 322, s: 26 },
	{ key: "wine", h: 348, s: 30 },
	{ key: "rust", h: 18, s: 36 },
	{ key: "espresso", h: 28, s: 26 },
	{ key: "amber", h: 40, s: 42 },
	{ key: "olive", h: 60, s: 30 },
	{ key: "moss", h: 82, s: 26 },
	{ key: "forest", h: 140, s: 28 },
	{ key: "teal", h: 178, s: 30 },
	{ key: "steel", h: 200, s: 34 },
	{ key: "navy", h: 218, s: 36 },
	{ key: "charcoal", h: 210, s: 8 },
];

interface Surfaces {
	canvas: string;
	toolPendingBg: string;
	toolSuccessBg: string;
	toolErrorBg: string;
	customMessageBg: string;
	userMessageBg: string;
	selectedBg: string;
}

/** Shortest-arc hue blend, so e.g. 350 -> 10 goes through red. */
function blendHue(a: number, b: number, t: number): number {
	const diff = ((b - a + 540) % 360) - 180;
	return (a + diff * t + 360) % 360;
}

function hsl(h: number, s: number, l: number): string {
	const sat = s / 100;
	const lit = l / 100;
	const a = sat * Math.min(lit, 1 - lit);
	const f = (n: number) => {
		const k = (n + h / 30) % 12;
		return lit - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
	};
	const hex = (x: number) =>
		Math.round(255 * x)
			.toString(16)
			.padStart(2, "0");
	return `#${hex(f(0))}${hex(f(8))}${hex(f(4))}`;
}

function surfacesFor(sw: Swatch): Surfaces {
	return {
		canvas: hsl(sw.h, sw.s, 7),
		toolPendingBg: hsl(sw.h, sw.s, 14),
		// Success/error keep a green/red lean but pick up the session hue, so
		// completed tool boxes still read as success/error while staying tinted.
		toolSuccessBg: hsl(blendHue(140, sw.h, 0.4), sw.s, 15),
		toolErrorBg: hsl(blendHue(0, sw.h, 0.15), Math.min(60, sw.s + 10), 16),
		customMessageBg: hsl(sw.h, Math.round(sw.s * 0.9), 17),
		userMessageBg: hsl(sw.h, sw.s, 21),
		selectedBg: hsl(sw.h, Math.min(100, sw.s + 6), 26),
	};
}

/* -------------------------------------------------------------------- state */

const ENTRY_TYPE = "session-background";
const MAX_REMEMBERED = 64;
const STATE_FILE = path.join(getAgentDir(), "session-background.json");

interface Assignment {
	id: string;
	key: string;
	at: number;
}

function loadAssignments(): Assignment[] {
	try {
		const parsed: unknown = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
		if (!Array.isArray(parsed)) return [];
		return parsed.filter(
			(a): a is Assignment =>
				typeof (a as Assignment)?.id === "string" &&
				typeof (a as Assignment)?.key === "string" &&
				typeof (a as Assignment)?.at === "number",
		);
	} catch {
		return [];
	}
}

function saveAssignments(assignments: Assignment[]): void {
	try {
		fs.writeFileSync(STATE_FILE, JSON.stringify(assignments, null, "\t"));
	} catch {
		// Best effort; the session entry and hash still keep colours stable.
	}
}

/** FNV-1a, used as a stable fallback when no assignment is recorded. */
function hash(s: string): number {
	let h = 0x811c9dc5;
	for (let i = 0; i < s.length; i++) {
		h ^= s.charCodeAt(i);
		h = Math.imul(h, 0x01000193);
	}
	return h >>> 0;
}

function byKey(key: string | undefined): Swatch | undefined {
	return SWATCHES.find((s) => s.key === key);
}

/** Read the most recent swatch stored inside the session itself. */
function storedSwatch(ctx: ExtensionContext): Swatch | undefined {
	let found: Swatch | undefined;
	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type === "custom" && entry.customType === ENTRY_TYPE) {
			const data = entry.data as { key?: unknown } | undefined;
			if (typeof data?.key === "string") {
				const sw = byKey(data.key);
				if (sw) found = sw;
			}
		}
	}
	return found;
}

function pickSwatch(id: string, assignments: Assignment[]): Swatch {
	const existing = byKey(assignments.find((a) => a.id === id)?.key);
	if (existing) return existing;

	// Prefer a swatch unused by recent sessions so concurrent sessions differ.
	const recent = assignments.slice(-SWATCHES.length).map((a) => a.key);
	const unused = SWATCHES.filter((s) => !recent.includes(s.key));
	const pool = unused.length > 0 ? unused : SWATCHES;
	return pool[Math.floor(Math.random() * pool.length)] ?? SWATCHES[hash(id) % SWATCHES.length]!;
}

/* -------------------------------------------------------------------- theme */

const BG_KEYS = new Set([
	"selectedBg",
	"searchMatchBg",
	"userMessageBg",
	"customMessageBg",
	"toolPendingBg",
	"toolSuccessBg",
	"toolErrorBg",
]);

/** Build a copy of the active theme whose background surfaces use the swatch. */
function buildSessionTheme(ctx: ExtensionContext, sw: Swatch): Theme | undefined {
	const active = ctx.ui.theme;
	const baseName = active.name ?? "dark";
	const info = ctx.ui.getAllThemes().find((t) => t.name === baseName);
	if (!info?.path) return undefined;

	let json: { vars?: Record<string, string | number>; colors?: Record<string, string | number> };
	try {
		json = JSON.parse(fs.readFileSync(info.path, "utf8"));
	} catch {
		return undefined;
	}

	const vars = json.vars ?? {};
	const resolve = (value: string | number): string | number => {
		let current = value;
		for (let i = 0; i < 10; i++) {
			if (typeof current !== "string" || current === "" || !(current in vars)) break;
			current = vars[current]!;
		}
		return current;
	};

	const fgColors: Record<string, string | number> = {};
	const bgColors: Record<string, string | number> = {};
	for (const [key, value] of Object.entries(json.colors ?? {})) {
		if (BG_KEYS.has(key)) bgColors[key] = resolve(value);
		else fgColors[key] = resolve(value);
	}

	const tint = surfacesFor(sw);
	Object.assign(bgColors, {
		selectedBg: tint.selectedBg,
		searchMatchBg: tint.selectedBg,
		userMessageBg: tint.userMessageBg,
		customMessageBg: tint.customMessageBg,
		toolPendingBg: tint.toolPendingBg,
		toolSuccessBg: tint.toolSuccessBg,
		toolErrorBg: tint.toolErrorBg,
	});

	try {
		return new Theme(fgColors, bgColors, active.getColorMode(), { name: baseName });
	} catch {
		return undefined;
	}
}

/* ------------------------------------------------------------ OSC 11 canvas */

const setBg = (hex: string) => `\x1b]11;${hex}\x07`;
const resetBg = "\x1b]111\x07";

function writeOut(seq: string): void {
	try {
		process.stdout.write(seq);
	} catch {
		// Terminal already gone.
	}
}

/* --------------------------------------------------------------- extension */

export default function (pi: ExtensionAPI) {
	let applied = false;
	let exitHook: (() => void) | undefined;

	const armExitReset = () => {
		if (exitHook) return;
		exitHook = () => {
			try {
				fs.writeSync(1, resetBg);
			} catch {
				// Terminal already gone.
			}
		};
		process.on("exit", exitHook);
	};
	const disarmExitReset = () => {
		if (!exitHook) return;
		process.off("exit", exitHook);
		exitHook = undefined;
	};

	const resolveSwatch = (ctx: ExtensionContext, persist: boolean): Swatch => {
		const id = ctx.sessionManager.getSessionId();
		const found = storedSwatch(ctx);
		if (found) return found;

		const assignments = loadAssignments();
		const sw = pickSwatch(id, assignments);
		if (persist) {
			saveAssignments(
				[...assignments.filter((a) => a.id !== id), { id, key: sw.key, at: Date.now() }].slice(
					-MAX_REMEMBERED,
				),
			);
			pi.appendEntry(ENTRY_TYPE, { key: sw.key });
		}
		return sw;
	};

	let activeTheme: Theme | undefined;
	let activeSessionId: string | undefined;
	let expectedUserBg: string | undefined;
	let reapplyTimers: Array<ReturnType<typeof setTimeout>> = [];

	let activeSwatch: Swatch | undefined;

	const persistSwatch = (ctx: ExtensionContext, sw: Swatch): void => {
		const id = ctx.sessionManager.getSessionId();
		pi.appendEntry(ENTRY_TYPE, { key: sw.key });
		const assignments = loadAssignments();
		saveAssignments(
			[...assignments.filter((a) => a.id !== id), { id, key: sw.key, at: Date.now() }].slice(
				-MAX_REMEMBERED,
			),
		);
	};

	const applySwatch = (ctx: ExtensionContext, sw: Swatch): void => {
		const theme = buildSessionTheme(ctx, sw);
		activeSwatch = sw;
		activeTheme = theme;
		expectedUserBg = theme?.getBgAnsi("userMessageBg");
		if (theme) ctx.ui.setTheme(theme);
		writeOut(setBg(surfacesFor(sw).canvas));
	};

	// pi calls themeController.applyFromSettings() immediately after session_start
	// on reload/switch, which would clobber our in-memory theme. Re-assert it.
	const ensureApplied = (ctx: ExtensionContext): void => {
		if (!activeTheme || ctx.sessionManager.getSessionId() !== activeSessionId) return;
		if (expectedUserBg && ctx.ui.theme.getBgAnsi("userMessageBg") === expectedUserBg) return;
		ctx.ui.setTheme(activeTheme);
	};

	const clearReapplyTimers = (): void => {
		for (const timer of reapplyTimers) clearTimeout(timer);
		reapplyTimers = [];
	};

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		activeSessionId = ctx.sessionManager.getSessionId();
		applySwatch(ctx, resolveSwatch(ctx, true));

		clearReapplyTimers();
		for (const delay of [0, 100, 400]) {
			reapplyTimers.push(setTimeout(() => ensureApplied(ctx), delay));
		}

		if (process.stdout.isTTY) {
			applied = true;
			armExitReset();
		}
	});

	// Guarantees the tint is restored after any startup/reload ordering.
	pi.on("agent_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ensureApplied(ctx);
	});

	pi.on("session_shutdown", () => {
		clearReapplyTimers();
		if (!applied) return;
		applied = false;
		disarmExitReset();
		writeOut(resetBg);
	});

	pi.registerCommand("session-bg", {
		description: "Show, cycle, set, or test the per-session background colour",
		// usage is documented in the file header; args are parsed below
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();

			if (arg === "test") {
				writeOut(setBg("#ff00ff"));
				ctx.ui.notify(
					"OSC 11 test: pane background set to magenta. If it stays unchanged, your terminal/multiplexer (e.g. herdr) blocks OSC 11 - the theme tint is still active.",
					"info",
				);
				return;
			}
			if (arg === "reset") {
				writeOut(resetBg);
				ctx.ui.notify("OSC 11 background reset.", "info");
				return;
			}

			let next: Swatch | undefined;
			const currentKey = activeSwatch?.key ?? resolveSwatch(ctx, false).key;
			const currentIndex = SWATCHES.findIndex((s) => s.key === currentKey);

			if (arg === "next") {
				next = SWATCHES[(currentIndex + 1) % SWATCHES.length];
			} else if (arg === "prev") {
				next = SWATCHES[(currentIndex - 1 + SWATCHES.length) % SWATCHES.length];
			} else if (arg === "random") {
				const others = SWATCHES.filter((s) => s.key !== currentKey);
				next = others[Math.floor(Math.random() * others.length)];
			} else if (arg === "pick") {
				const choice = await ctx.ui.select(
					"Session colour",
					SWATCHES.map((s) => s.key),
				);
				if (choice) next = byKey(choice);
			} else if (arg) {
				next = byKey(arg);
				if (!next) {
					ctx.ui.notify(`Unknown swatch "${arg}". Try: ${SWATCHES.map((s) => s.key).join(", ")}`, "warning");
					return;
				}
			}

			const sw = next ?? byKey(currentKey) ?? resolveSwatch(ctx, false);
			if (next) persistSwatch(ctx, sw);
			applySwatch(ctx, sw);
			const active =
				!!activeTheme &&
				ctx.sessionManager.getSessionId() === activeSessionId &&
				ctx.ui.theme.getBgAnsi("userMessageBg") === expectedUserBg;
			ctx.ui.notify(
				`Session colour: ${sw.key} (canvas ${surfacesFor(sw).canvas}), theme tint ${active ? "active" : "not active"}`,
				"info",
			);
		},
	});
}