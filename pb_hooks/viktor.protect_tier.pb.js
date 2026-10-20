/// <reference path="../pb_data/types.d.ts" />
// Stop untrusted clients forging the Pro tier via auth registration or PATCH.
// Every hook callback is self-contained: PocketBase JSVM callback execution
// may not retain file-global helpers.
onRecordCreateRequest((e) => {
  const info = e.requestInfo();
  const body = info.body || {};
  const auth = info.auth;
  if (!(auth && auth.isSuperuser) &&
      Object.prototype.hasOwnProperty.call(body, "tier")) {
    throw new ForbiddenError("Subscription entitlement is server managed.");
  }
  e.next();
}, "profiles");

onRecordUpdateRequest((e) => {
  const info = e.requestInfo();
  const body = info.body || {};
  const auth = info.auth;
  if (!(auth && auth.isSuperuser) &&
      Object.prototype.hasOwnProperty.call(body, "tier")) {
    throw new ForbiddenError("Subscription entitlement is server managed.");
  }
  e.next();
}, "profiles");
