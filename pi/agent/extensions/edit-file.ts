/**
 * Edit File in External Editor
 *
 * Opens a repo file in an external editor (Microsoft Edit by default) with full
 * terminal access. The pi TUI suspends while the editor runs and resumes when it
 * exits. Unlike the built-in Ctrl+G editor (which edits your *prompt draft*),
 * this opens the actual file pi is working on.
 *
 * Usage:
 *   /edit                 Open the file pi most recently wrote/edited (else last read)
 *   /edit <path>          Open a specific file, relative to the session cwd
 *
 * Editor command resolution: PI_EDITOR, then $VISUAL, then $EDITOR, then "edit".
 *
 * When the file's contents change, a hidden note is queued for the next turn so
 * pi re-reads it instead of relying on stale content.
 */

import { spawn } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function editorCommand(): string {
	return (process.env.PI_EDITOR || process.env.VISUAL || process.env.EDITOR || "edit").trim();
}

/** Cheap change signature: avoids reading large files into memory. */
function fileSignature(path: string): string | null {
	try {
		const st = statSync(path);
		return `${st.mtimeMs}:${st.size}`;
	} catch {
		return null;
	}
}

export default function editFileExtension(pi: ExtensionAPI) {
	let lastEdited: string | undefined;
	let lastRead: string | undefined;

	// Remember the files pi touches so /edit with no argument is useful.
	pi.on("tool_call", (event) => {
		const tool = event.toolName;
		if (tool !== "read" && tool !== "write" && tool !== "edit") return;
		const p = (event.input as { path?: unknown }).path;
		if (typeof p !== "string" || p.length === 0) return;
		if (tool === "read") lastRead = p;
		else lastEdited = p;
	});

	pi.registerCommand("edit", {
		description: "Open a file in an external editor (defaults to the file pi last touched)",
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/edit is only available in the interactive TUI", "warning");
				return;
			}
			if (!ctx.isIdle()) {
				ctx.ui.notify("pi is busy - press Esc to stop it before opening the editor", "warning");
				return;
			}

			const arg = args.trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");
			const chosen = arg || lastEdited || lastRead;
			if (!chosen) {
				ctx.ui.notify("Usage: /edit <path>  (pi has not touched a file yet to default to)", "warning");
				return;
			}

			const target = isAbsolute(chosen) ? chosen : resolve(ctx.cwd, chosen);

			if (!existsSync(target)) {
				ctx.ui.notify(`File not found: ${target}`, "error");
				return;
			}
			try {
				if (statSync(target).isDirectory()) {
					ctx.ui.notify(`Not a file: ${target}`, "error");
					return;
				}
			} catch {
				ctx.ui.notify(`Cannot open: ${target}`, "error");
				return;
			}

			const [editor, ...editorArgs] = editorCommand().split(/\s+/);
			const before = fileSignature(target);

			const exitCode = await ctx.ui.custom<number | null>((tui, _theme, _keybindings, done) => {
				// Release the terminal, then hand it to the editor.
				tui.stop();
				process.stdout.write("\x1b[2J\x1b[H");

				let settled = false;
				const finish = (code: number | null) => {
					if (settled) return;
					settled = true;
					tui.start();
					tui.requestRender(true);
					done(code);
				};

				// Async spawn (not spawnSync) to avoid Node stdin races on Windows.
				const child = spawn(editor, [...editorArgs, target], {
					stdio: "inherit",
					shell: process.platform === "win32",
				});
				child.on("error", () => finish(null));
				child.on("close", (code) => finish(code));

				return { render: () => [], invalidate: () => {} };
			});

			if (exitCode !== 0) {
				ctx.ui.notify(`Editor exited with code ${exitCode ?? "?"}`, "warning");
				return;
			}

			if (fileSignature(target) !== before) {
				ctx.ui.notify(`Updated ${target}`, "info");
				// Keep pi's context fresh for the next request without forcing a turn.
				pi.sendMessage(
					{
						customType: "external-edit",
						content: `<external-edit path="${target}">The user edited this file in an external editor. Re-read it before relying on any previously seen content.</external-edit>`,
						display: false,
						details: {},
					},
					{ deliverAs: "nextTurn" },
				);
			} else {
				ctx.ui.notify(`No changes to ${target}`, "info");
			}
		},
	});
}
