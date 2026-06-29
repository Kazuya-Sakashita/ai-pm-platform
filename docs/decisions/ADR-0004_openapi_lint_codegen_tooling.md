# ADR-0004: OpenAPI lint/codegenはRedocly CLI、openapi-typescript、openapi-fetchを採用する

## Status

Accepted

## Date

2026-06-30

## Context

本プロジェクトはAPI駆動開発を最重要ルールとしている。`docs/api/openapi.yaml` を正とし、Backend/Frontend実装がOpenAPIから乖離しないようにする必要がある。

ISSUE-014では依存なしの `scripts/check-openapi.rb` を作成したが、これはYAML構文とcomponent `$ref` の簡易チェックに留まる。実装開始前に、lint、TypeScript型生成、Frontend API clientの標準を決める必要がある。

## Decision

MVPでは以下を採用する。

| Purpose | Tool |
| --- | --- |
| OpenAPI lint and governance | Redocly CLI |
| TypeScript type generation | openapi-typescript |
| Frontend API client | openapi-fetch |
| Dependency-free fallback check | `scripts/check-openapi.rb` |

## Rationale

Redocly CLIはOpenAPI descriptionのlint、bundle、API lifecycle operationsを扱える。MVPではlintから始め、将来bundleやdocs生成へ拡張できる。

openapi-typescriptはOpenAPI 3.0/3.1からTypeScript型を生成でき、runtime-freeな型生成に向く。

openapi-fetchはOpenAPI schemaから型安全なfetch clientを作れ、薄いruntimeでNext.js frontendと相性がよい。

## Generated files

推奨配置:

```text
frontend/lib/api/schema.d.ts
frontend/lib/api/client.ts
```

`schema.d.ts` は `docs/api/openapi.yaml` から生成する。

## Scripts

将来root `package.json` に追加する想定:

```json
{
  "scripts": {
    "api:check": "ruby scripts/check-openapi.rb && redocly lint docs/api/openapi.yaml",
    "api:types": "openapi-typescript docs/api/openapi.yaml -o frontend/lib/api/schema.d.ts",
    "api:verify": "npm run api:check && npm run api:types && git diff --exit-code frontend/lib/api/schema.d.ts"
  }
}
```

## CI Policy

CIでは以下を必須にする。

1. `ruby scripts/check-openapi.rb`
2. `redocly lint docs/api/openapi.yaml`
3. `openapi-typescript docs/api/openapi.yaml -o frontend/lib/api/schema.d.ts`
4. generated fileに差分が出ていないことを確認
5. Frontend typecheck

## Consequences

良い点:

- OpenAPIを中心にBackend/Frontendの乖離を検出しやすい。
- TypeScript clientの手書きを避けられる。
- API変更時にFrontendの型エラーとして影響が見える。
- Redocly CLIで将来のAPI governanceに拡張できる。

悪い点:

- Node.js toolchainが必要になる。
- generated fileの運用ルールが必要。
- Redocly lint rulesetを厳しくしすぎると初期開発速度が落ちる。

## Alternatives

### Spectral

有力候補だが、MVPではRedocly CLIのlint/bundle/docs寄りの拡張性を優先して不採用。

### OpenAPI Generator

多言語client/server生成には強いが、MVP frontendでは軽量な型生成とfetch clientで十分なため不採用。

### 手書きclient

不採用。OpenAPI駆動開発の価値を弱め、API変更時の検出が遅れる。

## References

- Redocly CLI: https://redocly.com/docs/cli
- openapi-typescript: https://openapi-ts.dev/introduction
- openapi-fetch: https://openapi-ts.dev/openapi-fetch/

## Follow-up

- root `package.json` を作成する。
- Redocly rulesetを追加する。
- `frontend/lib/api/schema.d.ts` を生成する。
- `frontend/lib/api/client.ts` を作成する。

