(() => {
  if (!window._afBlobHook) {
    window._afBlobHook = true;
    const OB = window.Blob; window.afBlobs = [];
    window.Blob = class extends OB { constructor(p, o) { super(p, o); if (this.size > 5000) afBlobs.push(this); } };
  }
  window.sleep = ms => new Promise(r => setTimeout(r, ms));
  window.afPick = async name => {
    const card = [...document.querySelectorAll("[title],[aria-label]")].find(e => (e.getAttribute("aria-label") || e.title).split("\n")[0] === name);
    if (!card) return name + ": no está";
    card.click(); await sleep(1800);
    return (card.getAttribute("aria-label") || card.title).replace(/\n/g, " | ");
  };
  window.afSel = (label, v) => {
    const s = [...document.querySelectorAll("select")].find(s => s.offsetParent && [...s.options].some(o => o.value === v) && (s.closest("label,div")?.innerText || "").toUpperCase().includes(label));
    if (!s) return label + "?"; s.value = v; s.dispatchEvent(new Event("change", { bubbles: true })); return label + "=" + v;
  };
  window.afDownload = async (save) => {
    if (![...document.querySelectorAll("button")].some(b => b.offsetParent && b.textContent.trim() === "↓ Download"))
      [...document.querySelectorAll("button")].find(b => /^DOWNLOAD/i.test(b.textContent.trim())).click();
    await sleep(500);
    const mesh = [...document.querySelectorAll("label")].find(l => /include character mesh/i.test(l.textContent))?.querySelector("input");
    if (mesh && mesh.checked) mesh.click();
    const out = [afSel("FORMAT", "fbx"), afSel("SKELETON", "mixamo")];
    await sleep(300);
    afBlobs.length = 0;
    [...document.querySelectorAll("button")].find(b => b.offsetParent && b.textContent.trim() === "↓ Download").click();
    for (let i = 0; i < 40 && !afBlobs.length; i++) await sleep(250);
    await sleep(600);
    const b = afBlobs.sort((a, c) => c.size - a.size)[0];
    if (!b) return {err: "no blob", out};
    const bytes = new Uint8Array(await b.arrayBuffer()); let s = "";
    for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return {save, b64: btoa(s)};
  };
  return "ok";
})()
