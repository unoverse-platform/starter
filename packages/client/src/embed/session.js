/**
 * Session identity — the channel-supplied session FACTS (§5a; UNOVERSE_MCP_TEMPLATE_
 * PROTOCOL). These are supplied ONCE by the channel and never invented per-turn:
 *
 *   - userId          the authenticated subject (the JWT `sub`) — who
 *   - conversationId  the persistent thread — survives reloads AND is shared across
 *                     MCP apps in the same conversation (mirrors legacy gravity-client's
 *                     persisted user id; conversationId is a sessionParam it requires)
 *
 * The workflow streams its reply to (userId, conversationId), so both MUST be stable and
 * identical on the stream session AND the tool call. Minting a fresh id per click/reload
 * (the earlier bug) means the reply never lands.
 */
// ONE id scheme: a prefix so an id is readable in a log, then a UUID. The prefix is the
// only part anything reads (the platform's public-entry gate checks `guest-`); the rest is
// opaque, so there is nothing to parse and no clock or PRNG in the identity.
const makeId = (prefix) => `${prefix}-${crypto.randomUUID()}`;

/**
 * The conversation id — minted ONCE PER PAGE LOAD and held in memory. A browser
 * refresh starts a fresh conversation (fresh agent thread, fresh durable surfaces);
 * within the load, every MCP app, stream session and tool call shares this ONE id
 * (the "reply never lands" bug was minting per click/turn — per-LOAD is safe).
 *
 * Minted on FIRST USE rather than at import: `crypto.randomUUID` exists only in a secure
 * context, so minting at module load would take the whole bundle down on a plain-http LAN
 * URL instead of failing the one call that needs an id.
 */
let conversationId = null;

export function getConversationId() {
  if (!conversationId) conversationId = makeId("conv");
  return conversationId;
}

/** Start a fresh thread ("new conversation") mid-session — mints and returns a new id. */
export function resetConversation() {
  conversationId = makeId("conv");
  return conversationId;
}

/**
 * Guest identity for PUBLIC channels — the anonymous visitor's stable `userId`.
 *
 * The platform's public-entry gate requires guest sessions to present a
 * `guest-`-prefixed id (so an anonymous caller can never claim a real user's id),
 * and keys the visitor's conversations and memory off it — so it must SURVIVE
 * reloads. localStorage, minted once per browser.
 */
const GUEST_KEY = "unoverse:guestId";

export function getGuestId() {
  let id;
  try {
    id = localStorage.getItem(GUEST_KEY);
  } catch {
    /* storage blocked (private mode) → per-load guest below */
  }
  if (!id || !id.startsWith("guest-")) {
    id = makeId("guest");
    try {
      localStorage.setItem(GUEST_KEY, id);
    } catch {
      /* fine: the id just won't survive the reload */
    }
  }
  return id;
}
