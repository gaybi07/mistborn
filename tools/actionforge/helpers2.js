(() => {
  const setv = (i, v) => { Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(i, String(v)); i.dispatchEvent(new Event("input", { bubbles: true })); i.dispatchEvent(new Event("change", { bubbles: true })); };
  window.afSlider = (name, v) => {
    const i = [...document.querySelectorAll("input[type=range]")].find(i => i.offsetParent && (i.closest("div")?.innerText || "").startsWith(name));
    if (!i) return name + "?"; setv(i, v); return name + "=" + i.value;
  };
  window.afFrame = async n => {
    const pause = [...document.querySelectorAll("button")].find(b => b.offsetParent && /pause|pausa/i.test((b.getAttribute("aria-label") || b.title || "")));
    if (pause) pause.click();
    const f = [...document.querySelectorAll("input")].find(i => i.offsetParent && /^Frame/.test(i.placeholder || "") ) || [...document.querySelectorAll("input")].find(i => i.offsetParent && /Frame \d+/.test(i.value));
    return f ? (f.focus(), setv(f, n), f.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true })), "frame " + n) : "sin campo de frame";
  };
  return [...document.querySelectorAll("input")].filter(i => i.offsetParent && i.type !== "range" && i.type !== "checkbox").map(i => i.type + ":" + (i.placeholder || "") + ":" + i.value + ":" + (i.getAttribute("aria-label") || i.title || "").slice(0, 50)).slice(0, 20);
})()
