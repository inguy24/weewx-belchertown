**Status:** Complete (2026-05-26)

**Outcome:** Webcam code stripped from all 3 repos, replaced with Belchertown-pattern static file serving. Wizard step 7 added for webcam configuration (enabled, image URL, video URL, refresh interval). Webcam config written as /var/www/clearskies/webcam.json (static file for dashboard) and stack.conf [webcam] (for wizard re-run). LXD disk device mounts webcam files from weewx host read-only. API has no webcam knowledge — webcam is a UI concern. Radar animation improved with cross-fade interpolation. Fonts standardized to Inter sans-serif.

---

# Plan: Strip Overengineered Webcam, Replace with Belchertown Pattern

**Created:** 2026-05-25
**Status:** Planned, not yet executed

## Context

The webcam implementation violated the project's prime directive: take what works from Belchertown. Instead of following Belchertown's simple pattern (static files served from a directory, `<img>` and `<video>` tags with cache-busting refresh), the implementation built an unnecessary API endpoint, config system, wizard step, admin section, and complex timelapse player. All of it needs to be stripped and replaced with the simple approach.

**How Belchertown does it** (`skins/Belchertown/index_radar.inc`):
- Webcam directory on the web server: `/webcam/`
- External process (cron) writes `weather_cam.jpg` and `weewx_timelapse.mp4`
- `<img src="webcam/weather_cam.jpg">` with 60-second cache-busting refresh
- `<video src="/webcam/weewx_timelapse.mp4">` with 15-minute reload
- No API, no config, no wizard — just static file serving

---

## Part 1: Remove all webcam code (3 repos, ~17 files to delete, ~40 code blocks to remove)

### API repo (`repos/weewx-clearskies-api/`)

**Delete files:**
- `weewx_clearskies_api/endpoints/webcam.py`

**Remove code from:**
- `models/responses.py` — delete `WebcamResponse` class
- `app.py` — delete webcam router import + `app.include_router(webcam_router)`
- `__main__.py` — delete webcam import, step 6q comments, `wire_webcam_settings()` call
- `config/settings.py` — delete `WebcamSettings` class, remove from `Settings` class (attribute, __init__ param, assignment, validate call, load_settings instantiation)
- `endpoints/setup.py` — delete `WebcamApplyConfig` model, remove `webcam` field from `ApplyRequest`, remove webcam section from `_write_api_conf()`
- `etc/api.conf.example` — delete `[webcam]` section

### Dashboard repo (`repos/weewx-clearskies-dashboard/`)

**Delete files:**
- `src/routes/webcam.tsx`
- All 13 `public/locales/*/webcam.json` files

**Remove code from:**
- `src/api/types.ts` — delete `WebcamData` interface
- `src/api/client.ts` — delete `WebcamData` import, delete `getWebcam()` function
- `src/hooks/useWeatherData.ts` — delete `getWebcam`/`WebcamData` imports, delete `useWebcam()` hook
- `src/App.tsx` — delete webcam lazy import, delete `/webcam` route
- `src/components/layout/nav-rail.tsx` — delete webcam nav item, delete `Camera` import
- `src/routes/now.tsx` — delete `useWebcam` import, delete `webcamData` state/effect, delete webcam card from the grid. **Keep the radar/webcam grid layout** but repurpose it (see Part 2)
- All 13 `public/locales/*/now.json` — delete `webcam` and `webcamAlt` keys
- All 13 `public/locales/*/nav.json` — delete `webcam` key

### Stack repo (`repos/weewx-clearskies-stack/`)

**Delete files:**
- `weewx_clearskies_config/templates/config/webcam_section.html`
- `weewx_clearskies_config/templates/wizard/step_webcam.html`

**Remove code from:**
- `wizard/state.py` — delete 5 webcam fields from WizardState, revert docstring "8 steps" → "7 steps"
- `wizard/state_persistence.py` — delete webcam from `_INT_FIELDS`, `_BOOL_FIELDS`, delete webcam section reading from `populate_from_config()`
- `wizard/routes.py` — delete step 7 GET/POST handlers, renumber step 8 (review) back to step 7, delete webcam from apply payload, delete webcam from `_merge_from_existing_config`, delete webcam from `_restore_prior_progress`, update docstring routing table
- `config/routes.py` — delete webcam from `_SECTION_META`, `_SECTION_ALLOWED_KEYS`, delete webcam template routing conditional
- `templates/config/dashboard.html` — delete `feature_sections` list, delete Features group from sidebar and overview
- `templates/wizard/_progress_bar.html` — remove "Webcam" from step_names, change `range(1, 9)` → `range(1, 8)`
- `templates/wizard/layout.html` — change step count 8 → 7
- `templates/wizard/step_review.html` — change "Step 8 of 8" → "Step 7 of 7", delete webcam review section, update Previous link `/step/7` → `/step/6`
- `templates/wizard/step_complete.html` — delete webcam `<li>`, renumber review step, update "Back to Review" link `/step/8` → `/step/7`
- All 7 step templates (`step_api.html` through `step_providers.html`) — change "of 8" → "of 7"

---

## Part 2: Replace with Belchertown pattern (simple static files)

