import { useEffect, useRef, useState } from "preact/hooks";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { getAccessToken } from "../lib/auth";

// The app UI resource served by the MCP server (§6d).
const APP_URI = "ui://unoverse/app.html";

/**
 * The SAB client as an MCP-Apps HOST (§6d): it reads the `ui://` app resource — the bundled
 * SDK+boot HTML — over STANDARD MCP and renders it in a sandboxed iframe, exactly what Claude
 * does. The host embeds NO Unoverse SDK; the SDK arrives inside the streamed app, which opens
 * its own /mcp + /stream in the iframe. The host only hands it config (where + which app + who).
 */
async function readAppHtml(serverUrl) {
  const client = new Client({ name: "unoverse-demo-host", version: "0.1.0" });
  // Inject the bearer on every underlying request (fresh per call → refresh-safe).
  const authFetch = async (url, init) => {
    const token = await getAccessToken();
    const headers = new Headers(init?.headers);
    if (token) headers.set("Authorization", `Bearer ${token}`);
    return fetch(url, { ...init, headers });
  };
  const transport = new StreamableHTTPClientTransport(new URL(`${serverUrl}/mcp`), { fetch: authFetch });
  await client.connect(transport);
  try {
    const res = await client.readResource({ uri: APP_URI });
    return res?.contents?.[0]?.text;
  } finally {
    // One-shot read: the host needs nothing further from MCP — the app opens its own planes.
    client.close().catch(() => {});
  }
}

export function AppHost({ serverUrl, apiUrl, templateId, token, userId, conversationId, onSize }) {
  const ref = useRef(null);
  const [html, setHtml] = useState(null);
  const [error, setError] = useState(null);

  const appConfig = { serverUrl, apiUrl, templateId, token, userId, conversationId };

  useEffect(() => {
    let alive = true;
    readAppHtml(serverUrl)
      .then((text) => {
        if (alive) typeof text === "string" && text ? setHtml(text) : setError("app resource returned no HTML");
      })
      .catch((err) => alive && setError(String(err?.message ?? err)));
    return () => {
      alive = false;
    };
  }, [serverUrl]);

  // Re-send config on change (token refresh); onLoad sends the first copy.
  useEffect(() => {
    ref.current?.contentWindow?.postMessage({ type: "unoverse:config", config: appConfig }, "*");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [serverUrl, templateId, token, userId, conversationId]);

  // The APP owns its width (manifest `width`) — it posts `unoverse:size` up; we hand it to the
  // panel so the slide-out sizes to the app. Only accept it from THIS iframe's window.
  useEffect(() => {
    const onMessage = (e) => {
      if (e.source !== ref.current?.contentWindow) return;
      if (e.data?.type === "unoverse:size" && e.data.width) onSize?.(e.data.width);
    };
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [onSize]);

  if (error) return <div className="flex h-full items-center justify-center p-4 text-center text-sm text-red-400">app failed to load: {error}</div>;
  if (!html) return <div className="flex h-full items-center justify-center text-sm text-gray-400">Loading app…</div>;

  return (
    <iframe
      ref={ref}
      srcDoc={html}
      onLoad={(e) => e.currentTarget.contentWindow?.postMessage({ type: "unoverse:config", config: appConfig }, "*")}
      sandbox="allow-scripts allow-same-origin allow-forms allow-modals allow-popups allow-popups-to-escape-sandbox"
      style={{ width: "100%", height: "100%", border: "none", display: "block" }}
    />
  );
}
