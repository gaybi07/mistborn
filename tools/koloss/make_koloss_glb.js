// Arma assets/koloss/Koloss.glb a partir del modelo estático del koloss (base.obj + texturas):
// le crea un esqueleto parecido al del Mistborn (mismos nombres y jerarquía que assets/mixamo/Mistborn.glb:
// pelvis, spine_01..03, clavicle, upperarm, lowerarm, hand, thigh, calf, foot, ball, neck_01, Head) y los
// pesos de la malla según la cercanía a cada hueso. Las animaciones no se copian aquí: el juego las toma del
// personaje principal en tiempo de ejecución (ver BoneTools.UE_TO_UE y ModelRig.retarget_from).
//
// Uso:  node tools/koloss/make_koloss_glb.js <carpeta con base.obj y texture_*.png> assets/koloss
// El modelo está en pose T, mide 1,725 m, mira hacia +Z y su izquierda es +X (como el resto de los glTF).

const fs = require("fs");
const path = require("path");

const [srcDir, outDir] = process.argv.slice(2);
if (!srcDir || !outDir) {
	console.error("uso: node make_koloss_glb.js <carpeta del modelo> <carpeta de salida>");
	process.exit(1);
}

// ---------------------------------------------------------------- Malla
const verts = [], uvs = [], norms = [];
const outPos = [], outUv = [], outNorm = [], indices = [];
const keyToIndex = new Map();
for (const line of fs.readFileSync(path.join(srcDir, "base.obj"), "utf8").split("\n")) {
	const p = line.trim().split(/\s+/);
	if (p[0] === "v") verts.push(p.slice(1, 4).map(Number));
	else if (p[0] === "vt") uvs.push(p.slice(1, 3).map(Number));
	else if (p[0] === "vn") norms.push(p.slice(1, 4).map(Number));
	else if (p[0] === "f") {
		const idx = [];
		for (const corner of p.slice(1)) {
			let i = keyToIndex.get(corner);
			if (i === undefined) {
				const [v, t, n] = corner.split("/").map((s) => (s === "" ? NaN : parseInt(s) - 1));
				i = outPos.length;
				outPos.push(verts[v]);
				outUv.push(isNaN(t) ? [0, 0] : [uvs[t][0], 1 - uvs[t][1]]);
				outNorm.push(isNaN(n) ? [0, 1, 0] : norms[n]);
				keyToIndex.set(corner, i);
			}
			idx.push(i);
		}
		for (let k = 1; k + 1 < idx.length; k++) indices.push(idx[0], idx[k], idx[k + 1]);
	}
}

// ---------------------------------------------------------------- Esqueleto
// [nombre, padre, cabeza, cola]; la cola solo orienta el hueso (su +Y apunta de la cabeza a la cola).
const L = [
	["root", null, [0, 0, 0], [0, 0.2, 0]],
	["pelvis", "root", [0, 0.95, -0.01], [0, 1.07, -0.01]],
	["spine_01", "pelvis", [0, 1.07, -0.01], [0, 1.19, -0.015]],
	["spine_02", "spine_01", [0, 1.19, -0.015], [0, 1.31, -0.02]],
	["spine_03", "spine_02", [0, 1.31, -0.02], [0, 1.5, -0.02]],
	["neck_01", "spine_03", [0, 1.5, -0.02], [0, 1.58, 0.0]],
	["Head", "neck_01", [0, 1.58, 0.0], [0, 1.73, 0.02]],
];
const side = (s, sx) => {
	const m = (v) => [v[0] * sx, v[1], v[2]];
	return [
		["clavicle_" + s, "spine_03", m([0.05, 1.4, -0.03]), m([0.28, 1.38, -0.04])],
		["upperarm_" + s, "clavicle_" + s, m([0.28, 1.38, -0.04]), m([0.58, 1.38, -0.05])],
		["lowerarm_" + s, "upperarm_" + s, m([0.58, 1.38, -0.05]), m([0.76, 1.38, -0.05])],
		["hand_" + s, "lowerarm_" + s, m([0.76, 1.38, -0.05]), m([0.88, 1.37, -0.05])],
		["thigh_" + s, "pelvis", m([0.17, 0.95, -0.015]), m([0.18, 0.5, -0.03])],
		["calf_" + s, "thigh_" + s, m([0.18, 0.5, -0.03]), m([0.25, 0.11, -0.065])],
		["foot_" + s, "calf_" + s, m([0.25, 0.11, -0.065]), m([0.28, 0.03, 0.1])],
		["ball_" + s, "foot_" + s, m([0.28, 0.03, 0.1]), m([0.28, 0.02, 0.22])],
	];
};
L.push(...side("l", 1), ...side("r", -1));
const bones = L.map(([name, parent, head, tail]) => ({ name, parent, head, tail }));
const byName = Object.fromEntries(bones.map((b, i) => [b.name, i]));

