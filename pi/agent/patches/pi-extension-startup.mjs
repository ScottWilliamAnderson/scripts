// Reapply only the two acknowledged experimental startup notices and Chrome
// isolation. Actual config, storage, tool and connection warnings stay intact.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

export function replaceOnce(source, before, after) {
    if (source.includes(after)) return source;
    assert.equal(source.split(before).length - 1, 1, "Package changed; review patch before applying");
    return source.replace(before, after);
}

if (process.argv.includes("--test")) {
    assert.equal(replaceOnce("before", "before", "after"), "after");
    assert.equal(replaceOnce("after", "before", "after"), "after");
    assert.throws(() => replaceOnce("different", "before", "after"));
    assert.throws(() => replaceOnce("before before", "before", "after"));
    console.log("Patch checks passed (including idempotence and changed-package rejection).");
} else {
    const agent = process.argv[2] ?? path.join(os.homedir(), ".pi", "agent");
    const root = path.join(agent, "npm", "node_modules", "@narumitw");
    const changes = [];
    const plan = (file, before, after) => {
        const source = fs.readFileSync(file, "utf8");
        const result = replaceOnce(source, before, after);
        if (result !== source) changes.push([file, result]);
    };
    plan(path.join(root, "pi-analytics", "dist", "index.ts"),
        'if (ctx.hasUI) ctx.ui.notify(EXPERIMENTAL_WARNING, "warning");',
        '// pi-local-patch: experimental notice acknowledged; real warnings retained.');
    plan(path.join(root, "pi-analytics", "src", "analytics.ts"),
        'if (ctx.hasUI) ctx.ui.notify(EXPERIMENTAL_WARNING, "warning");',
        '// pi-local-patch: experimental notice acknowledged; real warnings retained.');
    for (const relative of ["dist/index.ts", "src/file-context.ts"]) {
        const file = path.join(root, "pi-file-context", relative);
        const source = fs.readFileSync(file, "utf8");
        const marker = "// pi-local-patch: experimental File Context notice acknowledged.";
        if (source.includes(marker)) continue;
        const blocks = [...source.matchAll(/ctx\.ui\.notify\(\s*shortcut\s*\? `Experimental File Context loaded\.[\s\S]*?"warning",?\s*\);/g)];
        assert.equal(blocks.length, 1, `${relative}: File Context notice changed; review patch`);
        plan(file, blocks[0][0], marker);
    }
    const chrome = path.join(root, "pi-chrome-devtools");
    const files = [path.join(chrome, "src", "browser-manager.ts"),
        ...fs.readdirSync(path.join(chrome, "dist", "chunks"))
            .filter(name => name.endsWith(".ts"))
            .map(name => path.join(chrome, "dist", "chunks", name))]
        .filter(file => fs.readFileSync(file, "utf8").includes("function buildManagedBrowserLaunchArguments"));
    assert.ok(files.length >= 2, "Chrome source/runtime changed; review isolation patch");
    for (const file of files) {
        if (fs.readFileSync(file, "utf8").includes('"--disable-sync"')) continue;
        plan(file, '"--no-first-run",', '"--disable-sync", // pi-local-patch: no managed-browser sync\n"--no-first-run",');
    }
    // Validate every target before writing anything.
    for (const [file, source] of changes) {
        fs.writeFileSync(file, source);
        console.log(`Patched: ${path.relative(agent, file)}`);
    }
    console.log(changes.length ? "Restart pi to apply." : "All extension patches already applied.");
}
