import { defineConfig, loadEnv } from "vite";
import preact from "@preact/preset-vite";
import tailwindcss from "@tailwindcss/vite";
import cssInjectedByJs from "vite-plugin-css-injected-by-js";
import { resolve } from "path";

// This host embeds NO Unoverse SDK (the app streams in via the server's ui:// resource,
// SDK included). The react→preact/compat aliases exist only for react-oidc-context
// (authored for React); runtime deps are just preact + oidc + the standard MCP client.
//
// TWO build targets, selected by BUILD_TARGET:
//   (default)        → the hostable SITE: index.html + hashed assets, served statically
//                      (this is what deploys — landing `/`, `/sab`, `/bpp`).
//   BUILD_TARGET=widget → the embeddable IIFE: a self-mounting unoverse-demo.js (no index.html)
//                      to drop into a real host page via <script src>. (`npm run build:widget`)
const isWidget = process.env.BUILD_TARGET === "widget";

export default defineConfig(({ mode }) => {
  // OIDC config derives from the monorepo root .env (AUTH_* — the same values every
  // app uses), so the client never carries its own copy. A standalone checkout can
  // still set VITE_AUTH_* directly; explicit VITE_ values win.
  const rootEnv = loadEnv(mode, resolve(__dirname, "../.."), "");
  return {
  define: {
    "import.meta.env.VITE_AUTH_ISSUER": JSON.stringify(process.env.VITE_AUTH_ISSUER || rootEnv.VITE_AUTH_ISSUER || rootEnv.AUTH_ISSUER || ""),
    "import.meta.env.VITE_AUTH_CLIENT_ID": JSON.stringify(process.env.VITE_AUTH_CLIENT_ID || rootEnv.VITE_AUTH_CLIENT_ID || rootEnv.AUTH_CLIENT_ID || ""),
    "import.meta.env.VITE_AUTH_AUDIENCE": JSON.stringify(process.env.VITE_AUTH_AUDIENCE || rootEnv.VITE_AUTH_AUDIENCE || rootEnv.AUTH_AUDIENCE || "gravity-api"),
  },
  // The widget is ONE FILE. Vite's library mode extracts CSS to a sibling .css whatever
  // `cssCodeSplit` says, so the embed would be two tags and the easy one to forget is the
  // one that makes the drawer look right. This injects the stylesheet from the JS at
  // runtime, so `<script src="unoverse-demo.js">` is the whole install. The SITE target
  // keeps a real stylesheet — a page that serves its own HTML should not paint after JS.
  plugins: [preact(), tailwindcss(), ...(isWidget ? [cssInjectedByJs()] : [])],
  // The widget target writes INTO public/, so the public-directory feature must be off for
  // it: with both pointing at the same folder Vite would try to copy public/ into itself.
  ...(isWidget ? { publicDir: false } : {}),
  resolve: {
    alias: [
      { find: /^react$/, replacement: "preact/compat" },
      { find: /^react-dom$/, replacement: "preact/compat" },
      { find: /^react\/jsx-runtime$/, replacement: "preact/jsx-runtime" },
      // AppHost names CfWorkerJsonSchemaValidator at every `new Client()`, so the SDK's
      // default Ajv provider is never constructed — alias the real Ajv (which compiles
      // schemas with `new Function`) to an inert stub so no eval reaches a customer page.
      // Exact regex so `ajv-formats` isn't swallowed by the `ajv` rule.
      { find: /^ajv$/, replacement: resolve(__dirname, "ajv-stub.js") },
      { find: /^ajv-formats$/, replacement: resolve(__dirname, "ajv-stub.js") },
    ],
    dedupe: ["preact"],
  },
  // Widget target: a self-mounting IIFE (no hashes), embeddable via <script src>. Emits
  // unoverse-demo.js + unoverse-demo.css. Site target: a normal Vite build off index.html.
  build: isWidget
    ? {
        lib: {
          // The EMBED entry — reads `data-app` off its own <script> tag. The demo site's
          // entry (src/demo/main.jsx) is a different thing and routes on the URL path.
          entry: "src/embed/widget.jsx",
          name: "UnoverseDemo",
          formats: ["iife"],
          fileName: () => "unoverse-demo.js",
        },
        // Output into public/ so ONE copy serves both worlds: `npm run dev` serves it at
        // /unoverse-demo.js, and `npm run build` copies public/ into dist automatically.
        // emptyOutDir:false because public/ also holds the favicon.
        outDir: "public",
        emptyOutDir: false,
        cssCodeSplit: false,
        rollupOptions: {
          output: {
            inlineDynamicImports: true,
            assetFileNames: "unoverse-demo.[ext]",
          },
        },
      }
    : {
        // Site build: MULTI-PAGE. index.html is the grid (Preact); every other entry is a
        // pretend customer page that loads the built widget through a <script> tag, which is
        // the only way the real embed path (data-app, currentScript, injected CSS, IIFE) gets
        // exercised by anything. They carry no JS of their own.
        outDir: "dist",
        rollupOptions: {
          input: Object.fromEntries(
            ["index", "sab", "bpp", "yas", "yasvoice", "emirates"].map((n) => [
              n,
              resolve(__dirname, `${n}.html`),
            ]),
          ),
        },
      },
  server: {
    port: 3007,
    // Fail rather than drift (same rule as Studio's config): a tool that answers on a
    // different port than it printed is worse than one that refuses to start.
    strictPort: true,
    host: "0.0.0.0",
  },
  };
});
