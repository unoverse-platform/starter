import { defineConfig, loadEnv } from "vite";
import preact from "@preact/preset-vite";
import tailwindcss from "@tailwindcss/vite";
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
  plugins: [preact(), tailwindcss()],
  resolve: {
    alias: {
      react: "preact/compat",
      "react-dom": "preact/compat",
      "react/jsx-runtime": "preact/jsx-runtime",
    },
    dedupe: ["preact"],
  },
  // Widget target: a self-mounting IIFE (no hashes), embeddable via <script src>. Emits
  // unoverse-demo.js + unoverse-demo.css. Site target: a normal Vite build off index.html.
  build: isWidget
    ? {
        lib: {
          entry: "src/main.jsx",
          name: "UnoverseDemo",
          formats: ["iife"],
          fileName: () => "unoverse-demo.js",
        },
        cssCodeSplit: false,
        rollupOptions: {
          output: {
            inlineDynamicImports: true,
            assetFileNames: "unoverse-demo.[ext]",
          },
        },
      }
    : {
        // Site build: index.html is the entry; Vite injects the hashed JS/CSS.
        outDir: "dist",
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
