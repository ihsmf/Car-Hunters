// TikTok #5 "GEARS ARE BROKEN" - full-bleed 9:16 (no blurred bars): every shot is an animated 9:16 crop of the 1280x576
// footage. Camera moves / shake / whip are applied to the crop centre and clamped, so no frame ever shows an empty edge.
// Captions sit on a dark gradient at the top (safe zone y 150-560), boost badges at the bottom, end card full screen.
import React from "react";
import { AbsoluteFill, OffthreadVideo, Sequence, interpolate, random, spring, staticFile, useCurrentFrame } from "remotion";
import cfg from "./edit5.json";

const FPS = 30;
const W = 1080;
const H = 1920;
const SRC_W = 1280;
const SRC_H = 576;

type Seg = { clip: string; src: number[]; dur: number; cam: number[][]; fx?: string[]; caps?: any[][]; badge?: string[] };
const segs: Seg[] = (cfg as any).segments;
const prefix: string = (cfg as any).prefix;
const starts: number[] = [];
let acc = 0;
for (const s of segs) {
  starts.push(acc);
  acc += Math.round(s.dur * FPS);
}
export const totalFrames5 = acc;

const COLORS: Record<string, string> = {
  gold: "#FFC93A", yellow: "#FFD640", red: "#FF4D5E", cyan: "#3EE8FF", white: "#FFFFFF", grey: "#BFC4CE", green: "#6DF08C", blue: "#4FA3FF",
};
const fontFace = `@font-face { font-family: 'InterBlack'; src: url('${staticFile("Inter-Black.otf")}'); }`;
const ease = (u: number) => u * u * (3 - 2 * u);
const strokeCss = (px: number): React.CSSProperties => ({ WebkitTextStroke: `${px}px #0d0f17`, paintOrder: "stroke fill" as any });

// 9:16 crop of the source for camera (cx, cy, zoom) + offsets in source px; always fills the frame
function place(cx: number, cy: number, z: number, ox = 0, oy = 0) {
  const s = (H / SRC_H) * Math.max(1, z);
  const vw = SRC_W * s;
  const vh = SRC_H * s;
  const left = Math.min(0, Math.max(W - vw, W / 2 - cx * vw - ox * s));
  const top = Math.min(0, Math.max(H - vh, H / 2 - cy * vh - oy * s));
  return { left, top, vw, vh };
}

const Footage: React.FC<{ src: string; p: { left: number; top: number; vw: number; vh: number }; filter?: string; style?: React.CSSProperties; clip?: string; dx?: number }> = ({ src, p, filter, style, clip, dx = 0 }) => (
  <div style={{ position: "absolute", inset: 0, overflow: "hidden", clipPath: clip, ...style }}>
    <OffthreadVideo src={src} muted style={{ position: "absolute", left: p.left + dx, top: p.top, width: p.vw, height: p.vh, filter }} />
  </div>
);

const Caption: React.FC<{ l1: string; l2: string; color: string; t: number }> = ({ l1, l2, color, t }) => {
  const f = Math.round(t * FPS);
  const pop = spring({ frame: f, fps: FPS, config: { damping: 9, stiffness: 180, mass: 0.6 } });
  const words = l2.split(" ");
  const size = Math.min(150, Math.floor(1520 / Math.max(8, l2.length)));
  const size1 = Math.min(72, Math.floor(1300 / Math.max(10, l1.length)));
  return (
    <div style={{ position: "absolute", top: 170, left: 0, width: W, textAlign: "center", fontFamily: "InterBlack" }}>
      {l1 ? <div style={{ fontSize: size1, color: "#fff", transform: `scale(${interpolate(pop, [0, 1], [1.5, 1])})`, opacity: pop, ...strokeCss(14), textShadow: "0 8px 0 rgba(0,0,0,.5)" }}>{l1}</div> : null}
      <div style={{ marginTop: 4, display: "flex", justifyContent: "center", flexWrap: "wrap", gap: "0 26px", padding: "0 30px" }}>
        {words.map((w, i) => {
          const sp = spring({ frame: f - 3 - i * 3, fps: FPS, config: { damping: 8, stiffness: 200, mass: 0.6 } });
          return (
            <span key={i} style={{ display: "inline-block", fontSize: size, color, transform: `scale(${interpolate(sp, [0, 1], [2.2, 1])}) rotate(${interpolate(sp, [0, 1], [-8, 0])}deg)`, opacity: Math.min(1, sp * 2), ...strokeCss(18), textShadow: `0 10px 0 rgba(0,0,0,.55), 0 0 44px ${color}99` }}>
              {w}
            </span>
          );
        })}
      </div>
    </div>
  );
};

