/**
 * OIDC config + token bridge — the SAB widget acts as an authenticated CHANNEL.
 *
 * Auth lives in the CHANNEL, never in the Unoverse SDK (UNOVERSE_MCP_TEMPLATE_
 * PROTOCOL §5a). The resulting Auth0 access token is fed to the UnoverseClient and
 * useUnoverseConnection via `getAccessToken`, where it rides the MCP `Authorization`
 * header and the REST trigger (docs/AUTH_TOKEN_FLOW.md). Mirrors the workbench.
 *
 * Configure via .env: VITE_AUTH_ISSUER, VITE_AUTH_CLIENT_ID, VITE_AUTH_AUDIENCE.
 * Unset → no AuthProvider is mounted and the client talks anonymously (dev servers
 * with DISABLE_AUTH=true).
 */
import { WebStorageStateStore } from "oidc-client-ts";

export const oidcConfig = {
  authority: import.meta.env.VITE_AUTH_ISSUER,
  client_id: import.meta.env.VITE_AUTH_CLIENT_ID,
  redirect_uri: window.location.origin,
  scope: "openid profile email",
  // Auth0 needs `audience` to mint an API access token (a JWT), not an opaque one.
  extraQueryParams: { audience: import.meta.env.VITE_AUTH_AUDIENCE || "gravity-api" },
  userStore: new WebStorageStateStore({ store: window.sessionStorage }),
  automaticSilentRenew: true,
  // Strip ?code=…&state=… off the URL after the redirect callback.
  onSigninCallback: () => window.history.replaceState({}, document.title, window.location.pathname),
};

/** True only when an issuer + client id are configured. */
export const hasAuth = !!(oidcConfig.authority && oidcConfig.client_id);

// Token bridge: the singleton UnoverseClient (created outside React) can't read auth
// context, so App registers the current token getter here. Called per request, so it
// always returns a fresh token (refresh-safe). null → anonymous.
let _getAccessToken = null;
export function setAccessTokenFn(fn) {
  _getAccessToken = fn;
}
export const getAccessToken = () => (_getAccessToken ? _getAccessToken() : null);
