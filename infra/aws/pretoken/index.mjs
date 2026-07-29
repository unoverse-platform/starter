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
export const handler = async (event) => {
  const groups = event.request.groupConfiguration?.groupsToOverride ?? [];
  const email = event.request.userAttributes?.email;

  const claims = {
    roles: groups,
    permissions: groups,
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
