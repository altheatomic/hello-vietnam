# UI change patches

These patches preserve the UI work from branch:

`fe-feature/upgrade-account-ui-language-ui`

Base branch used for export:

`check`

Patch order:

1. `0001-Update-upgrade-account-UI-and-language-labels.patch`
2. `0002-Show-current-subscription-plan-on-upgrade-page.patch`
3. `0003-Update-upgrade-payment-screen-UI.patch`
4. `0004-Complete-upgrade-payment-flow.patch`
5. `0005-Update-travel-app-UI-flows.patch`

To apply these changes on another branch:

```sh
git am ui-patches/*.patch
```

If the target branch has diverged and `git am` reports conflicts, resolve the conflicted files, then continue:

```sh
git am --continue
```

To abort while resolving conflicts:

```sh
git am --abort
```
