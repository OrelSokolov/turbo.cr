# turbo.cr

A 1:1 Crystal port of **turbo-rails 2.0.20** (Hotwire Turbo Streams) with
the namespace `Turbo`, built on top of action_view.cr, action_pack.cr,
action_cable.cr, active_record.cr and active_job.cr. Covers the stream
tag builder (`turbo_stream.append/prepend/...`), cable broadcasting
(`broadcast_*_to`, declarative `broadcasts`/`broadcasts_to` on models),
`_later` jobs over ActiveJob, view helpers (`turbo_stream_from`,
`turbo_frame_tag`) and the `text/vnd.turbo-stream.html` HTTP format.
Client side is the official vendored `@hotwired/turbo` 8.0.13 UMD plus a
~60-line cable connector instead of the npm bundle. Suite: **60/60 oracle**
cases recorded from the real gem + an E2E smoke of the demo app.

> ⚠️ EXPERIMENTAL FRAMEWORK, DO NOT USE IN PRODUCTION YET.

## Installation

```yaml
dependencies:
  turbo_cr:
    github: OrelSokolov/turbo.cr
```

```sh
shards install
```

Depends on `active_support.cr`, `action_view.cr`, `action_pack.cr`,
`action_cable.cr`, `active_record.cr` and `active_job.cr`.

## Usage

```crystal
# In a view or turbo_stream template:
turbo_stream.append "entries", "<div>hi</div>"
turbo_stream.remove "clearance_5"
turbo_stream.update "entries", partial: "entries/entry", locals: {"entry" => entry}
turbo_stream.refresh

turbo_frame_tag "cart", src: "/cart", loading: "lazy" { }
turbo_stream_from "room", "entries"

# From a model or controller:
Turbo::StreamsChannel.broadcast_prepend_to ["entries"],
  target: "entries", content: "<div>new</div>"

class Message < ActiveRecord::Base
  include Turbo::Broadcastable
  broadcasts_to :board, inserts_by: :prepend, target: "board_messages"
end
```

## Feature comparison vs turbo-rails 2.0.20

### Streams tag builder & view helpers

| Feature | Original (turbo-rails) | Port (turbo.cr) | Status |
|---|---|---|---|
| `turbo_stream` actions append/prepend/replace/update/remove/before/after (+ `_all` variants) | ✅ | Same 7 actions, block/no-block overloads | ✅ |
| `turbo_stream.refresh`, custom `action`/`action_all` | ✅ | Same | ✅ |
| Rendering semantics: positional content unescaped, block/html escaped, `method:` before action/target | ✅ | Same (locked by oracle) | ✅ |
| `turbo_frame_tag` (+ block form, content_tag escaping) | ✅ | Same | ✅ |
| `turbo_stream_from` (signed stream name, custom channel) | ✅ | Same (`raise "streamables can't be blank"` locked by oracle) | ✅ |
| `renderable:` objects | ✅ | P2, not implemented | ❌ |

### Broadcasting

| Feature | Original | Port | Status |
|---|---|---|---|
| `broadcast_*_to` for all actions + `broadcast_action_to`, `broadcast_stream_to`, `broadcast_render_to` | ✅ | Same | ✅ |
| `broadcast_refresh_to` (no attributes in 2.0.20) | ✅ | Same (oracle pins the no-attributes behavior) | ✅ |
| Signed stream names (`signed_stream_name`/`verified_stream_name`, HEX digest) | ✅ | Same via ActiveSupport::MessageVerifier | ✅ |
| `Turbo::Broadcastable`: `broadcasts`/`broadcasts_to` macros (after_commit create/update/destroy), instance `broadcast_*`, `suppressing_turbo_broadcasts`, GlobalID-lite | ✅ | Same | ✅ |
| Proc streams in `broadcasts_to` | ✅ | P2, Symbol (model method) or String literal only | ⚠️ partial |
| Debounce in `broadcast_refreshes_with` | ✅ | P1, not implemented | ❌ |

### Jobs, channel & HTTP format

| Feature | Original | Port | Status |
|---|---|---|---|
| `Turbo::StreamsChannel` subscription by signed stream name | ✅ | Same (rejects invalid signatures) | ✅ |
| `_later` jobs: ActionBroadcastJob / BroadcastJob / BroadcastStreamJob | ✅ | Same via ActiveJob (payload-hash dispatch, ctors up to 4 args) | ✅ |
| `respond_to { format.turbo_stream }`, default `#{action}.turbo_stream.erb` render without layout, CT `text/vnd.turbo-stream.html; charset=utf-8` | ✅ | Same (in action_pack.cr), Accept negotiation + `?format=turbo_stream` | ✅ |
| `redirect_to` from a turbo_stream request → http fallback with CT text/html | ✅ | Same | ✅ |
| Client JS (npm bundle) | ✅ | Vendored `@hotwired/turbo` 8.0.13 UMD + ~60-line `turbo_cable.js` WS connector | ⚠️ partial |
| Turbo::Frames `frame_loading` / `enforce_frame_routes` | ✅ | No routing-port analog | ❌ |

## Deviations & Crystal-specific notes

- kwargs → named args: `turbo_stream.append target, "text"` instead of
  `**options`.
- Renderer seam instead of `ApplicationController.render`: compiled
  languages can't render from a string at runtime — the app registers
  `Turbo.partial_renderer` / `Turbo.template_renderer` procs over
  compile-time-compiled partials/templates. See `spec/oracle_spec.cr`
  (TurboView) and demo (`src/turbo_renderers.cr`) for boilerplate.
- `broadcasts` macro: pluralize is a runtime inflector, unavailable in
  macro-land — the stream name is computed at runtime.
- Block overloads are typed (`&block : Proc(String)`) because untyped
  blocks passed through as Proc return nil; locals are normalized via
  `Turbo.cast_locals` (generics invariance); ActiveJob argument hashes
  are strictly `Hash(String | Symbol, ArgValue)`.
- Declarative macros live in the `Broadcastable` module body (plain
  methods in ClassMethods via `macro included`) because `extend` inside
  `macro included` doesn't hoist macros.

## Testing

```sh
make spec    # = CRAILS_VIEWS=spec/fixtures/views crystal spec
```

Requires a local PostgreSQL (default
`postgres://root@/crails_turbo_spec?host=/var/run/postgresql`,
override with `TURBO_SPEC_URL`); Redis is not needed (in-process Test
subscription adapter). Oracle: **60 cases** recorded from the real
turbo-rails 2.0.20 + rails 8.1.4 (DB `crails_turbo_oracle`, TZ=UTC) in
`oracle/cases.rb` → `oracle/expected.yml`; the Crystal mirror
`spec/oracle_spec.cr` replays them 1:1 without edits (expected raise
cases included). E2E smoke `spec/e2e_smoke.cr` additionally needs the
demo app running: `demo/bin/app serve -p 3001`.
