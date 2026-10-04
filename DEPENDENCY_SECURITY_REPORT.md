# Dependency Security Report — BarberBook

**Scope:** `functions/` Node/Cloud Functions dependency tree (production + development) and the Flutter/Dart tree.
**Status:** PASS — 0 known vulnerabilities in production, 0 in the full tree.
**Verified against:** `functions/package-lock.json` as staged in this phase, in a clean tree extracted from the Git index (see `PHASE1_2_REPORT.md` §5).

---

## 1. Environment actually used

| Tool | Version |
|---|---|
| Node.js | `v26.1.0` |
| npm | `11.13.0` |
| Firebase CLI | `15.25.1` |
| Flutter | `3.27.2` |
| Dart | `3.6.1` |
| OpenJDK | `21.0.7` |

Declared production engine is `node: "22"` (`functions/package.json`). See §7 for this gap.

## 2. Direct dependencies (unchanged by this phase)

| Package | Declared | Installed | Role |
|---|---|---|---|
| `firebase-admin` | `^13.0.2` | `13.10.0` | production |
| `firebase-functions` | `^6.3.0` | `6.6.0` | production |
| `@firebase/rules-unit-testing` | `^5.0.2` | `5.0.2` | dev |
| `mocha` | `^11.0.1` | `11.8.0` | dev |

No direct dependency was upgraded or removed.

## 3. Baseline audit (before any change)

| Scope | high | moderate | low | critical | total |
|---|---|---|---|---|---|
| Production (`--omit=dev`) | 0 | 8 | 0 | 0 | **8** |
| Full tree (prod + dev) | 6 | 10 | 1 | 0 | **17** |

The 17 findings reduce to **6 unique root advisories**.

## 4. Root advisories and dependency chains

### Production — 1 unique advisory, 8 affected packages

**GHSA-w5hq-g745-h8pq** — *uuid: Missing buffer bounds check in v3/v5/v6 when `buf` is provided* (moderate, vulnerable `<11.1.1`)

```
firebase-admin
├── @google-cloud/firestore ──> google-gax ──┬──> uuid      (vulnerable)
│                                            └──> retry-request ──> teeny-request ──> uuid
└── @google-cloud/storage  ──┬──> retry-request
                             └──> teeny-request ──> uuid
gaxios ──> uuid
```

Affected packages reported by npm: `uuid`, `gaxios`, `google-gax`, `@google-cloud/firestore`, `@google-cloud/storage`, `retry-request`, `teeny-request`, `firebase-admin`.

### Development — 3 unique advisories