const Badge: React.FC<{ icon: string; label: string; color: string; f: number }> = ({ icon, label, color, f }) => {
  const sp = spring({ frame: f - 4, fps: FPS, config: { damping: 10, stiffness: 160 } });
  return (
    <div style={{ position: "absolute", left: 0, width: W, top: 1430, display: "flex", justifyContent: "center", transform: `translateY(${interpolate(sp, [0, 1], [220, 0])}px) scale(${1 + 0.04 * Math.sin(f / 3)})` }}>
      <div style={{ display: "flex", alignItems: "center", gap: 18, padding: "18px 40px", borderRadius: 60, background: "rgba(10,12,20,0.82)", border: `6px solid ${color}`, boxShadow: `0 0 50px ${color}aa`, fontFamily: "InterBlack", fontSize: 64, color }}>
        <span style={{ fontSize: 70 }}>{icon}</span>
        <span style={{ ...strokeCss(10) }}>{label}</span>
      </div>
    </div>
  );
};

const Rays: React.FC<{ t: number; strength: number; color: string }> = ({ t, strength, color }) => (
  <svg width={W} height={H} style={{ position: "absolute", inset: 0, mixBlendMode: "screen", opacity: strength }}>
    <g transform={`translate(${W / 2},${H / 2}) rotate(${t * 40})`}>
      {Array.from({ length: 26 }).map((_, k) => {
        const a = (k / 26) * Math.PI * 2;
        const r = 2000;
        const d = 0.055;
        return <polygon key={k} points={`0,0 ${Math.cos(a - d) * r},${Math.sin(a - d) * r} ${Math.cos(a + d) * r},${Math.sin(a + d) * r}`} fill={color} opacity={0.22} />;
      })}
    </g>
  </svg>
);

const SpeedLines: React.FC<{ seed: number; f: number }> = ({ seed, f }) => (
  <svg width={W} height={H} style={{ position: "absolute", inset: 0, opacity: 0.6, mixBlendMode: "screen" }}>
    {Array.from({ length: 34 }).map((_, k) => {
      const a = random(`${seed}-a-${k}-${Math.floor(f / 2)}`) * Math.PI * 2;
      const r0 = 520 + random(`${seed}-r-${k}`) * 260;
      const len = 380 + random(`${seed}-l-${k}-${f}`) * 600;
      return <line key={k} x1={W / 2 + Math.cos(a) * r0} y1={H / 2 + Math.sin(a) * r0} x2={W / 2 + Math.cos(a) * (r0 + len)} y2={H / 2 + Math.sin(a) * (r0 + len)} stroke="#fff" strokeWidth={3 + (k % 4)} strokeLinecap="round" />;
    })}
  </svg>
);

