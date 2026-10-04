#!/usr/bin/env node
// pi-local-patch: recognise multiline input that arrives without bracketed
// paste markers (herdr/ConPTY, tmux, Termux, ...) as a paste instead of
// treating the first \r as Enter/submit.
//
// Port of https://github.com/earendil-works/pi/pull/7382 into pi's bundled
// StdinBuffer. Re-apply after every pi update:
//
//   node ~/.pi/agent/patches/pi-unmarked-paste.mjs
//
// See ~/.pi/agent/pi-unmarked-paste.patch.md for details.

import fs from "node:fs";
import path from "node:path";

const pkgRoot = process.argv[2] ??
  path.join(process.env.APPDATA ?? "", "npm", "node_modules", "@earendil-works", "pi-coding-agent");
const chunksDir = path.join(pkgRoot, "dist", "bundle", "chunks");

const MARKER = "classifyUnmarkedPaste";
const NEEDLE = /var StdinBuffer=class extends EventEmitter(?:2)?\{/;

const classify = String.raw`function classifyUnmarkedPaste(sequences){let sawNewline=!1,sawTextAfterNewline=!1;for(let sequence of sequences){if(sequence==="\r"||sequence==="\n"){sawNewline=!0;continue}if(sequence==="\t"){if(sawNewline)sawTextAfterNewline=!0;continue}if(sequence.length!==1)return"none";let code=sequence.charCodeAt(0);if(code<32||code>=127&&code<=159)return"none";if(sawNewline)sawTextAfterNewline=!0}return sawNewline?sawTextAfterNewline?"paste":"pending":"none"}`;

const edits = [
  [
    String.raw`return{sequences,remainder:""}}var StdinBuffer=class extends EventEmitter2{`,
    String.raw`return{sequences,remainder:""}}` + classify + `var StdinBuffer=class extends EventEmitter2{`,
  ],
  [
    String.raw`pasteBuffer="";pendingKittyPrintableCodepoint;constructor(options={}){`,
    String.raw`pasteBuffer="";pendingKittyPrintableCodepoint;pendingUnmarkedPasteSequences=[];unmarkedPasteTimeout=null;constructor(options={}){`,
  ],
  [
    String.raw`process(data){this.timeout&&(clearTimeout(this.timeout),this.timeout=null);let str2;`,
    String.raw`process(data){this.timeout&&(clearTimeout(this.timeout),this.timeout=null),this.unmarkedPasteTimeout&&(clearTimeout(this.unmarkedPasteTimeout),this.unmarkedPasteTimeout=null);let str2;`,
  ],
  [
    String.raw`else str2=data;if(str2.length===0&&this.buffer.length===0){`,
    String.raw`else str2=data;if(this.pendingUnmarkedPasteSequences.length>0){str2=this.pendingUnmarkedPasteSequences.join("")+str2,this.pendingUnmarkedPasteSequences=[]}if(str2.length===0&&this.buffer.length===0){`,
  ],
  [
    String.raw`let result=extractCompleteSequences(this.buffer);this.buffer=result.remainder;for(let sequence of result.sequences)this.emitDataSequence(sequence);if(this.buffer.length>0){`,
    String.raw`let result=extractCompleteSequences(this.buffer);this.buffer=result.remainder;if(this.buffer.length===0){let unmarkedPaste=classifyUnmarkedPaste(result.sequences);if(unmarkedPaste==="paste"){this.pendingKittyPrintableCodepoint=void 0,this.emit("paste",result.sequences.join(""));return}if(unmarkedPaste==="pending"){let newlineIndex=result.sequences.findIndex(sequence=>sequence==="\r"||sequence==="\n");for(let sequence of result.sequences.slice(0,newlineIndex))this.emitDataSequence(sequence);this.pendingUnmarkedPasteSequences=result.sequences.slice(newlineIndex),this.unmarkedPasteTimeout=setTimeout(()=>{let pending=this.pendingUnmarkedPasteSequences;this.pendingUnmarkedPasteSequences=[],this.unmarkedPasteTimeout=null;for(let sequence of pending)this.emitDataSequence(sequence)},this.timeoutMs);return}}for(let sequence of result.sequences)this.emitDataSequence(sequence);if(this.buffer.length>0){`,
  ],
  [
    String.raw`flush(){if(this.timeout&&(clearTimeout(this.timeout),this.timeout=null),this.buffer.length===0)return[];let sequences=[this.buffer];return this.buffer="",this.pendingKittyPrintableCodepoint=void 0,sequences}`,
    String.raw`flush(){this.timeout&&(clearTimeout(this.timeout),this.timeout=null),this.unmarkedPasteTimeout&&(clearTimeout(this.unmarkedPasteTimeout),this.unmarkedPasteTimeout=null);let sequences=this.pendingUnmarkedPasteSequences;this.pendingUnmarkedPasteSequences=[],this.buffer.length>0&&(sequences.push(this.buffer),this.buffer="");if(sequences.length===0)return[];return this.pendingKittyPrintableCodepoint=void 0,sequences}`,
  ],
  [
    String.raw`clear(){this.timeout&&(clearTimeout(this.timeout),this.timeout=null),this.buffer="",this.pasteMode=!1,this.pasteBuffer="",this.pendingKittyPrintableCodepoint=void 0}`,
    String.raw`clear(){this.timeout&&(clearTimeout(this.timeout),this.timeout=null),this.unmarkedPasteTimeout&&(clearTimeout(this.unmarkedPasteTimeout),this.unmarkedPasteTimeout=null),this.buffer="",this.pasteMode=!1,this.pasteBuffer="",this.pendingKittyPrintableCodepoint=void 0,this.pendingUnmarkedPasteSequences=[]}`,
  ],
  [
    String.raw`getBuffer(){return this.buffer}`,
    String.raw`getBuffer(){return this.pendingUnmarkedPasteSequences.join("")+this.buffer}`,
  ],
];

if (!fs.existsSync(chunksDir)) {
  console.error(`chunks directory not found: ${chunksDir}`);
  process.exit(1);
}

const targets = fs
  .readdirSync(chunksDir)
  .filter((name) => name.endsWith(".js"))
  .map((name) => path.join(chunksDir, name))
  .filter((file) => NEEDLE.test(fs.readFileSync(file, "utf8")));

if (targets.length === 0) {
  console.error(`no bundled StdinBuffer found under ${chunksDir}`);
  process.exit(1);
}

let changed = 0;
for (const file of targets) {
  let src = fs.readFileSync(file, "utf8");
  if (src.includes(MARKER)) {
    console.log(`already patched: ${file}`);
    continue;
  }

  const orig = src;
  for (const [oldText, newText] of edits) {
    // Bundler names EventEmitter differently between releases; match only
    // the name actually used by this StdinBuffer, not every emitter in the file.
    const emitter = src.match(NEEDLE)[0].includes("EventEmitter2") ? "EventEmitter2" : "EventEmitter";
    const inputName = src.includes("let str2;if(Buffer.isBuffer(data))") ? "str2" : "str";
    const before = oldText.replaceAll("EventEmitter2", emitter).replaceAll("str2", inputName);
    const after = newText.replaceAll("EventEmitter2", emitter).replaceAll("str2", inputName);
    const count = src.split(before).length - 1;
    if (count !== 1) {
      throw new Error(`${path.basename(file)}: expected 1 occurrence, got ${count} for: ${before.slice(0, 60)}...`);
    }
    src = src.replace(before, after);
  }
  if (src === orig) throw new Error(`${path.basename(file)}: nothing changed`);

  const backup = `${file}.pi-unmarked-paste.bak`;
  if (!fs.existsSync(backup)) fs.writeFileSync(backup, orig);
  fs.writeFileSync(file, src);
  changed++;
  console.log(`patched: ${file} (backup: ${backup})`);
}

console.log(changed > 0 ? "done. restart pi to apply." : "nothing to do.");