| Advisory | Package | Severity | Vulnerable range | Reached via |
|---|---|---|---|---|
| [GHSA-m9gg-hp2v-232j](https://github.com/advisories/GHSA-m9gg-hp2v-232j) | `@grpc/grpc-js` | high | `<1.13.6` | `@firebase/rules-unit-testing` → `firebase` → `@firebase/firestore` → `@grpc/grpc-js` |
| [GHSA-f596-whhp-79r4](https://github.com/advisories/GHSA-f596-whhp-79r4) | `@grpc/grpc-js` | high | `<1.13.6` | same chain |
| [GHSA-5c6j-r48x-rmvq](https://github.com/advisories/GHSA-5c6j-r48x-rmvq) | `serialize-javascript` | high | `<=7.0.2` | `mocha` → `serialize-javascript` |
| [GHSA-qj8w-gfj5-8c6v](https://github.com/advisories/GHSA-qj8w-gfj5-8c6v) | `serialize-javascript` | high | `>=5.0.0 <7.0.5` | same chain |
| [GHSA-73rr-hh4g-fpgx](https://github.com/advisories/GHSA-73rr-hh4g-fpgx) | `diff` | low | `>=6.0.0 <8.0.3` | `mocha` → `diff` |

Note: `serialize-javascript` appears in the audit tree through Mocha's **parallel worker** mode.

## 5. Exploitability analysis

### GHSA-w5hq-g745-h8pq (uuid) — production

- The advisory is **specific to `uuid.v3()`, `uuid.v5()` and `uuid.v6()` when the caller supplies a `buf` argument**. The defect is a missing bounds check when writing into a caller-provided buffer.
- Observed evidence in this repository: the vulnerable code path *is present* in the installed `uuid@9.0.1` (`lib/v35.js`), so the advisory applies to the installed version.
- Observed consumers in the installed tree (`gaxios`, `google-gax`, `teeny-request`, `retry-request`) call **`uuid.v4()` only**, and none pass a `buf` argument.
- **Conclusion: not currently exploitable based on the observed code path.** This is an evidence-based judgement about the current call sites, *not* a claim that the vulnerable code is absent.

### GHSA-m9gg-hp2v-232j / GHSA-f596-whhp-79r4 (`@grpc/grpc-js`) — development

- Both advisories concern the **gRPC server** side: returning unauthorized certificates as authorised, and leaking handler error messages to clients.
- In this project `@grpc/grpc-js` is pulled in only by `@firebase/rules-unit-testing`, i.e. the **local Firestore emulator client used by the test suite**. It is a `devDependency` chain and is **not deployed** to Cloud Functions.
- Module-load probing confirmed the affected copies **are actually loaded** during emulator tests, so this is recorded as genuinely reachable in the test/dev context, not assumed away.

### GHSA-5c6j-r48x-rmvq / GHSA-qj8w-gfj5-8c6v (`serialize-javascript`) — development

- Reachable through Mocha's parallel worker mode.
- No script in this repository uses `--parallel` (see `functions/package.json` scripts, all plain `mocha` invocations), and runtime probing showed the vulnerable worker modules are **not loaded** in the current runs.
- Recorded as low practical exposure in this repository, but still remediated.

### GHSA-73rr-hh4g-fpgx (`diff`) — development

- Denial of service in `parsePatch` / `applyPatch`. Only reachable if untrusted patch input is fed to Mocha's diff machinery, which this project never does. Low severity and low exposure.

## 6. Remediation

### Chosen approach: npm `overrides` (no major upgrades)

```json
"overrides": {
  "uuid": "11.1.1",
  "@grpc/grpc-js": "1.14.5",
  "serialize-javascript": "7.1.2",
  "diff": "8.0.3"
}
```

| Override | Advisory cleared | Why this version |
|---|---|---|
| `uuid@11.1.1` | GHSA-w5hq-g745-h8pq | first non-vulnerable release; clears all 8 production findings at the root |
| `@grpc/grpc-js@1.14.5` | GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4 | `> 1.13.6` |
| `serialize-javascript@7.1.2` | GHSA-5c6j-r48x-rmvq, GHSA-qj8w-gfj5-8c6v | `> 7.0.5` |
| `diff@8.0.3` | GHSA-73rr-hh4g-fpgx | first non-vulnerable release (`>=6.0.0 <8.0.3` vulnerable) |

### Why the npm-suggested majors were rejected

npm offered these as the only "supported" fixes; each is a breaking major upgrade:

| npm suggestion | Rejected because |
|---|---|
| `firebase-admin` → `14.5.0` | Major. Changes Admin SDK APIs used throughout `functions/src/lib/*.js`. Out of scope for a security-fix phase and would require revalidating all server logic. |
| `firebase-functions` → `7.4.0` | Major. Only flagged transitively via `firebase-admin`; the underlying advisory is already cleared at the root. |
| `@firebase/rules-unit-testing` → `2.0.7` | npm's own suggestion is a **downgrade** across a major, which would break the test API the current suite is written against. |
| `mocha` → `12.0.3` | Major. Not required: both underlying advisories are cleared by overriding the vulnerable transitive packages directly. |

`npm audit fix --force` was **not** used.

Each override was first trialled in an isolated sandbox, with the full test suite re-run, before being applied to the repository. No test was deleted, skipped, or weakened, and no lint/analysis rule was suppressed.

## 7. Verification

Run in a **clean tree extracted from the staged Git index** (`git archive` of the index tree, no `.git`, no pre-existing `node_modules`):

| Check | Result |
|---|---|
| `npm ci` | PASS — 364 packages installed from lockfile |
| `npm audit --omit=dev` | **0 vulnerabilities** |
| `npm audit` (full) | **0 vulnerabilities** |
| `npm ls --depth=0` | PASS — no invalid/missing/extraneous entries |
| Unit tests | **68 passing** |
| Emulator/rules tests | **108 passing** (33 rules + 75 integration) |
| Flutter tests | **51 passing** |
| `flutter analyze` | 0 errors, 0 warnings, 20 info |

Flutter dependency currency: `flutter pub outdated` reports **every package at `Upgradable == Current`**. All available upgrades require breaking majors, so no in-range Flutter dependency update was applied.

## 8. Residual risk / limitations

1. **Node runtime version gap.** `engines.node` is `"22"` (the Cloud Functions runtime), but the verification environment ran **Node `v26.1.0`**. All suites passed on Node 26, but they were **not** executed on Node 22. Nothing in the dependency tree is known to require Node 24+, and `firebase-admin@13`/`firebase-functions@6` both declare `>=14`/`>=18` style ranges, so Node 26 is within their supported engine ranges. **The suites should be re-run on Node 22 in CI before release.** This is the most significant open item.
2. **Overrides are out-of-range pins.** `uuid@11.1.1` is a major above the range requested by consumers (which ask for `^9`), and `diff@8.0.3` / `serialize-javascript@7.1.2` likewise move beyond what the parents request. This is a deliberate, temporary trade-off to avoid a risky major upgrade of `firebase-admin`. It should be revisited when `firebase-admin` 14 is adopted, and the overrides revisited or removed then.
3. **No production deployment was performed**, by instruction. All gate verification is local. `npm audit` reflects the current advisory database, not the state of any deployed artifact.
4. Advisory data is a point-in-time snapshot; re-running `npm audit` is required as the database evolves.

## 9. Advisory references

- https://github.com/advisories/GHSA-w5hq-g745-h8pq
- https://github.com/advisories/GHSA-m9gg-hp2v-232j
- https://github.com/advisories/GHSA-f596-whhp-79r4
- https://github.com/advisories/GHSA-5c6j-r48x-rmvq
- https://github.com/advisories/GHSA-qj8w-gfj5-8c6v
- https://github.com/advisories/GHSA-73rr-hh4g-fpgx