# TestFlight pipeline

`.github/workflows/testflight.yml` archives the app and uploads it to App Store
Connect for TestFlight. It runs when you push a `v*` tag or start it manually
from the Actions tab. Marketing version comes from the tag (`v1.2` → `1.2`) or
the manual input; the build number is the workflow run number.

Uploading is only half of TestFlight: after the build finishes processing in
App Store Connect (usually 5–15 minutes), add testers under **TestFlight →
Internal Testing**. Apple handles the invitations.

## What you need

1. **Paid Apple Developer Program membership.** TestFlight is not available to
   free Apple IDs.
2. **App record** in [App Store Connect](https://appstoreconnect.apple.com) for
   bundle ID `com.ioujared.traylog`.
3. **App IDs** for `com.ioujared.traylog` and `com.ioujared.traylog.widget` in
   [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
4. **App Group** `group.com.ioujared.traylog`, assigned to both App IDs. The
   widget cannot read the plan without it. Create it under **Identifiers → App
   Groups** and tick it in both App IDs' capabilities.
5. **App Store Connect API key** (Admin or App Manager role) from **Users and
   Access → Integrations → App Store Connect API → Team Keys**. Download the
   `.p8` once; you also need its Key ID and the Issuer ID.
6. **Team ID** from the [Membership page](https://developer.apple.com/account/#/membership)
   (10 characters).

## Repository configuration

Add these under **Settings → Secrets and variables → Actions**:

| Name | Kind | Value |
| --- | --- | --- |
| `APPSTORE_KEY_ID` | secret | Key ID of the API key |
| `APPSTORE_ISSUER_ID` | secret | Issuer ID of the API key |
| `APPSTORE_PRIVATE_KEY` | secret | Full contents of `AuthKey_XXXX.p8`, including the BEGIN/END lines |
| `DEVELOPMENT_TEAM` | variable | Your 10-character Team ID |

With the GitHub CLI, run these yourself in a terminal (each prompts for the
value, so paste secrets there, never into chat):

```sh
gh secret set APPSTORE_KEY_ID --repo IOUJared/traylog
gh secret set APPSTORE_ISSUER_ID --repo IOUJared/traylog
gh secret set APPSTORE_PRIVATE_KEY --repo IOUJared/traylog
gh variable set DEVELOPMENT_TEAM --repo IOUJared/traylog
```

## Run it

```sh
gh workflow run testflight.yml --repo IOUJared/traylog
gh run watch --repo IOUJared/traylog
```

or push a tag:

```sh
git tag v1.0 && git push origin v1.0
```

## Signing

The workflow uses Xcode's automatic cloud signing with the App Store Connect
API key (`-allowProvisioningUpdates` plus `-authenticationKey*`). With an Admin
or App Manager key, `xcodebuild` creates the distribution certificate and
profiles it needs.

If the archive step fails with a signing error:

- Confirm the App Group exists and is enabled on **both** App IDs.
- Confirm the API key role is Admin or App Manager.
- If Xcode still cannot mint a distribution certificate, create one once on a
  Mac (Xcode → Settings → Accounts → Manage Certificates → Apple Distribution),
  or generate a certificate signing request and upload it in the developer
  portal. CI-only environments cannot create the CSR without a keychain-signed
  request.

If you switch to manual signing, replace the archive settings with
`CODE_SIGN_STYLE=Manual`, `PROVISIONING_PROFILE_SPECIFIER`, and a base64
distribution certificate imported into a temporary keychain.

## Notes

- The uploaded key is written to `$RUNNER_TEMP` and deleted in an `always()`
  step; it is never committed.
- `MARKETING_VERSION` only overrides the build; bump `project.yml` if you want
  the repository to reflect the released version.
- The widget extension is embedded in the app, so a single archive uploads both.
- CI (`ios.yml`) still builds for the simulator unsigned and does not need any
  of these secrets.