const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const len = (a) => Math.hypot(a[0], a[1], a[2]);
const norm = (a) => { const l = len(a); return [a[0] / l, a[1] / l, a[2] / l]; };

// Cuaternión [x, y, z, w] que lleva el vector unitario a hasta el b por el camino más corto.
function fromTo(a, b) {
	const d = dot(a, b);
	if (d < -0.999999) return [1, 0, 0, 0];
	const c = cross(a, b);
	const q = [c[0], c[1], c[2], 1 + d];
	const l = Math.hypot(...q);
	return q.map((x) => x / l);
}
const qmul = (a, b) => [
	a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
	a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
	a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
	a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
];
const qconj = (q) => [-q[0], -q[1], -q[2], q[3]];
function qrot(q, v) {
	const r = qmul(qmul(q, [v[0], v[1], v[2], 0]), qconj(q));
	return [r[0], r[1], r[2]];
}
function qmat(q) { // matriz 3x3 por filas
	const [x, y, z, w] = q;
	return [
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
	];
}

for (const b of bones) {
	b.worldQ = fromTo([0, 1, 0], norm(sub(b.tail, b.head)));
	const p = b.parent === null ? null : bones[byName[b.parent]];
	b.localT = p ? qrot(qconj(p.worldQ), sub(b.head, p.head)) : b.head;
	b.localQ = p ? qmul(qconj(p.worldQ), b.worldQ) : b.worldQ;
}

// ---------------------------------------------------------------- Pesos
function segDist(p, a, b) {
	const ab = sub(b, a), ap = sub(p, a);
	const t = Math.max(0, Math.min(1, dot(ap, ab) / dot(ab, ab)));
	return len(sub(ap, [ab[0] * t, ab[1] * t, ab[2] * t]));
}
const SKIP = new Set(["root"]);

// Qué huesos pueden mover a un vértice (evita que un brazo arrastre el torso o una pierna a la otra).
function candidates(p) {
	const s = p[0] >= 0 ? "l" : "r";
	const ax = Math.abs(p[0]);
	const out = [];
	for (const b of bones) {
		if (SKIP.has(b.name)) continue;
		const n = b.name;
		const bs = n.endsWith("_l") ? "l" : n.endsWith("_r") ? "r" : "";
		if (bs && bs !== s) continue;
		const isArm = /^(clavicle|upperarm|lowerarm|hand)_/.test(n);
		const isLeg = /^(thigh|calf|foot|ball)_/.test(n);
		if (isArm && !(n.startsWith("clavicle") ? ax > 0.2 && p[1] > 1.3 : ax > 0.3 && p[1] > 1.1)) continue;
		if (isLeg && p[1] > 1.02) continue;
		if (!isArm && !isLeg && ax > 0.42 && p[1] > 1.1) continue; // el brazo extendido solo lo mueve el brazo
		if (/^(spine_0[12]|pelvis)$/.test(n) && p[1] > 1.5) continue;
		if (/^(neck_01|Head)$/.test(n) && p[1] < 1.42) continue;
		if (isLeg === false && /^(pelvis|spine_01)$/.test(n) && p[1] < 0.78) continue;
		out.push(b);
	}
	return out;
}

const joints = [], weights = [];
for (const p of outPos) {
	const cand = candidates(p).map((b) => ({ b, d: segDist(p, b.head, b.tail) }));
	cand.sort((x, y) => x.d - y.d);
	const top = cand.slice(0, 4).map((c) => ({ i: byName[c.b.name], w: 1 / Math.pow(c.d + 0.03, 4) }));
	const total = top.reduce((a, c) => a + c.w, 0);
	while (top.length < 4) top.push({ i: 0, w: 0 });
	joints.push(top.map((c) => c.i));
	weights.push(top.map((c) => c.w / total));
}

