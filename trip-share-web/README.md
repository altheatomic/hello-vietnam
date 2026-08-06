# HelloVietnam public trip viewer

This is a dependency-free static site intended for Cloudflare Pages. Use this
directory as the Pages build output directory; no build command is required.

## Deployment inputs

1. Deploy the `trip-share` Supabase Edge Function with `--no-verify-jwt`.
2. Set Edge Function secrets `SHARE_WEB_BASE_URL` and
   `SHARE_WEB_ALLOWED_ORIGINS` to the final Pages HTTPS origin.
3. Confirm `config.js` points to the deployed function.
4. Copy `.well-known/assetlinks.json.example` to
   `.well-known/assetlinks.json` and replace the placeholder with the SHA-256
   certificate fingerprints. Include the local release certificate and the
   Play App Signing certificate when both APK distribution paths are used.
5. Build Flutter with the same host in both layers:

```powershell
$env:SHARE_WEB_HOST='<pages-project>.pages.dev'
flutter build apk --dart-define=SHARE_WEB_HOST=<pages-project>.pages.dev
```

Android must receive the JSON at
`https://<host>/.well-known/assetlinks.json` as `application/json` without a
redirect. `_redirects` keeps `/trip/<token>` on the SPA while leaving the
well-known file as a physical asset.
