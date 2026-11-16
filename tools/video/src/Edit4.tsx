// TikTok #4 "I risked everything for a LEGENDARY" - Remotion composition, 1080x1920, 30 fps.
// Segments come from edit4.json (pre-cut by cut.py into public/sNN.mp4). Each segment: the 16:9 game footage in a big
// window over a blurred copy, an animated camera (cx, cy, zoom), effects (flash, whip, glitch, chroma, shake, rays, ring,
// build-up, gold glow) and kinetic captions. 150 BPM grid: a small zoom bump every 12 frames.
import React from "react";
import { AbsoluteFill, Easing, OffthreadVideo, Sequence, interpolate, random, spring, staticFile, useCurrentFrame } from "remotion";
import cfg from "./edit4.json";

const FPS = 30;
const W = 1080;
const WIN_H = 1100;
const WIN_Y = 410;
const SRC_W = 1280;
const SRC_H = 576;

type Seg = { clip: string; src: number[]; dur: number; cam: number[][]; fx?: string[]; caps?: any[][]; freeze?: boolean };
const segs: Seg[] = (cfg as any).segments;
const starts: number[] = [];
let acc = 0;
for (const s of segs) {
  starts.push(acc);
  acc += Math.round(s.dur * FPS);
}
export const totalFrames = acc;

const COLORS: Record<string, string> = {
  gold: "#FFC93A", yellow: "#FFD640", red: "#FF4D5E", cyan: "#3EE8FF", white: "#FFFFFF", grey: "#BFC4CE", green: "#6DF08C",
};

const fontFace = `@font-face { font-family: 'InterBlack'; src: url('${staticFile("Inter-Black.otf")}'); }`;

const ease = (u: number) => u * u * (3 - 2 * u);

// where the footage sits inside the window for a camera (cx, cy, zoom)
function place(cam: number[]) {
  const [cx, cy, z] = cam;
  const s = (WIN_H / SRC_H) * z;
  const vw = SRC_W * s;
  const vh = SRC_H * s;
  const left = Math.min(0, Math.max(W - vw, W / 2 - cx * vw));
  const top = Math.min(0, Math.max(WIN_H - vh, WIN_H / 2 - cy * vh));
  return { left, top, vw, vh };
}

const Footage: React.FC<{ src: string; cam: number[]; style?: React.CSSProperties; dx?: number; filter?: string; clip?: string }> = ({ src, cam, style, dx = 0, filter, clip }) => {
  const p = place(cam);
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", clipPath: clip, ...style }}>
      <OffthreadVideo src={src} muted style={{ position: "absolute", left: p.left + dx, top: p.top, width: p.vw, height: p.vh, filter }} />
    </div>
  );
};

const Caption: React.FC<{ l1: string; l2: string; color: string; t: number }> = ({ l1, l2, color, t }) => {
  const f = Math.round(t * FPS);
  const pop = spring({ frame: f, fps: FPS, config: { damping: 9, stiffness: 180, mass: 0.6 } });
  const scale1 = interpolate(pop, [0, 1], [1.5, 1]);
  const words = l2.split(" ");
  const stroke = (px: number): React.CSSProperties => ({ WebkitTextStroke: `${px}px #10121a`, paintOrder: "stroke fill" as any });
  return (
    <div style={{ position: "absolute", top: 150, left: 0, width: W, textAlign: "center", fontFamily: "InterBlack" }}>
      {l1 ? (
        <div style={{ fontSize: 68, color: "#fff", transform: `scale(${scale1})`, opacity: pop, ...stroke(14), textShadow: "0 8px 0 rgba(0,0,0,.45)", letterSpacing: 1 }}>{l1}</div>
      ) : null}
      <div style={{ marginTop: 4, display: "flex", justifyContent: "center", flexWrap: "wrap", gap: "0 26px", padding: "0 30px" }}>
        {words.map((w, i) => {
          const sp = spring({ frame: f - 3 - i * 3, fps: FPS, config: { damping: 8, stiffness: 200, mass: 0.6 } });
          const size = Math.min(140, Math.floor(1500 / Math.max(8, l2.length)));
          return (
            <span key={i} style={{ display: "inline-block", fontSize: size, color, transform: `scale(${interpolate(sp, [0, 1], [2.2, 1])}) rotate(${interpolate(sp, [0, 1], [-8, 0])}deg)`, opacity: Math.min(1, sp * 2), ...stroke(18), textShadow: `0 10px 0 rgba(0,0,0,.5), 0 0 40px ${color}88` }}>
              {w}
            </span>
          );
        })}
      </div>
    </div>
  );
};