// ---------------------------------------------------------------- GLB
const chunks = [];
const views = [], accessors = [];
function add(typedArray, target, type, componentType, count, extra = {}) {
	let buf = Buffer.from(typedArray.buffer, typedArray.byteOffset, typedArray.byteLength);
	const pad = (4 - (buf.length % 4)) % 4;
	const offset = chunks.reduce((a, c) => a + c.length, 0);
	chunks.push(Buffer.concat([buf, Buffer.alloc(pad)]));
	const view = { buffer: 0, byteOffset: offset, byteLength: buf.length };
	if (target) view.target = target;
	views.push(view);
	accessors.push({ bufferView: views.length - 1, componentType, count, type, ...extra });
	return accessors.length - 1;
}
const N = outPos.length;
let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
for (const p of outPos) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], p[i]); mx[i] = Math.max(mx[i], p[i]); }
const aPos = add(new Float32Array(outPos.flat()), 34962, "VEC3", 5126, N, { min: mn, max: mx });
const aNorm = add(new Float32Array(outNorm.flat()), 34962, "VEC3", 5126, N);
const aUv = add(new Float32Array(outUv.flat()), 34962, "VEC2", 5126, N);
const aJoints = add(new Uint8Array(joints.flat()), 34962, "VEC4", 5121, N);
const aWeights = add(new Float32Array(weights.flat()), 34962, "VEC4", 5126, N);
const aIdx = add(new Uint32Array(indices), 34963, "SCALAR", 5125, indices.length);

// Matrices inversas de reposo (columnas): la pose de reposo es la de la malla.
const ibm = new Float32Array(bones.length * 16);
bones.forEach((b, j) => {
	const r = qmat(b.worldQ); // R por filas; la inversa es su traspuesta
	const ri = [[r[0][0], r[1][0], r[2][0]], [r[0][1], r[1][1], r[2][1]], [r[0][2], r[1][2], r[2][2]]];
	const t = [-dot(ri[0], b.head), -dot(ri[1], b.head), -dot(ri[2], b.head)];
	const m = [ri[0][0], ri[1][0], ri[2][0], 0, ri[0][1], ri[1][1], ri[2][1], 0, ri[0][2], ri[1][2], ri[2][2], 0, t[0], t[1], t[2], 1];
	ibm.set(m, j * 16);
});
const aIbm = add(ibm, null, "MAT4", 5126, bones.length);

const nodes = [{ name: "Koloss", mesh: 0, skin: 0 }];
for (const b of bones) {
	const children = bones.filter((c) => c.parent === b.name).map((c) => byName[c.name] + 1);
	const n = { name: b.name, translation: b.localT, rotation: b.localQ };
	if (children.length) n.children = children;
	nodes.push(n);
}
const json = {
	asset: { version: "2.0", generator: "tools/koloss/make_koloss_glb.js" },
	scene: 0,
	scenes: [{ nodes: [0, 1] }],
	nodes,
	skins: [{ joints: bones.map((_, i) => i + 1), inverseBindMatrices: aIbm, skeleton: 1 }],
	meshes: [{ name: "Koloss", primitives: [{ attributes: { POSITION: aPos, NORMAL: aNorm, TEXCOORD_0: aUv, JOINTS_0: aJoints, WEIGHTS_0: aWeights }, indices: aIdx, material: 0 }] }],
	materials: [{ name: "Koloss", pbrMetallicRoughness: { baseColorTexture: { index: 0 }, metallicFactor: 0.0, roughnessFactor: 0.85 }, normalTexture: { index: 1 } }],
	textures: [{ source: 0, sampler: 0 }, { source: 1, sampler: 0 }],
	samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 }],
	images: [{ uri: "Koloss_diffuse.png" }, { uri: "Koloss_normal.png" }],
	accessors,
	bufferViews: views,
	buffers: [{ byteLength: chunks.reduce((a, c) => a + c.length, 0) }],
};
let jsonBuf = Buffer.from(JSON.stringify(json));
jsonBuf = Buffer.concat([jsonBuf, Buffer.alloc((4 - (jsonBuf.length % 4)) % 4, 0x20)]);
const bin = Buffer.concat(chunks);
const header = Buffer.alloc(12);
header.write("glTF", 0);
header.writeUInt32LE(2, 4);
header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + bin.length, 8);
const jh = Buffer.alloc(8); jh.writeUInt32LE(jsonBuf.length, 0); jh.write("JSON", 4);
const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.write("BIN\0", 4);
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "Koloss.glb"), Buffer.concat([header, jh, jsonBuf, bh, bin]));
fs.copyFileSync(path.join(srcDir, "texture_diffuse.png"), path.join(outDir, "Koloss_diffuse.png"));
fs.copyFileSync(path.join(srcDir, "texture_normal.png"), path.join(outDir, "Koloss_normal.png"));
console.log(`Koloss.glb: ${N} vértices, ${indices.length / 3} triángulos, ${bones.length} huesos`);
