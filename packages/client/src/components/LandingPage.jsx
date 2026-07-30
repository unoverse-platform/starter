import { useEffect, useRef, useState } from "preact/hooks";
import { useAuth } from "react-oidc-context";
import { config, clients } from "../lib/config";
import { hasAuth } from "../lib/auth";
import { UnoverseMark } from "./Logo";

// Per-channel card art: a rich hero image + an accent (glow tint). Keyed by registry key;
// anything unlisted falls back to the brand violet with no image.
const CARD_ART = {
  sab: {
    accent: "167,139,250", // violet
    image: "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=900&q=80", // city at dusk
  },
  bpp: {
    accent: "34,211,238", // cyan
    image: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=900&q=80", // corporate towers
  },
  yas: {
    accent: "52,211,153", // emerald
    image: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80", // island shoreline
  },
  yasvoice: {
    accent: "251,191,36", // amber — the voice sibling
    image: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=900&q=80", // concert / live sound
  },
  emirates: {
    accent: "248,113,113", // red
    image: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80", // wing above clouds
  },
};
const FALLBACK_ART = { accent: "167,139,250", image: null };

/**
 * The Unoverse landing page (`/`) — the hub. Sits behind the SAME login gate as the channel
 * demos (auth is a channel concern; the server's /health says whether it's enforced), and once
 * signed in shows one card per registered client — the way into every POC demo (`/sab`, `/bpp`,
 * `/yas`, `/emirates`). Every state (gate included) sits on the cinematic video backdrop.
 */
export function LandingPage() {
  // Login gate — same contract as ClientDemo: ask the server whether it enforces auth
  // (/health → authRequired); fail safe to "secured" if the server is unreachable.
  const auth = useAuth();
  const [authRequired, setAuthRequired] = useState(null);
  useEffect(() => {
    fetch(`${config.serverUrl}/health`)
      .then((r) => r.json())
      .then((d) => setAuthRequired(!!d.authRequired))
      .catch(() => setAuthRequired(true));
  }, []);
  const signedIn = !!auth?.isAuthenticated;
  const needsLogin = authRequired === true && !signedIn;

  if (authRequired === null || (hasAuth && auth?.isLoading)) {
    return (
      <Backdrop>
        <div className="relative text-sm text-white/60">Loading…</div>
      </Backdrop>
    );
  }
  if (needsLogin && hasAuth) {
    return (
      <Backdrop>
        <SignInCard onLogin={() => auth?.signinRedirect()} />
      </Backdrop>
    );
  }
  if (needsLogin && !hasAuth) {
    return (
      <Backdrop>
        <div className="uv-rise relative flex max-w-sm flex-col items-center gap-3 rounded-2xl border border-white/10 bg-white/5 p-8 text-center backdrop-blur-md">
          <div className="text-sm font-semibold text-white/85">This server requires authentication</div>
          <div className="text-xs leading-relaxed text-white/50">
            Configure OIDC (VITE_AUTH_ISSUER / VITE_AUTH_CLIENT_ID) to sign in, or set{" "}
            <code className="text-white/70">DISABLE_AUTH=true</code> in the server .env for anonymous local dev.
          </div>
        </div>
      </Backdrop>
    );
  }

  return <Hub />;
}

/**
 * The cinematic brand backdrop every landing state sits on: full-bleed muted video loop
 * under a dark wash, corner glows, and a vignette. Children render centered above it.
 */
function Backdrop({ children }) {
  // Force muted autoplay from JS. The `muted` ATTRIBUTE doesn't always reflect to the DOM
  // PROPERTY across frameworks, and browsers only allow autoplay when the property is true —
  // so set it explicitly and kick off play() (ignore the promise rejection if the tab is
  // backgrounded; it'll start on the next visibility change).
  const videoRef = useRef(null);
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    v.muted = true;
    v.play().catch(() => {});
  }, []);

  return (
    <div className="fixed inset-0 overflow-y-auto bg-black">
      {/* Full-screen muted video loop. A NATIVE <video> (not a YouTube iframe): the HTML spec
          guarantees muted autoplay, and it renders NO player chrome — no play/pause button ever,
          because there's no `controls` attribute. */}
      <div className="fixed inset-0 overflow-hidden">
        <video
          ref={videoRef}
          autoPlay
          muted
          loop
          playsInline
          preload="auto"
          className="pointer-events-none absolute left-1/2 top-1/2 h-full w-full min-h-full min-w-full -translate-x-1/2 -translate-y-1/2 object-cover"
          src="https://videos.pexels.com/video-files/3141210/3141210-uhd_3840_2160_25fps.mp4"
        />
        {/* Cinematic wash — darken the footage, then bleed brand glows in from the corners. */}
        <div className="absolute inset-0 bg-black/55" />
        <div
          className="absolute inset-0"
          style={{
            background:
              "radial-gradient(70rem 50rem at 80% -10%, rgba(167,139,250,0.28), transparent 55%)," +
              "radial-gradient(60rem 50rem at 5% 115%, rgba(34,211,238,0.22), transparent 55%)",
          }}
        />
        {/* subtle vignette */}
        <div
          className="absolute inset-0"
          style={{ background: "radial-gradient(120% 120% at 50% 50%, transparent 55%, rgba(0,0,0,0.7) 100%)" }}
        />
      </div>

      <div className="relative flex min-h-full flex-col items-center justify-center px-6 py-16">{children}</div>

      {/* local keyframes — entrance rise + a slow float on the mark */}
      <style>{`
        @keyframes uv-rise { from { opacity: 0; transform: translateY(18px); } to { opacity: 1; transform: none; } }
        .uv-rise { animation: uv-rise 1s cubic-bezier(0.22, 1, 0.36, 1) both; }
        @keyframes uv-float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-8px); } }
        .uv-float { animation: uv-float 6s ease-in-out infinite; }
      `}</style>
    </div>
  );
}

