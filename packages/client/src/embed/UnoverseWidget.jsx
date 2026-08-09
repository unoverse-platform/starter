import { useEffect, useMemo, useState } from "preact/hooks";
import { useAuth } from "react-oidc-context";
import { config } from "./config";
import { hasAuth, setAccessTokenFn } from "./auth";
import { LoginScreen } from "./LoginScreen";
import { SlidingPanel } from "./SlidingPanel";
import { getConversationId, getGuestId } from "./session";
import { AppHost } from "./AppHost";

/**
 * THE EMBEDDABLE CLIENT — everything that runs on a HOST PAGE, and nothing that knows
 * whose page it is.
 *
 * It owns the CHANNEL concerns, which are exactly the concerns that cannot live inside the
 * iframe: auth/OIDC and the login gate, the session facts (userId, conversationId), the
 * sliding-panel chrome, and analytics delivery. It then hands config to AppHost, which
 * streams the app's `ui://` resource into a sandboxed iframe (§6d).
 *
 * It takes a templateId rather than looking one up. The demo site passes the channel it
 * routed to; a real embed passes what its <script> tag declared. Neither is special-cased
 * here, which is the point: the demo exercises the SAME component a customer loads, so the
 * two cannot drift.
 *
 * The drawer starts CLOSED behind a floating launcher (SlidingPanel), which is how a real
 * embed behaves on someone's site.
 */
export function UnoverseWidget({ templateId, analytics }) {
  // Auth lives in this CHANNEL. Register the current token getter so the MCP client +
  // stream send the bearer on every call (refresh-safe). null → anonymous.
  const auth = useAuth();
  useEffect(() => {
    setAccessTokenFn(hasAuth ? () => auth?.user?.access_token ?? null : null);
    return () => setAccessTokenFn(null);
  }, [auth?.user?.access_token]);

  // Logout: visit `?logout` → full Auth0 SSO sign-out → back to the login gate. Logout is a HOST
  // concern (it holds the session); no template/app change. Needs Auth0 "Allowed Logout URLs" to
  // include this origin.
  useEffect(() => {
    if (!hasAuth || !auth) return;
    if (!new URLSearchParams(window.location.search).has("logout")) return;
    window.history.replaceState({}, document.title, window.location.pathname);
    auth.signoutRedirect();
  }, [auth]);

  // The APP owns its panel width (manifest `width`) and posts it up via AppHost; the panel just
  // reacts. Undefined → SlidingPanel's own default until the app reports.
  const [panelWidth, setPanelWidth] = useState(undefined);

  // Login gate — ask the SERVER whether THIS app needs a login. One question, one
  // answer: /.well-known/unoverse-app/<org>/<app> → { authRequired } derives from the
  // app's bound workflow trigger toggle (Run Authorization). No client-side flag:
  // flipping the trigger toggle on the canvas IS the whole configuration.
  const [authRequired, setAuthRequired] = useState(null);
  useEffect(() => {
    fetch(`${config.serverUrl}/.well-known/unoverse-app/${templateId}`)
      .then((r) => r.json())
      .then((d) => setAuthRequired(!!d.authRequired))
      .catch(() => setAuthRequired(true)); // fail safe: assume secured
  }, [templateId]);
  const signedIn = !!auth?.isAuthenticated;
  const isPublic = authRequired === false;
  const needsLogin = authRequired === true && !signedIn;

  // Session facts (§5a), supplied once by the channel — never minted per-turn.
  //   conversationId → one per page load, shared across MCP apps — see session.js
  //   userId         → the authenticated JWT `sub`; on a public channel with no login,
  //                    the persisted guest id (`guest-<uuid>`) the gate requires
  const conversationId = useMemo(() => getConversationId(), []);
  const userId = auth?.user?.profile?.sub ?? (isPublic ? getGuestId() : undefined);

  // The app starts at ZERO width and grows to whatever it reports (`unoverse:size`) — the
  // app's natural width is the only authority. The gate states (loading/login) never report
  // one, so they get a fixed drawer width instead.
  let content;
  let isApp = false;
  if (authRequired === null || (hasAuth && auth?.isLoading)) {
    content = (
      <div className="flex h-full items-center justify-center bg-[#0f141a] text-sm text-gray-400">Loading…</div>
    );
  } else if (needsLogin && hasAuth) {
    content = <LoginScreen onLogin={() => auth?.signinRedirect()} />;
  } else if (needsLogin && !hasAuth) {
    content = (
      <div className="flex h-full flex-col items-center justify-center gap-3 bg-[#0f141a] text-center">
        <div className="text-sm font-semibold text-gray-200">This server requires authentication</div>
        <div className="max-w-sm text-xs leading-relaxed text-gray-500">
          Configure OIDC (VITE_AUTH_ISSUER / VITE_AUTH_CLIENT_ID) to sign in, or set{" "}
          <code className="text-gray-400">DISABLE_AUTH=true</code> in the server .env for anonymous local dev.
        </div>
      </div>
    );
  } else {
    isApp = true;
    // The client as HOST (§6d): stream the app (the server's ui:// resource) into a sandboxed
    // iframe and hand it config — the SAME contract Claude/ChatGPT use. The app opens its own
    // /mcp + /stream inside the iframe; this host embeds no Unoverse SDK at all.
    content = (
      <AppHost
        serverUrl={config.serverUrl}
        apiUrl={config.apiUrl}
        templateId={templateId}
        token={auth?.user?.access_token}
        userId={userId}
        conversationId={conversationId}
        onSize={setPanelWidth}
        analytics={analytics}
      />
    );
  }

  return <SlidingPanel width={isApp ? panelWidth ?? "0px" : "420px"}>{content}</SlidingPanel>;
}