const Rays: React.FC<{ t: number; strength: number; color: string }> = ({ t, strength, color }) => (
  <svg width={W} height={1920} style={{ position: "absolute", inset: 0, mixBlendMode: "screen", opacity: strength }}>
    <g transform={`translate(${W / 2},${WIN_Y + WIN_H / 2}) rotate(${t * 40})`}>
      {Array.from({ length: 24 }).map((_, k) => {
        const a = (k / 24) * Math.PI * 2;
        const r = 1500;
        const d = 0.06;
        return <polygon key={k} points={`0,0 ${Math.cos(a - d) * r},${Math.sin(a - d) * r} ${Math.cos(a + d) * r},${Math.sin(a + d) * r}`} fill={color} opacity={0.22} />;
      })}
    </g>
  </svg>
);

const SpeedLines: React.FC<{ seed: number; f: number }> = ({ seed, f }) => (
  <svg width={W} height={1920} style={{ position: "absolute", inset: 0, opacity: 0.55, mixBlendMode: "screen" }}>
    {Array.from({ length: 26 }).map((_, k) => {
      const a = random(`${seed}-a-${k}-${Math.floor(f / 2)}`) * Math.PI * 2;
      const r0 = 420 + random(`${seed}-r-${k}`) * 200;
      const len = 300 + random(`${seed}-l-${k}-${f}`) * 500;
      const cx = W / 2, cy = WIN_Y + WIN_H / 2;
      return <line key={k} x1={cx + Math.cos(a) * r0} y1={cy + Math.sin(a) * r0} x2={cx + Math.cos(a) * (r0 + len)} y2={cy + Math.sin(a) * (r0 + len)} stroke="#fff" strokeWidth={3 + (k % 3)} strokeLinecap="round" />;
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
      <AbsoluteFill style={{ background: `rgba(6,6,14,${interpolate(f, [0, 12], [0, 0.62], { extrapolateRight: "clamp" })})` }} />
      {Array.from({ length: 40 }).map((_, k) => {
        const x = random(`px${k}`) * W;
        const sp = 2 + random(`ps${k}`) * 5;
        const y = 1920 - ((f * sp * 4 + random(`py${k}`) * 1920) % 2100);
        return <div key={k} style={{ position: "absolute", left: x, top: y, width: 8, height: 8, borderRadius: 4, background: k % 3 ? "#FFC93A" : "#fff", opacity: 0.7 * a }} />;
      })}
      <div style={{ transform: `translateY(${interpolate(a, [0, 1], [80, 0])}px)`, opacity: a, fontSize: 64, color: "#fff", WebkitTextStroke: "12px #10121a", paintOrder: "stroke fill" as any }}>PLAY NOW ON ROBLOX</div>
      <div style={{ transform: `scale(${interpolate(b, [0, 1], [3, 1]) * pulse})`, opacity: Math.min(1, b * 2), fontSize: 170, lineHeight: 1.05, color: "#FFD640", WebkitTextStroke: "22px #10121a", paintOrder: "stroke fill" as any, textShadow: "0 14px 0 rgba(0,0,0,.5), 0 0 60px #FFB02088" }}>
        CAR<br />HUNTERS
      </div>
      <div style={{ marginTop: 26, opacity: c, transform: `translateY(${interpolate(c, [0, 1], [60, 0])}px)`, fontSize: 52, color: "#6DF08C", WebkitTextStroke: "10px #10121a", paintOrder: "stroke fill" as any }}>
        CATCH YOUR DREAM CAR
      </div>
    </AbsoluteFill>
  );
};

const Segment: React.FC<{ seg: Seg; index: number }> = ({ seg, index }) => {
  const f = useCurrentFrame();
  const n = Math.round(seg.dur * FPS);
  const t = f / FPS;
  const u = ease(Math.min(1, f / Math.max(1, n - 1)));
  const fx = new Set(seg.fx || []);
  const src = staticFile(`s${String(index).padStart(2, "0")}.mp4`);
  const [c0, c1] = seg.cam;
  const cam = [0, 1, 2].map((k) => c0[k] + (c1[k] - c0[k]) * u);
  // beat bump every 12 frames (150 BPM) on the global timeline
  const g = starts[index] + f;
  cam[2] *= 1 + 0.025 * Math.max(0, 1 - (g % 12) / 5);
  if (fx.has("punch") && t < 0.3) cam[2] *= 1 + 0.3 * (1 - t / 0.3) ** 2;
  if (fx.has("build")) cam[2] *= 1 + 0.22 * u * u;
  let amp = 0;
  if (fx.has("shake")) amp = 30 * Math.exp(-t * 2.4);
  if (fx.has("build")) amp = Math.max(amp, 3 + 20 * u * u);
  const sx = amp ? (random(`sx${index}-${f}`) - 0.5) * 2 * amp : 0;
  const sy = amp ? (random(`sy${index}-${f}`) - 0.5) * 2 * amp : 0;
  const whip = fx.has("whip") && t < 0.15 ? 1 - t / 0.15 : 0;
  const chroma = fx.has("chroma") && t < 0.5 ? 1 - t / 0.5 : fx.has("glitch") ? 1 : 0;
  let filter = "contrast(1.08) saturate(1.2)";
  if (fx.has("desat")) filter = "grayscale(0.8) brightness(0.8) contrast(1.15)";
  if (fx.has("build")) filter += ` brightness(${1 + 0.45 * u * u})`;
  if (whip) filter += ` blur(${whip * 18}px)`;
  const flash = fx.has("flash") && t < 0.22 ? 0.95 * (1 - t / 0.22) : 0;
  const winStyle: React.CSSProperties = { position: "absolute", left: sx, top: WIN_Y + sy, width: W, height: WIN_H, overflow: "hidden", transform: `translateX(${whip * 160}px)` };
  const goldPulse = fx.has("gold") ? 0.35 + 0.25 * Math.sin(f / 3) : 0;
  const ringT = fx.has("ring") ? t / 0.9 : 2;
  return (
    <AbsoluteFill style={{ background: "#07080d" }}>
      {/* blurred backdrop */}
      <div style={{ position: "absolute", inset: -60, overflow: "hidden" }}>
        <OffthreadVideo src={src} muted style={{ position: "absolute", height: "100%", left: "50%", transform: "translateX(-50%) scale(1.25)", filter: "blur(30px) brightness(0.42) saturate(1.4)" }} />
      </div>
      {/* game window */}
      <div style={winStyle}>
        <Footage src={src} cam={cam} filter={filter} />
        {chroma ? (
          <>
            <Footage src={src} cam={cam} dx={18 * chroma} filter="sepia(1) saturate(6) hue-rotate(-45deg)" style={{ mixBlendMode: "screen", opacity: 0.45 * chroma }} />
            <Footage src={src} cam={cam} dx={-18 * chroma} filter="sepia(1) saturate(6) hue-rotate(160deg)" style={{ mixBlendMode: "screen", opacity: 0.45 * chroma }} />
          </>
        ) : null}
        {fx.has("glitch")
          ? Array.from({ length: 7 }).map((_, k) => {
              const y0 = random(`gy${index}-${k}-${f}`) * 90;
              const hgt = 3 + random(`gh${index}-${k}-${f}`) * 9;
              const off = (random(`go${index}-${k}-${f}`) - 0.5) * 260;
              return <Footage key={k} src={src} cam={cam} dx={off} clip={`inset(${y0}% 0 ${Math.max(0, 100 - y0 - hgt)}% 0)`} />;
            })
          : null}
        {fx.has("pulse") ? <AbsoluteFill style={{ boxShadow: `inset 0 0 ${120 + 80 * Math.sin(f / 2.5)}px rgba(255,255,255,0.35)` }} /> : null}
        <AbsoluteFill style={{ boxShadow: "inset 0 0 160px rgba(0,0,0,0.55)" }} />
      </div>
      {/* window frame */}
      <div style={{ position: "absolute", left: 0, top: WIN_Y - 6, width: W, height: 6, background: "linear-gradient(90deg,#FFD640,#FF4D5E,#3EE8FF)" }} />
      <div style={{ position: "absolute", left: 0, top: WIN_Y + WIN_H, width: W, height: 6, background: "linear-gradient(90deg,#3EE8FF,#FF4D5E,#FFD640)" }} />
      {fx.has("rays") ? <Rays t={t} strength={Math.min(1, t / 0.2) * (n / FPS - t > 0.3 ? 1 : (n / FPS - t) / 0.3)} color={fx.has("gold") ? "#FFC93A" : "#FFE7A0"} /> : null}
      {ringT < 1 ? (
        <div style={{ position: "absolute", left: W / 2 - (80 + ringT * 1200), top: WIN_Y + WIN_H / 2 - (80 + ringT * 1200), width: 2 * (80 + ringT * 1200), height: 2 * (80 + ringT * 1200), borderRadius: "50%", border: `${Math.max(2, 30 * (1 - ringT))}px solid rgba(255,220,120,${1 - ringT})` }} />
      ) : null}
      {fx.has("speed") ? <SpeedLines seed={index} f={f} /> : null}
      {goldPulse ? <AbsoluteFill style={{ boxShadow: `inset 0 0 260px rgba(255,190,40,${goldPulse})` }} /> : null}
      {(seg.caps || []).map(([a0, a1, l1, l2, col], k) => (t >= a0 && t < a1 ? <Caption key={k} l1={l1} l2={l2} color={COLORS[col] || col} t={t - a0} /> : null))}
      {fx.has("end") ? <EndCard f={f} /> : null}
      {flash ? <AbsoluteFill style={{ background: "#fff", opacity: flash }} /> : null}
    </AbsoluteFill>
  );
};

export const Edit4: React.FC = () => (
  <AbsoluteFill style={{ background: "#07080d" }}>
    <style>{fontFace}</style>
    {segs.map((s, i) => (
      <Sequence key={i} from={starts[i]} durationInFrames={Math.round(s.dur * FPS)}>
        <Segment seg={s} index={i} />
      </Sequence>
    ))}
  </AbsoluteFill>
);