/** The Unoverse-branded login gate for the hub — a glass card over the video backdrop. */
function SignInCard({ onLogin }) {
  return (
    <div className="uv-rise relative flex w-full max-w-sm flex-col items-center rounded-2xl border border-white/10 bg-white/5 p-9 text-center backdrop-blur-md">
      {/* logomark with a soft halo */}
      <div className="relative mb-6">
        <div
          className="absolute -inset-6 rounded-full blur-2xl"
          style={{ background: "radial-gradient(circle, rgba(139,92,246,0.5), transparent 70%)" }}
        />
        <UnoverseMark size={56} className="relative drop-shadow-[0_0_24px_rgba(34,211,238,0.35)]" />
      </div>

      <h1 className="text-2xl font-semibold lowercase tracking-tight text-white">unoverse</h1>
      <p className="mb-8 mt-1 text-sm text-white/50">Sign in to continue</p>

      <button
        onClick={onLogin}
        className="flex w-full items-center justify-center gap-2 rounded-xl bg-white py-3 font-medium text-black transition-colors hover:bg-white/85"
      >
        <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
          />
        </svg>
        Sign In
      </button>

      <p className="mt-6 text-xs text-white/35">Secured by Auth0</p>
    </div>
  );
}

/** The signed-in hub: brand splash + one card per registered demo channel. */
function Hub() {
  return (
    <Backdrop>
      <div className="uv-rise relative flex flex-col items-center text-center">
        {/* logomark with a soft halo */}
        <div className="relative mb-6">
          <div
            className="absolute -inset-8 rounded-full blur-2xl"
            style={{ background: "radial-gradient(circle, rgba(139,92,246,0.55), transparent 70%)" }}
          />
          <UnoverseMark size={84} className="relative uv-float drop-shadow-[0_0_30px_rgba(34,211,238,0.35)]" />
        </div>

        {/* wordmark */}
        <h1 className="text-5xl font-semibold lowercase tracking-tight text-white sm:text-6xl">unoverse</h1>

        {/* tagline */}
        <p className="mt-4 max-w-xl bg-gradient-to-b from-white to-white/55 bg-clip-text text-xl font-medium leading-snug text-transparent sm:text-2xl">
          The experience layer for AI
        </p>

        {/* Demo cards — one per registered client; each is a full page load into that channel. */}
        <div className="mt-12 grid w-full max-w-5xl grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {Object.entries(clients).map(([key, client]) => (
            <DemoCard key={key} href={`/${key}`} client={client} art={CARD_ART[key] || FALLBACK_ART} />
          ))}
        </div>

        {/* footer */}
        <p className="mt-14 text-center text-xs tracking-wide text-white/35">One engine, many hosts.</p>
      </div>
    </Backdrop>
  );
}

/**
 * One channel card: a rich hero image under a glass scrim, the Unoverse mark in a glowing
 * tile, and the label/tagline sitting on a dark gradient so they stay readable while the
 * card keeps its translucent, see-through feel at the edges.
 */
function DemoCard({ href, client, art }) {
  const { accent, image } = art;
  return (
    <a
      href={href}
      className="group relative flex aspect-[3/4] flex-col overflow-hidden rounded-2xl border border-white/15 bg-white/5 p-5 text-left shadow-[0_8px_40px_rgba(0,0,0,0.35)] backdrop-blur-md transition-all duration-300 hover:-translate-y-1.5 hover:border-white/35 hover:shadow-[0_16px_60px_rgba(0,0,0,0.5)]"
    >
      {/* hero image — slightly translucent so the video still breathes through, zooms on hover */}
      {image && (
        <img
          src={image}
          alt=""
          loading="lazy"
          className="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-75 transition-all duration-500 group-hover:scale-105 group-hover:opacity-90"
        />
      )}
      {/* readability scrim — dark gradient anchored to the bottom where the text lives */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/30 via-black/15 to-black/85" />
      {/* accent glow, revealed on hover */}
      <div
        className="pointer-events-none absolute inset-0 opacity-40 transition-opacity duration-300 group-hover:opacity-100"
        style={{ background: `radial-gradient(16rem 12rem at 50% -20%, rgba(${accent},0.3), transparent 70%)` }}
      />

      {/* Unoverse mark in a glowing glass tile */}
      <div className="relative">
        <div
          className="flex h-11 w-11 items-center justify-center rounded-xl border border-white/20 bg-black/40 backdrop-blur-sm"
          style={{ boxShadow: `0 0 22px rgba(${accent},0.45)` }}
        >
          <UnoverseMark size={24} />
        </div>
      </div>

      <div className="relative mt-auto">
        <div className="text-lg font-semibold text-white drop-shadow-[0_1px_6px_rgba(0,0,0,0.8)]">{client.label}</div>
        <div className="mt-1 text-xs leading-relaxed text-white/75 drop-shadow-[0_1px_4px_rgba(0,0,0,0.8)]">
          {client.tagline}
        </div>
        <div
          className="mt-3 flex items-center gap-1 text-xs font-semibold transition-colors"
          style={{ color: `rgb(${accent})` }}
        >
          Open demo
          <svg className="h-3.5 w-3.5 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12l-7.5 7.5M21 12H3" />
          </svg>
        </div>
      </div>
    </a>
  );
}
