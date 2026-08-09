// Build-time stub for `ajv` + `ajv-formats`, aliased in for BOTH client builds.
//
// The MCP SDK statically imports Ajv (validation/ajv-provider.js) as its DEFAULT JSON-schema
// validator. Ajv compiles schemas with `new Function`, so it is both large and blocked by any
// strict CSP (no unsafe-eval). This client's ONLY MCP call is the one-shot `readResource` that
// fetches the app HTML, so a schema compiler is weight it never uses.
//
// We inject CfWorkerJsonSchemaValidator at the `new Client()` site (src/embed/AppHost.jsx),
// so the Ajv provider is never constructed and this stub is never invoked. Aliasing here keeps
// the eval-using real Ajv out of the bundle entirely. Same pattern as the webSDK build
// (apps/unoverse/web/sdk/ajv-stub.js). See memory project_chatgpt_widget_csp_eval.
//
// One default export serves both consumers (`new Ajv(...)` and `addFormats(ajv)`); neither
// runs at runtime.
export default function AjvStub() {}
