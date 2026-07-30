/**
 * Login gate — the BRAND's login (auth is a channel/brand concern; the MCP app is
 * auth-agnostic). Shown when the server requires auth and the user isn't signed in. Clicking
 * Sign In runs the host's OAuth redirect (Auth0); the resulting token is handed to the app.
 */
export function LoginScreen({ onLogin }) {
  return (
    <div className="flex h-full flex-col bg-gray-50">
      <div className="flex flex-1 items-center justify-center p-6">
        <div className="w-full max-w-sm rounded-2xl border border-gray-100 bg-white p-8 shadow-xl">
          <div className="mb-6 flex justify-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gray-900">
              <svg className="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                />
              </svg>
            </div>
          </div>

          <h1 className="text-center text-xl font-semibold text-gray-900">Smart Assistant</h1>
          <p className="mb-8 mt-1 text-center text-sm text-gray-500">Sign in to continue</p>

          <button
            onClick={onLogin}
            className="flex w-full items-center justify-center gap-2 rounded-xl bg-gray-900 py-3 font-medium text-white transition-colors hover:bg-gray-800"
          >
            <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
              />
            </svg>
            Sign In
          </button>

          <p className="mt-6 text-center text-xs text-gray-400">Secured by Auth0</p>
        </div>
      </div>

      <p className="pb-6 text-center text-xs text-gray-400">Powered by Unoverse</p>
    </div>
  );
}
