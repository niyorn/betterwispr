@AGENTS.md

# This fork

`niyorn/betterwispr` is a personal fork of `opennookorg/betterwispr`, built and run on this Mac
next to the official app. The upstream rules in `AGENTS.md` still apply.

## Branches

| Branch  | Holds                                   | Rule                                                                    |
| ------- | --------------------------------------- | ----------------------------------------------------------------------- |
| `main`  | An exact copy of `upstream/main`        | Never commit here, so GitHub's Sync fork stays a one-click fast-forward |
| `local` | Our own changes, built into the Dev app | Merge `main` into it after every sync; never rebase                     |

Updating:

```sh
gh repo sync niyorn/betterwispr      # or the Sync fork button on GitHub
git switch main && git pull
git switch local && git merge main
./scripts/install-dev.sh
```

To try an upstream PR before it lands: `git fetch upstream pull/<n>/head:pr-<n>`, then
`git merge pr-<n>` on `local`.

A change meant for upstream goes on its own branch off `main`, never off `local`, so none of
the fork-only changes travel with it.

## Toolchain

The full Xcode is required, not just the Command Line Tools: Apple Intelligence notes use the
`@Generable` macro, whose plugin ships only with Xcode. Without it the build stops with
`plugin for module 'FoundationModelsMacros' not found`.

## The Dev app

`./scripts/install-dev.sh` builds the Dev variant, signs it, replaces
`/Applications/BetterWispr Dev.app` and launches it. Use it for every rebuild.

`BETTERWISPR_VARIANT=dev` (read by `scripts/build-app.sh`) changes only `Info.plist`:

| Key                       | Official app              | Dev app                                                 |
| ------------------------- | ------------------------- | ------------------------------------------------------- |
| `CFBundleIdentifier`      | `org.betterwispr.app`     | `org.betterwispr.app.dev`                               |
| `CFBundleName`            | `BetterWispr`             | `BetterWispr Dev`                                       |
| `BetterWisprDataFolder`   | not set, so `BetterWispr` | `BetterWispr Dev`                                       |
| `SUEnableAutomaticChecks` | default                   | `false`, so Sparkle never swaps in the official release |

Every data path goes through `AppPaths.support`, which reads `BetterWisprDataFolder`.
The models live in `~/Library/Application Support/BetterWispr Dev/Models`; the official app's
`BetterWispr/Models` is a symlink to it, so models are downloaded once and deleting the official
app with its folder leaves the Dev app untouched. Settings, history, vocabulary and meetings are
the Dev app's own. Its shortcut is `⌃⌥⇧⌘ D`; the official app keeps `⌃⌥⇧⌘ Space`. Two apps on
the same shortcut fail silently, because the second hot-key registration is refused.

Never use `make run` or `make dev`: they `pkill -x BetterWispr`, which kills both apps.

## Signing

The Dev app is signed with `BetterWispr Local`, a self-signed code-signing certificate in the
login keychain. A stable certificate is what keeps Accessibility (paste) granted across
rebuilds; an ad-hoc signature changes every build and macOS revokes the grant each time.

macOS lists it as `CSSMERR_TP_NOT_TRUSTED`, so `security find-identity -v` and
`build-app.sh`'s automatic pick skip it. That is why `install-dev.sh` passes
`CODESIGN_IDENTITY` by name. Signing works regardless.

Keychain Access's Certificate Assistant failed here ("The specified item could not be found in
the keychain"). If the certificate is lost, recreate it from the terminal:

```sh
T=$(mktemp -d) && cd "$T"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout key.pem -out cert.pem \
  -subj "/CN=BetterWispr Local" -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning"
pw=$(openssl rand -hex 16)
openssl pkcs12 -export -inkey key.pem -in cert.pem -name "BetterWispr Local" -out cert.p12 \
  -passout "pass:$pw" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
security import cert.p12 -k ~/Library/Keychains/login.keychain-db -P "$pw" -T /usr/bin/codesign
cd - && rm -rf "$T"
```

A new certificate means granting Accessibility to `BetterWispr Dev` once more.

## What `local` changes

| Change                                                                                                                   | Where                                | Upstream?                             |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ | ------------------------------------- |
| History in a `List`, so leaving it no longer freezes                                                                     | Upstream PR #87, merged in           | Drop the merge once #87 lands         |
| Notes and Ask send API and CLI models the whole meeting in one request (200,000 characters); on-device models keep 6,000 | `MeetingNotesGenerator.budget(for:)` | Good PR candidate                     |
| Dev variant: `AppPaths`, `BETTERWISPR_VARIANT`, `install-dev.sh`                                                         | see above                            | Fork only                             |
| OpenRouter provider order per model, which wins over the low-latency `sort`                                              | `APINotesModel.openRouterProviders`  | Fork only                             |
| Parakeet phrase booster also for Dutch, spell-checked in Dutch and English                                               | `ParakeetProvider.boostedLanguages`  | Possible PR, after real-voice testing |
| Light cleanup also drops Dutch filled pauses (`eh`, `ehm`, `euh`), never the word `er`                                   | `TranscriptCleaner.dutchFillers`     | Possible PR |
| Notes language picker and own notes instructions (add to or replace the built-in prompt)                                 | Models → Meeting notes · Language and prompt | Possible PR (upstream issue #75) |
| Per-meeting notes language and instructions, laid over the ones from Models                                              | Notetaker → Summary → Notes options  | Possible PR |
| Vocabulary sent with meeting notes as a spelling reference (terms plus known mishearings; capped for small models)       | `MeetingNotesGenerator.vocabularyReference` | Possible PR |

## Known limits of the upstream app

- Upstream runs the Parakeet phrase booster only for English or automatic language, and with
  automatic language only when the text comes out English. On `local` it also runs for Dutch,
  with spelling checked in Dutch and English. Measured on 8 sentences of the macOS Dutch voice
  full of terms, it fixed 3 of 13 misheard terms; 8 plain Dutch sentences came out unchanged
  apart from one vocabulary hit (`Marten` → `Maarten`). Its model is English-only, so a misheard
  term that is itself a real word (`dit` for Git, `Egel` for Egle) stays.
- Learned corrections are checked by a model only for English text with Medium cleanup;
  otherwise rules alone decide, and their common-word list is English.
- Upstream's OpenRouter notes connection cannot set a provider order. On `local`,
  `APINotesModel.openRouterProviders` pins one per model and replaces the low-latency
  `sort: throughput`; keep it in step with Waan's `src/config/models.js` after a
  `npm run check:cache` run there. A model missing from the list lets OpenRouter choose.
