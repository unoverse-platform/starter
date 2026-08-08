# @unoverse-platform/client — the reference client app

The canonical CLIENT of a universe: the embeddable chat/app channel a website
puts in front of your deployed stack. Moved in from the standalone unoverseDemo
repo (2026-07-28). It is the template customers copy, the acceptance vehicle
for the deployed stack, and the source of the embed widget.

A minimal Preact shell that **loads an app and self-runs** — point it at an app
id, it appears and works. All UI, layout and styling live in the SDK plus the
server-served definitions/theme; this app owns none of it. The workflow binding
is an APP fact (the manifest's `binding`), never client config
(`UNOVERSE_MCP_TEMPLATE_PROTOCOL` §4b).

## What this is, and is not

- **A STATIC BUILD. Never a platform image.** This app never enters
  docker-compose, never runs on the universe VM, and must never be
  containerized into the stack. It deploys through the client-app static
  module (S3 + CloudFront on AWS, Spaces on DO) — see
  `docs/architecture/INFRASTRUCTURE.md` § Client apps.
- **A channel, not a universe.** It holds no secrets and no server. It knows
  two facts: the universe's API URL and which app to load. Everything else —
  auth discovery, guest identity, streaming — comes from the platform.

## THE PRODUCT IS ONE LINE OF JAVASCRIPT

The end state that matters commercially: this app compiles to a single script
tag that someone ELSE hosts on THEIR web page:

```html
<script async src="https://chat.example.com/embed.js" data-app="yasisland/yas-island-chat-layout"></script>
```

`npm run build:widget` is that build target. Two consequences are
non-negotiable design constraints for every change made here:

1. **Everything is cross-origin.** The script runs on a third-party origin and
   calls the universe's API on a different origin. CORS on the platform's
   public surface, the IdP's callback/logout origin list, and
   `frame-ancestors` on the hosted app must all admit the embedding site
   (`client_origins` in the infra contract). Nothing in this app may assume
   same-origin anything.
2. **Auth is optional per experience, never assumed.** Public workflows work
   with zero login (the SDK mints a persisted `guest-` identity); sign-in-later
   upgrades the same conversation via the universe's advertised OIDC config
   (`/.well-known/unoverse-universe`). The app hardcodes no issuer.

## How it works (the app model)

1. Read the app manifest — `resources/read unoverse://apps/<appId>` →
   `binding.workflow`, `binding.trigger`, `autoTrigger`.
2. Open the data-plane (`useUnoverseConnection`) bound to that workflow/trigger.
3. Self-run on connect when the manifest says `autoTrigger` — the workflow
   streams the template selection and its components back in.
4. Render via `StreamedUnoverseTemplate`; actions route back to the workflow.

## Config

`.env.example` documents the two facts (API URL, app id). If a change seems to
need a third config value, question it.
