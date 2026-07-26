---
sidebarTitle: "Credentials"
title: "Credential Management"
---

**The One Rule: Nodes NEVER touch credentials. Services read credentials from `credentialContext.credentials`.**

## ✅ CORRECT Pattern

The platform resolves credentials into `context.credentials` before execution. Services read them directly from there — no async fetch required.

### 1. Node Level (Executor)

```typescript
// ✅ CORRECT: Build credential context and pass to service
protected async executeNode(inputs, config, context) {
  const credentialContext = this.buildCredentialContext(context);
  const result = await myService(config, credentialContext, context.api);
  return { __outputs: result };
}

private buildCredentialContext(context: NodeExecutionContext) {
  const { workflowId, executionId, nodeId } = this.validateAndGetContext(context);
  return {
    workflowId, executionId, nodeId,
    nodeType: this.nodeType,
    config: context.config,
    credentials: context.credentials || {},
  };
}
```

### 2. Service Level

> **🛑 Select your credential BY NAME first.** `context.credentials` contains **every credential in the workflow**, keyed by credential type name (see [Credential Context Structure](#-credential-context-structure)). Many credential types expose the same field — `openAICredential`, `apolloCredential`, `hunterCredential`, `searchapiCredential` all have an `apiKey`. A blind "first object with `.apiKey`" scan therefore grabs **whichever happens to be first in the bag**, not yours. A node works in isolation, then silently authenticates with the wrong service the moment another `apiKey` credential is added to the workflow (symptom: a `401`/`No user found` from the API even though the correct credential is selected in the UI).
>
> Always read `available.<yourCredentialName>` first; fall back to the field-signature scan only for single-credential convenience.

```typescript
// ✅ CORRECT: Select THIS node's credential by its declared name, then fall back to a scan
export async function myService(config: any, credentialContext: any, api?: any) {
  const available = credentialContext.credentials || {};

  // Name-first: matches the credential this node declares (`credentials: [{ name: "myCredential" }]`).
  // The fallback scan only disambiguates correctly when one credential is present.
  const creds: any =
    available.myCredential ?? Object.values(available).find((v) => (v as any)?.apiKey);

  if (!creds?.apiKey) {
    throw new Error("myCredential missing apiKey");
  }

  // Use the credential
  return await externalAPI.call(creds.apiKey, config.data);
}

// ❌ WRONG: bare field-signature scan — grabs the first apiKey in the bag, not necessarily yours
// for (const val of Object.values(available)) { if (val?.apiKey) { creds = val; break; } }

// ❌ WRONG: api.getNodeCredentials() does not reliably return credentials
// const creds = await api.getNodeCredentials(credentialContext, "myCredential");
```

## Real Example — OpenAI

```typescript
// _legacy/nodes/openai/src/shared/openaiStream/client/openaiClient.ts
// (the openai package is a YAML manifest now, where the same rule is `credentials:` in
//  interface.yaml; this stays as the reference pattern for a CODE node)
export async function initializeOpenAIClient(context: any, logger: any, api?: any) {
  const availableCredentials = context.credentials || {};

  // Name-first: this node declares `openAICredential`. Falling back to a scan is only safe
  // when no other apiKey credential (Apollo, Hunter, SearchAPI, …) is in the workflow.
  const credentials: OpenAICredentials | undefined =
    availableCredentials.openAICredential ??
    (Object.values(availableCredentials).find((c) => (c as any)?.apiKey) as OpenAICredentials | undefined);

  if (!credentials?.apiKey) {
    throw new Error("OpenAI API key not found in credentials");
  }

  return new OpenAI({ apiKey: credentials.apiKey });
}
```

## 🏗️ Credential Context Structure

```typescript
interface CredentialContext {
  workflowId: string;
  executionId: string;
  nodeId: string;
  nodeType: string;
  config: any;
  credentials: Record<string, any>; // ALL workflow credentials, keyed by credential type name
                                     // (e.g. { openAICredential: {...}, hunterCredential: {...} }).
                                     // Select yours by name — NOT by scanning for the first apiKey.
}
```

## 📋 Complete Implementation

### 1. Node Definition — Declare Credentials

```typescript
export const MyNode: EnhancedNodeDefinition = {
  type: "MyNode",
  // ...
  credentials: [
    {
      name: "myCredential",
      type: "myCredentialType",
      required: true,
    },
  ],
};
```

### 2. Credential Definition

```typescript
// src/credentials/index.ts
export const MyCredential = {
  name: "myCredential",
  displayName: "My Service",
  description: "Credentials for My Service",
  properties: [
    {
      name: "apiKey",
      displayName: "API Key",
      type: "string" as const,
      required: true,
      secret: true,
      description: "Your API key",
    },
  ],
};
```

### 3. Service — Read Credentials

```typescript
export async function myService(config: any, credentialContext: any, api?: any) {
  const available = credentialContext.credentials || {};

  // Name-first (the name from `credentials: [{ name: "myCredential" }]`), scan as fallback.
  const creds: any =
    available.myCredential ?? Object.values(available).find((v) => (v as any)?.apiKey);

  if (!creds?.apiKey) throw new Error("API key not found in credentials");

  const response = await fetch(config.apiEndpoint, {
    headers: { Authorization: `Bearer ${creds.apiKey}` },
  });

  return response.json();
}
```

## 🚨 Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `"Credentials are required"` | Missing `credentials: [...]` on node definition | Add credential declaration |
| `"Credential not found"` | Config missing credential ID | Populate credential ID in node config UI |
| Empty/undefined credential values | Using `api.getNodeCredentials()` | Read from `credentialContext.credentials` directly |
| `401` / `No user found` **despite** the right credential selected in the UI | Service scans for the first `.apiKey` and grabs another node's credential (the bag holds every workflow credential) | Select by name: `available.<yourCredentialName> ?? <scan>` |

## 🔗 Study Real Implementations

- `_legacy/nodes/openai/src/shared/openaiStream/client/openaiClient.ts` — the canonical
  name-first pattern for reading `context.credentials`. Kept as a reference only: the
  `openai` package is a manifest now, where a credential is declared in `interface.yaml`
  and interpolated as `{{ credentials.<name>.<field> }}` with no code at all.
- `@unoverse-platform/miro-bridge` — `mcpHandlers.ts` — same pattern for bearer token auth

---

**Next**: [Troubleshooting](./05-troubleshooting.md)