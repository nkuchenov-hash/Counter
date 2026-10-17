/// <reference path="../pb_data/types.d.ts" />
// Prevent client-controlled upgrade to paid AI features.
// Pro state must only be set by trusted server billing/admin jobs.
function viktorRejectClientTierMutation(e) {
  const info = e.requestInfo();
  const auth = info.auth;
  const body = info.body || {};
  const isSuperuser = !!(auth && auth.isSuperuser);
  if (!isSuperuser && Object.prototype.hasOwnProperty.call(body, "tier")) {
    throw new ForbiddenError("Subscription entitlement is server managed.");
  }
  e.next();
}

onRecordCreateRequest((e) => {
  viktorRejectClientTierMutation(e);
}, "profiles");

onRecordUpdateRequest((e) => {
  viktorRejectClientTierMutation(e);
}, "profiles");