const EndCard: React.FC<{ f: number }> = ({ f }) => {
  const a = spring({ frame: f - 6, fps: FPS, config: { damping: 10, stiffness: 120 } });
  const b = spring({ frame: f - 18, fps: FPS, config: { damping: 9, stiffness: 160 } });
  const c = spring({ frame: f - 34, fps: FPS, config: { damping: 12 } });
  const pulse = 1 + 0.04 * Math.sin(f / 4);
  return (
    <AbsoluteFill style={{ fontFamily: "InterBlack", alignItems: "center", justifyContent: "center", textAlign: "center" }}>
      <AbsoluteFill style={{ background: `rgba(6,6,14,${interpolate(f, [0, 12], [0, 0.6], { extrapolateRight: "clamp" })})` }} />
      {Array.from({ length: 46 }).map((_, k) => {
        const x = random(`px${k}`) * W;
        const sp = 2 + random(`ps${k}`) * 5;
        const y = H - ((f * sp * 4 + random(`py${k}`) * H) % (H + 200));
        return <div key={k} style={{ position: "absolute", left: x, top: y, width: 9, height: 9, borderRadius: 5, background: k % 3 ? "#3EE8FF" : "#FFC93A", opacity: 0.75 * a }} />;
      })}
      <div style={{ transform: `translateY(${interpolate(a, [0, 1], [80, 0])}px)`, opacity: a, fontSize: 64, color: "#fff", ...strokeCss(12) }}>PLAY NOW ON ROBLOX</div>
      <div style={{ transform: `scale(${interpolate(b, [0, 1], [3, 1]) * pulse})`, opacity: Math.min(1, b * 2), fontSize: 180, lineHeight: 1.05, color: "#FFD640", ...strokeCss(22), textShadow: "0 14px 0 rgba(0,0,0,.5), 0 0 60px #FFB02088" }}>
        CAR<br />HUNTERS
      </div>
      <div style={{ marginTop: 26, opacity: c, transform: `translateY(${interpolate(c, [0, 1], [60, 0])}px)`, fontSize: 54, color: "#3EE8FF", ...strokeCss(10) }}>GET YOUR GEARS AT BIG TONY</div>
    </AbsoluteFill>
  );
};

