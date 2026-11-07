// Uso: node cdp.mjs eval <archivo.js>      -> evalúa en la página de ActionForge e imprime el resultado
//      node cdp.mjs shot <salida.png>       -> captura de la ventana
// Si el resultado es {save: ruta, b64: datos}, escribe el archivo en vez de imprimirlo.
import fs from "node:fs";
const [mode, arg] = process.argv.slice(2);
const list = await (await fetch("http://127.0.0.1:9333/json")).json();
const page = list.find(t => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener("open", r, { once: true }));
let id = 0;
const call = (method, params = {}) => new Promise((res, rej) => {
  const my = ++id;
  const on = ev => { const m = JSON.parse(ev.data); if (m.id === my) { ws.removeEventListener("message", on); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
  ws.addEventListener("message", on);
  ws.send(JSON.stringify({ id: my, method, params }));
});
await call("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
await call("Page.setWebLifecycleState", { state: "active" }).catch(() => {});
if (mode === "rot") {
  // rot <hueso>,<rx>,<ry>,<rz>: elige el hueso en el Outliner y escribe la rotación con el teclado; "-" deja el eje
  const [bone, ...v] = arg.split(",");
  const ev = async e => (await call("Runtime.evaluate", { expression: e, awaitPromise: true, returnByValue: true })).result.value;
  const sec = `[...document.querySelectorAll('[data-tool="transform"]')].find(e=>e.offsetParent)`;
  const head = () => ev(`${sec}.innerText.split(String.fromCharCode(10)).map(s=>s.trim()).filter(Boolean)[1]`);
  const want = bone.replace("thigh", "Thigh").replace("calf", "Calf").replace("foot", "Foot").replace(/_(l|r)$/, (m, s) => " " + s.toUpperCase());
  for (let t = 0; t < 4 && (await head()) !== want; t++) {
    const xy = await ev(`(()=>{const sp=[...document.querySelectorAll("span")].find(e=>e.offsetParent&&e.children.length==0&&e.textContent.replace(/^[^a-z]*/,"").trim()==="${bone}"); if(!sp) return null; sp.scrollIntoView({block:"center"}); const r=sp.getBoundingClientRect(); return [r.x+r.width/2,r.y+r.height/2];})()`);
    if (!xy) break;
    await new Promise(r => setTimeout(r, 300));
    const xy2 = await ev(`(()=>{const sp=[...document.querySelectorAll("span")].find(e=>e.offsetParent&&e.children.length==0&&e.textContent.replace(/^[^a-z]*/,"").trim()==="${bone}"); const r=sp.getBoundingClientRect(); return [r.x+r.width/2,r.y+r.height/2];})()`);
    for (const type of ["mouseMoved", "mousePressed", "mouseReleased"]) await call("Input.dispatchMouseEvent", { type, x: xy2[0], y: xy2[1], button: "left", buttons: type === "mousePressed" ? 1 : 0, clickCount: 1 });
    await new Promise(r => setTimeout(r, 500));
  }
  const h = await head();
  if (h !== want) { console.log("no se eligió", bone, "(", h, ")"); } else {
    const FX = [1692, 1764, 1838];
    for (let k = 0; k < 3; k++) { if (v[k] === "-" || v[k] === undefined) continue;
      for (let t = 0; t < 6; t++) {
        if (Math.abs(parseFloat(await ev(`[...${sec}.querySelectorAll("input")][${k}].value`)) - parseFloat(v[k])) < 0.05) break;
        for (const type of ["mouseMoved", "mousePressed", "mouseReleased"]) await call("Input.dispatchMouseEvent", { type, x: FX[k], y: 242, button: "left", buttons: type === "mousePressed" ? 1 : 0, clickCount: 1 });
        await new Promise(r => setTimeout(r, 350));
        if (await ev(`(()=>{const i=document.activeElement; if(!i||i.tagName!=="INPUT") return false; i.select(); return true})()`)) {
          await call("Input.insertText", { text: v[k] });
          await call("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 }); await call("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
          await new Promise(r => setTimeout(r, 400)); }
      } }
    await new Promise(r => setTimeout(r, 300));
    console.log(h, await ev(`[...${sec}.querySelectorAll("input")].slice(0,3).map(i=>i.value).join(" ")`));
  }
} else if (mode === "wheel") {
  const [x, y, d] = arg.split(",").map(Number);
  await call("Input.dispatchMouseEvent", { type: "mouseWheel", x, y, deltaX: 0, deltaY: d });
  console.log("ok wheel", arg);
} else if (mode === "field") {
  // field x,y,texto: triple clic en el campo, escribe y Enter
  const [x, y, ...t] = arg.split(","); const M = (type, b, c = 1) => call("Input.dispatchMouseEvent", { type, x: +x, y: +y, button: "left", buttons: b, clickCount: c });
  await M("mouseMoved", 0); await M("mousePressed", 1); await M("mouseReleased", 0); await new Promise(r => setTimeout(r, 250));
  await call("Input.dispatchKeyEvent", { type: "keyDown", key: "a", code: "KeyA", modifiers: 2, windowsVirtualKeyCode: 65 }); await call("Input.dispatchKeyEvent", { type: "keyUp", key: "a", code: "KeyA", modifiers: 2, windowsVirtualKeyCode: 65 });
  await call("Input.insertText", { text: t.join(",") });
  await call("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 }); await call("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
  console.log("ok field", arg);
} else if (mode === "click" || mode === "drag" || mode === "key") {
  // click x,y | drag x1,y1,x2,y2 | key <tecla>
  const M = (type, x, y, buttons = 1) => call("Input.dispatchMouseEvent", { type, x, y, button: "left", buttons, clickCount: 1 });
  if (mode === "key") { await call("Input.dispatchKeyEvent", { type: "keyDown", key: arg, text: arg.length === 1 ? arg : undefined }); await call("Input.dispatchKeyEvent", { type: "keyUp", key: arg }); }
  else { const n = arg.split(",").map(Number);
    if (mode === "click") { await M("mouseMoved", n[0], n[1], 0); await M("mousePressed", n[0], n[1]); await M("mouseReleased", n[0], n[1], 0); }
    else { await M("mouseMoved", n[0], n[1], 0); await M("mousePressed", n[0], n[1]);
      for (let i = 1; i <= 20; i++) { await M("mouseMoved", n[0] + (n[2] - n[0]) * i / 20, n[1] + (n[3] - n[1]) * i / 20); await new Promise(r => setTimeout(r, 15)); }
      await M("mouseReleased", n[2], n[3], 0); } }
  console.log("ok", mode, arg);
} else if (mode === "shot") {
  const r = await call("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(arg, Buffer.from(r.data, "base64"));
  console.log("captura", arg);
} else {
  const r = await call("Runtime.evaluate", { expression: fs.readFileSync(arg, "utf8"), awaitPromise: true, returnByValue: true, timeout: 120000 });
  if (r.exceptionDetails) { console.log("ERROR", JSON.stringify(r.exceptionDetails).slice(0, 800)); }
  const v = r.result.value;
  const saves = Array.isArray(v) ? v.filter(x => x && x.save) : (v && v.save ? [v] : []);
  for (const s of saves) { fs.writeFileSync(s.save, Buffer.from(s.b64, "base64")); console.log("guardado", s.save, s.b64.length * 3 / 4 | 0, "bytes"); }
  if (!saves.length) console.log(JSON.stringify(v, null, 1));
}
ws.close();
