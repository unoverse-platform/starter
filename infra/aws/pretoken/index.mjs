/**
 * Cognito Pre Token Generation (V2_0) — the platform's token contract.
 *
 * LOAD-BEARING. The platform reads sub/email/roles (and permissions) off the
 * ACCESS token and never calls back to the IdP (docs/AUTH_TOKEN_FLOW.md). Without
 * this Lambda, email-keyed features silently no-op and no role-gated surface
 * (workflow:author builder, marketplace:publish publish, requires.role nodes)
 * can ever pass. The Cognito equivalent of the Auth0 Post-Login Action.
 *
 * Roles = the user's Cognito groups, verbatim. Groups are named in the platform's
 * noun:verb grammar (workflow:author, marketplace:publish, finance:approve, ...),
 * so group membership IS the RBAC surface. They are emitted on BOTH `roles` and
 * `permissions`: the platform's builder/publish gates read permissions, node
 * requires.role matches either.
 */
// The role → permission map, from the ground (ROLE_PERMISSIONS, set by terraform). Its
// absence is not an error: without it a group grants itself, which is the old behaviour.
const ROLE_PERMISSIONS = (() => {
  try { return JSON.parse(process.env.ROLE_PERMISSIONS ?? "{}"); } catch { return {}; }
})();

export const handler = async (event) => {
  const groups = event.request.groupConfiguration?.groupsToOverride ?? [];
  const email = event.request.userAttributes?.email;

  // ROLES ARE WHO YOU ARE; PERMISSIONS ARE WHAT YOU MAY DO. Cognito has one level — groups
  // — and the platform reads two claims: Canvas gates on `roles` containing "admin", while
  // the publish and builder gates read `permissions` for marketplace:publish and
  // workflow:author. Emitting groups as BOTH made every group a role and a permission at
  // once, so a pool built from permission-shaped groups had no "admin" and Canvas refused
  // an administrator who held every permission it grants.
  //
  // Groups are the roles. Permissions are what those roles map to, unioned.
  const permissions = [...new Set(
    groups.flatMap((g) => ROLE_PERMISSIONS[g] ?? [g]),
  )];

  const claims = {
    roles: groups,
    permissions,
    ...(email ? { email } : {}),
  };

  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        claimsToAddOrOverride: claims,
      },
      idTokenGeneration: {
        claimsToAddOrOverride: claims,
      },
    },
  };
  return event;
};