const Segment: React.FC<{ seg: Seg; index: number }> = ({ seg, index }) => {
  const f = useCurrentFrame();
  const n = Math.round(seg.dur * FPS);
  const t = f / FPS;
  const u = ease(Math.min(1, f / Math.max(1, n - 1)));
  const fx = new Set(seg.fx || []);
  const src = staticFile(`${prefix}${String(index).padStart(2, "0")}.mp4`);
  const [c0, c1] = seg.cam;
  let cx = c0[0] + (c1[0] - c0[0]) * u;
  const cy = c0[1] + (c1[1] - c0[1]) * u;
  let z = c0[2] + (c1[2] - c0[2]) * u;
  const g = starts[index] + f;
  z *= 1 + 0.03 * Math.max(0, 1 - (g % 12) / 5); // 150 BPM beat bump
  if (fx.has("punch") && t < 0.3) z *= 1 + 0.35 * (1 - t / 0.3) ** 2;
  if (fx.has("build")) z *= 1 + 0.25 * u * u;
  let amp = 0;
  if (fx.has("shake")) amp = 10 * Math.exp(-t * 2.4);
  if (fx.has("build")) amp = Math.max(amp, 1 + 7 * u * u);
  const ox = amp ? (random(`sx${index}-${f}`) - 0.5) * 2 * amp : 0;
  const oy = amp ? (random(`sy${index}-${f}`) - 0.5) * 2 * amp : 0;
  const whip = fx.has("whip") && t < 0.15 ? 1 - t / 0.15 : 0;
  if (whip) cx += 0.06 * whip; // the whip slides the crop (clamped by place), never the layer
  const p = place(cx, cy, z, ox, oy);
  const chroma = fx.has("chroma") && t < 0.5 ? 1 - t / 0.5 : fx.has("glitch") ? 1 : 0;
  let filter = "contrast(1.1) saturate(1.25)";
  if (fx.has("glow")) filter = "contrast(1.12) saturate(1.55) brightness(1.06)";
  if (fx.has("build")) filter += ` brightness(${1 + 0.12 * u * u})`;
  if (whip) filter += ` blur(${whip * 14}px)`;
  const flash = fx.has("flash") && t < 0.22 ? 0.95 * (1 - t / 0.22) : 0;
  const ringT = fx.has("ring") ? t / 0.9 : 2;
  const rayColor = fx.has("blue") ? "#7FC4FF" : "#FFE08A";
  return (
    <AbsoluteFill style={{ background: "#07080d", overflow: "hidden" }}>
      <Footage src={src} p={p} filter={filter} />
      {chroma ? (
        <>
          <Footage src={src} p={p} dx={16 * chroma} filter="sepia(1) saturate(6) hue-rotate(-45deg)" style={{ mixBlendMode: "screen", opacity: 0.45 * chroma }} />
          <Footage src={src} p={p} dx={-16 * chroma} filter="sepia(1) saturate(6) hue-rotate(160deg)" style={{ mixBlendMode: "screen", opacity: 0.45 * chroma }} />
        </>
      ) : null}
      {fx.has("glitch")
        ? Array.from({ length: 8 }).map((_, k) => {
            const y0 = random(`gy${index}-${k}-${f}`) * 92;
            const hgt = 2 + random(`gh${index}-${k}-${f}`) * 7;
            const off = (random(`go${index}-${k}-${f}`) - 0.5) * 240;
            const pp = place(cx + off / (SRC_W * (H / SRC_H) * z), cy, z);
            return <Footage key={k} src={src} p={pp} clip={`inset(${y0}% 0 ${Math.max(0, 100 - y0 - hgt)}% 0)`} />;
          })
        : null}
      {fx.has("glow") ? <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 62%, rgba(110,240,140,0.16), rgba(0,0,0,0) 60%)", mixBlendMode: "screen" }} /> : null}
      {fx.has("rays") ? <Rays t={t} strength={Math.min(1, t / 0.2) * (n / FPS - t > 0.3 ? 1 : Math.max(0, (n / FPS - t) / 0.3))} color={rayColor} /> : null}
      {ringT < 1 ? (
        <div style={{ position: "absolute", left: W / 2 - (80 + ringT * 1400), top: H / 2 - (80 + ringT * 1400), width: 2 * (80 + ringT * 1400), height: 2 * (80 + ringT * 1400), borderRadius: "50%", border: `${Math.max(2, 34 * (1 - ringT))}px solid ${fx.has("blue") ? `rgba(130,200,255,${1 - ringT})` : `rgba(255,220,120,${1 - ringT})`}` }} />
      ) : null}
      {fx.has("speed") ? <SpeedLines seed={index} f={f} /> : null}
      {fx.has("pulse") ? <AbsoluteFill style={{ boxShadow: `inset 0 0 ${180 + 120 * Math.sin(f / 2.5)}px rgba(255,255,255,0.32)` }} /> : null}
      {fx.has("blue") ? <AbsoluteFill style={{ boxShadow: `inset 0 0 300px rgba(80,160,255,${0.35 + 0.2 * Math.sin(f / 3)})` }} /> : null}
      {/* vignette + caption band */}
      <AbsoluteFill style={{ boxShadow: "inset 0 0 220px rgba(0,0,0,0.6)" }} />
      {seg.caps && seg.caps.length ? <div style={{ position: "absolute", left: 0, top: 0, width: W, height: 620, background: "linear-gradient(rgba(0,0,0,0.72), rgba(0,0,0,0.45) 55%, rgba(0,0,0,0))" }} /> : null}
      {(seg.caps || []).map(([a0, a1, l1, l2, col], k) => (t >= a0 && t < a1 ? <Caption key={k} l1={l1} l2={l2} color={COLORS[col] || col} t={t - a0} /> : null))}
      {seg.badge ? <Badge icon={seg.badge[0]} label={seg.badge[1]} color={seg.badge[2]} f={f} /> : null}
      {fx.has("end") ? <EndCard f={f} /> : null}
      {flash ? <AbsoluteFill style={{ background: "#fff", opacity: flash }} /> : null}
    </AbsoluteFill>
  );
};

export const Edit5: React.FC = () => (
  <AbsoluteFill style={{ background: "#07080d" }}>
    <style>{fontFace}</style>
    {segs.map((s, i) => (
      <Sequence key={i} from={starts[i]} durationInFrames={Math.round(s.dur * FPS)}>
        <Segment seg={s} index={i} />
      </Sequence>
    ))}
  </AbsoluteFill>
);
