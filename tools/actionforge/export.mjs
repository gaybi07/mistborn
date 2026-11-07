// Baja un clip de ActionForge (app de escritorio abierta con --remote-debugging-port=9333) como FBX con esqueleto
// de Mixamo, sin malla, con ajustes opcionales del panel Adjust.
//   node tools/actionforge/export.mjs <clip> <salida.fbx> ["<ajustes>"]
// clip: el id de la biblioteca (sword_regular_b, ninjajump_start...) o el de una animación importada
// (user.<nombre>_<hash>, ver location.hash). ajustes: lo que va tras "#a=", p. ej.
//   "posture:k0=0|0.42=0|0.57=-50,armSpace:k0=0|0.57=-20,headPitch:k0=20"
// (parámetro:k<fracción del clip>=<grados>|<fracción>=<grados>...; varios separados por coma).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const [clip, out, adjust = ""] = process.argv.slice(2);
if (!clip || !out) {
  console.log("uso: node tools/actionforge/export.mjs <clip> <salida.fbx> [ajustes]");
  process.exit(1);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const list = await (await fetch("http://127.0.0.1:9333/json")).json();
const page = list.find(t => t.type === "page");
let ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener("open", r, { once: true }));
let id = 0;
const call = (method, params = {}) => new Promise((res, rej) => {
  const my = ++id;
  const on = ev => { const m = JSON.parse(ev.data); if (m.id === my) { ws.removeEventListener("message", on); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
  ws.addEventListener("message", on);
  ws.send(JSON.stringify({ id: my, method, params }));
});
const ev = async expr => (await call("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true, timeout: 120000 })).result.value;
await call("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
const hash = (adjust ? `a=${adjust}&` : "") + `clip=${clip}`;
await ev(`location.href = 'https://actionforge.app/#${hash}'; location.reload(); 'ok'`).catch(() => {});
ws.close();
await new Promise(r => setTimeout(r, 9000));  // recarga la app
ws = new WebSocket((await (await fetch("http://127.0.0.1:9333/json")).json()).find(t => t.type === "page").webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener("open", r, { once: true }));
await call("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
console.log("cargado:", await ev("location.hash"));
await ev(fs.readFileSync(path.join(here, "helpers.js"), "utf8"));
const r = await ev(`(async () => await afDownload(${JSON.stringify(out)}))()`);
if (!r || !r.b64) {
  console.log("no se bajó:", JSON.stringify(r));
  process.exit(1);
}
fs.writeFileSync(out, Buffer.from(r.b64, "base64"));
console.log("guardado", out, fs.statSync(out).size, "bytes");
ws.close();