### Caddy config
Add a route to serve `/webcam/` from a designated directory. On weather-dev, this would be:
```
handle /webcam/* {
    root * /var/www/clearskies/webcam
    file_server
}
```

The webcam directory contains:
- `weather_cam.jpg` — live still (written by external cron/HA automation)
- `weewx_timelapse.mp4` — assembled timelapse video (written by external process)

### Dashboard Now page (`src/routes/now.tsx`)
Keep the 50/50 grid layout for radar + webcam, but implement it the Belchertown way:

```tsx
{/* Webcam card — simple static image with cache-busting refresh */}
<Card>
  <CardHeader><CardTitle>{t('webcam')}</CardTitle></CardHeader>
  <CardContent>
    <img 
      src={`/webcam/weather_cam.jpg?t=${refreshTs}`}
      alt={t('webcamAlt')}
      className="w-full rounded"
      onError={(e) => { e.currentTarget.style.display = 'none' }}
    />
    <video controls loop className="w-full rounded mt-2">
      <source src={`/webcam/weewx_timelapse.mp4?t=${videoRefreshTs}`} type="video/mp4" />
    </video>
  </CardContent>
</Card>
```

- `refreshTs` updates every 60 seconds (cache-busting for the still image)
- `videoRefreshTs` updates every 15 minutes (cache-busting for the timelapse)
- **Video format: MP4** — matches Belchertown's `weewx_timelapse.mp4` with `type="video/mp4"`
- No API call, no `useWebcam` hook, no config check

**Graceful degradation — no errors when files don't exist:**
- Image: `onError` handler hides the `<img>` element entirely (no broken image icon)
- Video: `onError` on the `<video>` element hides it entirely (no empty player with error)
- If BOTH are missing (no webcam directory at all), the entire webcam card hides — no "not configured" message, no error, just not shown
- Use a state flag like `webcamAvailable` that starts `true` and flips to `false` on image load error. If `false`, don't render the webcam card at all
- The video should also have `onError` to hide itself independently if only the image exists but no video (or vice versa)

Keep `webcam` and `webcamAlt` i18n keys in `now.json` (they're needed for the card title and img alt). Delete the rest.

### No wizard step, no admin config, no API endpoint, no timelapse frame config needed
The webcam is just files in a directory — a still image and a video file. The operator points their capture script at `/var/www/clearskies/webcam/`. No `timelapse_max_frames`, no frame directory, no frame serving endpoint. We play the MP4 file directly, just like Belchertown does.

---

## Execution Order

1. **One agent per repo** to strip the code (3 agents in parallel)
2. Commit all 3 repos
3. Push all 3
4. Deploy: API restart, stack restart, dashboard rebuild with `VITE_SSE_URL=/sse`
5. Manually add Caddy route for `/webcam/` on weather-dev
6. Symlink or copy the existing webcam directory: `ln -s /var/www/weewx/webcam /var/www/clearskies/webcam`

## Part 3: Temporary cron job to sync webcam files

Until the Belchertown skin is decommissioned, the cron jobs write to `/var/www/weewx/webcam/`. A simple rsync/cp cron job on the weewx host copies the files to the Clear Skies directory.

**On weewx host**, add a cron job:
```bash
# Sync webcam files from Belchertown to Clear Skies every minute
* * * * * rsync -a /var/www/weewx/webcam/ /var/www/clearskies/webcam/ 2>/dev/null
```

Or if the Clear Skies webcam directory is on weather-dev (different host), use rsync over SSH:
```bash
* * * * * rsync -a /var/www/weewx/webcam/ weather-dev:/var/www/clearskies/webcam/ 2>/dev/null
```

This is temporary — when Belchertown is retired, the operator points the capture cron jobs directly at `/var/www/clearskies/webcam/` and removes this sync job.

**Directory setup on the target host:**
```bash
sudo mkdir -p /var/www/clearskies/webcam
sudo chown ubuntu:ubuntu /var/www/clearskies/webcam
```

## Deploy workflow

| Change | Commands on target host |
|--------|------------------------|
| API code | `ssh ratbert "lxc exec weewx -- bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull && sudo systemctl restart weewx-clearskies-api'"` |
| Stack code | `ssh 192.168.2.113 "cd /home/ubuntu/repos/weewx-clearskies-stack && git pull && sudo systemctl restart weewx-clearskies-config"` |
| Dashboard code | `ssh 192.168.2.113 "cd /home/ubuntu/repos/weewx-clearskies-dashboard && git pull && VITE_SSE_URL=/sse npm run build && sudo rm -rf /var/www/clearskies/assets && sudo cp -r dist/. /var/www/clearskies/"` |

## Verification
- [ ] No webcam nav link in dashboard
- [ ] No `/webcam` route in dashboard
- [ ] No `/api/v1/webcam` endpoint on API
- [ ] Wizard is 7 steps again (no webcam step)
- [ ] Admin config has no webcam section
- [ ] Now page shows webcam image from `/webcam/weather_cam.jpg` with 60s refresh
- [ ] Now page shows timelapse video from `/webcam/weewx_timelapse.mp4`
- [ ] If webcam directory doesn't exist, Now page gracefully hides the webcam card
- [ ] `npx tsc --noEmit` passes in dashboard
