// node upload.mjs <archivo>: lo carga en la primera entrada de archivos de ActionForge (importar animación)
const file = process.argv[2];
const list = await (await fetch("http://127.0.0.1:9333/json")).json();
const page = list.find(t => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener("open", r, { once: true }));
let id = 0;
const call = (method, params = {}) => new Promise((res, rej) => { const my = ++id; const on = ev => { const m = JSON.parse(ev.data); if (m.id === my) { ws.removeEventListener("message", on); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } }; ws.addEventListener("message", on); ws.send(JSON.stringify({ id: my, method, params })); });
await call("DOM.getDocument");
const r = await call("Runtime.evaluate", { expression: 'document.querySelectorAll("input[type=file]")[0]' });
await call("DOM.setFileInputFiles", { files: [file], objectId: r.result.objectId });
console.log("subido", file);
ws.close();
