# Spotify Library Organization System - Implementation Plan

**Status:** Planning  
**Created:** 2025-12-17

## Overview

AI-powered system to organize 2.5k+ Spotify songs with automatic categorization, listening analytics, and dynamic playlist generation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SPOTIFY LIBRARY ORGANIZATION SYSTEM                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DATA SOURCES                          DATABASE (PostgreSQL - LXC 105)      │
│  ┌─────────────┐                       ┌─────────────────────────────────┐  │
│  │  Spotify    │──── Liked Songs ────▶│  songs, song_metadata,          │  │
│  │    API      │──── Track Info  ────▶│  managed_playlists, tags        │  │
│  └─────────────┘                       └─────────────────────────────────┘  │
│                                                       ▲                      │
│  ┌─────────────┐                                      │                      │
│  │  Last.fm    │──── Scrobbles ─────▶ play_history ───┘                      │
│  │    API      │──── Skip Detection                                          │
│  └─────────────┘                                                             │
│                                                                              │
│  AI ENRICHMENT (Claude Agent - LXC 130)                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Batch Analysis: 50 songs/run → genre, mood, era, tags, energy      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  PLAYLIST ENGINE (n8n - LXC 109)                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Heavy     │  │   Seasonal  │  │   Genre     │  │  Classics   │        │
│  │  Rotation   │  │   Vibes     │  │  Playlists  │  │  & Moods    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Location | Purpose |
|-----------|----------|---------|
| PostgreSQL Database | LXC 105 | Store songs, metadata, play history, stats |
| n8n Workflows | LXC 109 | Orchestration, API calls, scheduling |
| Claude Agent | LXC 130 | AI song analysis |
| Last.fm API | External | Scrobble/skip data |
| Slack | External | Notifications |

---

## Database Schema

**Database:** `spotify_library` on PostgreSQL (LXC 105)

### Tables

```sql
-- Core song library
CREATE TABLE songs (
    id SERIAL PRIMARY KEY,
    spotify_id VARCHAR(64) UNIQUE NOT NULL,
    title VARCHAR(512) NOT NULL,
    artist VARCHAR(512) NOT NULL,
    album VARCHAR(512),
    duration_ms INTEGER,
    release_date DATE,
    spotify_popularity INTEGER,
    added_at TIMESTAMP,  -- when liked on Spotify
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- AI-generated metadata
CREATE TABLE song_metadata (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    genre VARCHAR(64),
    sub_genre VARCHAR(64),
    mood VARCHAR(64),
    energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 10),
    era VARCHAR(16),  -- decade: 60s, 70s, etc.
    vocal_style VARCHAR(32),  -- male, female, mixed, instrumental
    ai_tags TEXT[],  -- array of tags
    analyzed_at TIMESTAMP DEFAULT NOW(),
    analysis_version INTEGER DEFAULT 1,
    UNIQUE(song_id)
);

-- Listening history from Last.fm
CREATE TABLE play_history (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    played_at TIMESTAMP NOT NULL,
    duration_played_ms INTEGER,
    skipped BOOLEAN DEFAULT FALSE,
    source VARCHAR(32) DEFAULT 'lastfm',
    UNIQUE(song_id, played_at)
);

-- Aggregated stats (refreshed daily)
CREATE MATERIALIZED VIEW song_stats AS
SELECT 
    s.id AS song_id,
    COUNT(ph.id) AS total_plays,
    COUNT(ph.id) FILTER (WHERE ph.skipped = TRUE) AS total_skips,
    ROUND(COUNT(ph.id) FILTER (WHERE ph.skipped = TRUE)::NUMERIC / 
          NULLIF(COUNT(ph.id), 0) * 100, 2) AS skip_rate,
    COUNT(ph.id) FILTER (WHERE ph.played_at > NOW() - INTERVAL '7 days') AS plays_this_week,
    COUNT(ph.id) FILTER (WHERE ph.played_at > NOW() - INTERVAL '30 days') AS plays_this_month,
    MAX(ph.played_at) AS last_played,
    MIN(ph.played_at) AS first_played
FROM songs s
LEFT JOIN play_history ph ON s.id = ph.song_id
GROUP BY s.id;

-- Managed playlists
CREATE TABLE managed_playlists (
    id SERIAL PRIMARY KEY,
    spotify_playlist_id VARCHAR(64) UNIQUE,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    type VARCHAR(32) NOT NULL,  -- dynamic, seasonal, genre, mood
    query_rules JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    last_synced TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Current playlist contents
CREATE TABLE playlist_songs (
    id SERIAL PRIMARY KEY,
    playlist_id INTEGER REFERENCES managed_playlists(id) ON DELETE CASCADE,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    position INTEGER,
    added_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(playlist_id, song_id)
);

-- Tags
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(64) UNIQUE NOT NULL,
    type VARCHAR(32) NOT NULL,  -- genre, mood, era, custom
    color VARCHAR(7)  -- hex color
);

-- Song-Tag relationship
CREATE TABLE song_tags (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    source VARCHAR(16) DEFAULT 'ai',  -- ai, manual
    confidence NUMERIC(3,2),  -- 0.00 to 1.00
    UNIQUE(song_id, tag_id)
);

-- Manual overrides
CREATE TABLE song_overrides (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    exclude_from_playlists INTEGER[],  -- array of playlist IDs
    pinned_to_playlists INTEGER[],  -- array of playlist IDs
    manual_tags TEXT[],  -- override AI tags
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(song_id)
);

-- Indexes
CREATE INDEX idx_songs_spotify_id ON songs(spotify_id);
CREATE INDEX idx_songs_added_at ON songs(added_at);
CREATE INDEX idx_play_history_played_at ON play_history(played_at);
CREATE INDEX idx_play_history_song_id ON play_history(song_id);
CREATE INDEX idx_song_metadata_genre ON song_metadata(genre);
CREATE INDEX idx_song_metadata_mood ON song_metadata(mood);
CREATE UNIQUE INDEX idx_song_stats_song_id ON song_stats(song_id);
```

---

## n8n Workflows

### Data Ingestion

| # | Workflow | Trigger | Description |
|---|----------|---------|-------------|
| 1 | Import Liked Songs | Manual | One-time: Pull all 2.5k liked songs → `songs` table |
| 2 | Sync New Likes | Cron (hourly) | Check for newly liked songs, add to `songs` |
| 3 | Last.fm Scrobble Sync | Cron (15 min) | Pull recent scrobbles → `play_history` |
| 4 | Refresh Song Stats | Cron (daily 3am) | Refresh materialized view `song_stats` |

### AI Enrichment

| # | Workflow | Trigger | Description |
|---|----------|---------|-------------|
| 5 | Analyze Untagged Songs | Cron (every 6 hours) | Batch 50 unanalyzed → Claude → `song_metadata` |

### Playlist Management

| # | Workflow | Trigger | Description |
|---|----------|---------|-------------|
| 6 | Update Dynamic Playlists | Cron (daily 4am) | Refresh Heavy Rotation, On Repeat, etc. |
| 7 | Update Genre Playlists | On metadata update | Refresh genre-based playlists |
| 8 | Update Mood Playlists | On metadata update | Refresh mood-based playlists |
| 9 | Snapshot Seasonal Playlist | Webhook (manual) | Create/update seasonal playlist |

### Utilities

| # | Workflow | Trigger | Description |
|---|----------|---------|-------------|
| 10 | Slack Notifications | Sub-workflow | Called by other workflows to send updates |
| 11 | Manual Override Handler | Webhook | Handle tag/exclude/pin requests |

---

## Managed Playlists

All auto-generated playlists prefixed with `[Auto]`

### Dynamic (Daily Updates)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Heavy Rotation` | Top 30 by plays_this_month WHERE skip_rate < 40% |
| `[Auto] On Repeat` | plays_this_week >= 5 |
| `[Auto] Fresh Finds` | added_at within 30 days, plays >= 2 |

### Dynamic (Weekly Updates)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Rediscovered` | last_played > 6 months ago, plays_this_week >= 2 |
| `[Auto] Deep Cuts` | total_plays < 3, added > 6 months ago |
| `[Auto] Skip Jail` | skip_rate > 60%, total_plays >= 5 |

### Genre-Based (On Metadata Update)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Hip Hop` | genre = 'hip hop' |
| `[Auto] Indie` | genre = 'indie' |
| `[Auto] Electronic` | genre IN ('electronic', 'edm', 'house', 'techno') |
| `[Auto] R&B` | genre = 'r&b' |
| `[Auto] Rock` | genre IN ('rock', 'alternative', 'punk') |
| `[Auto] Pop` | genre = 'pop' |

*Additional genres created based on library analysis*

### Mood-Based (On Metadata Update)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Chill Vibes` | mood IN ('chill', 'relaxed', 'ambient') |
| `[Auto] Energy Boost` | energy_level >= 8 |
| `[Auto] Melancholic` | mood IN ('melancholic', 'sad', 'emotional') |
| `[Auto] Focus Mode` | mood = 'focus', energy_level BETWEEN 4 AND 7 |

### Seasonal (Manual Trigger)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Summer 2025` | Snapshot of high plays during Jun-Aug 2025 |
| `[Auto] Winter 2024-25` | Snapshot of high plays during Dec-Feb |

### Curated (Monthly)

| Playlist Name | Logic |
|---------------|-------|
| `[Auto] Classics` | spotify_popularity > 70 AND release_year < 2010 |
| `[Auto] Hidden Gems` | spotify_popularity < 40 AND total_plays >= 10 |

---

## Last.fm Integration

### API Endpoints Used

- `user.getRecentTracks` - Get scrobbles (paginated)
- `track.getInfo` - Get track details if needed

### Skip Detection Logic

```javascript
skipped = (duration_played_ms < 30000) || 
          (duration_played_ms < track_duration_ms * 0.5)
```

### Sync Strategy

1. Poll every 15 minutes
2. Store last sync timestamp in workflow static data
3. Fetch only new scrobbles since last sync
4. Dedupe by (song_id, played_at)
5. Match scrobbles to songs by title + artist

---

## Claude Analysis

### Batch Size
50 songs per run (every 6 hours)

### Cost Estimate
2,500 songs ÷ 50 per batch = 50 batches × ~$0.05 = ~$2.50 total

### Prompt Template

```
Analyze these songs and return a JSON array. For each song provide:
- genre: primary genre (lowercase)
- sub_genre: more specific genre (lowercase)  
- mood: one of [chill, energetic, melancholic, uplifting, aggressive, romantic, focus, party, emotional, peaceful]
- energy_level: 1-10 scale
- era: decade (60s, 70s, 80s, 90s, 2000s, 2010s, 2020s)
- vocal_style: one of [male, female, mixed, instrumental]
- tags: 3-5 descriptive lowercase tags

Songs to analyze:
1. "Title" by Artist (Album, Year)
2. ...

Return ONLY valid JSON array, no other text.
```

---

## Slack Notifications

### Events

| Event | Message Example |
|-------|-----------------|
| Analysis complete | "🎵 Analyzed 50 songs. 2,450 remaining." |
| Playlist updated | "📝 Updated [Auto] Heavy Rotation - 30 tracks" |
| New songs added | "➕ Added 5 new liked songs to library" |
| Songs hit skip jail | "⚠️ 3 songs moved to Skip Jail" |
| Seasonal snapshot | "📸 Created [Auto] Summer 2025 - 45 tracks" |
| Import complete | "✅ Imported 2,500 liked songs" |
| Error | "❌ Last.fm sync failed: {error}" |

---

## Manual Override Webhooks

| Endpoint | Method | Body | Purpose |
|----------|--------|------|---------|
| `/spotify/tag` | POST | `{spotify_id, tags[]}` | Manually tag a song |
| `/spotify/exclude` | POST | `{spotify_id, playlist_ids[]}` | Exclude from playlists |
| `/spotify/pin` | POST | `{spotify_id, playlist_ids[]}` | Pin to playlists |
| `/spotify/analyze` | POST | `{spotify_id}` | Force re-analyze |
| `/spotify/seasonal` | POST | `{name, season}` | Create seasonal snapshot |

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create `spotify_library` database on PostgreSQL (LXC 105)
- [ ] Run schema SQL to create tables
- [ ] Configure PostgreSQL to allow connections from n8n (LXC 109)
- [ ] Create n8n PostgreSQL credential
- [ ] Create n8n Last.fm credential (API key)
- [ ] Create n8n Slack webhook credential

### Phase 2: Data Import
- [ ] Build "Import Liked Songs" workflow
- [ ] Run import (2.5k songs)
- [ ] Verify data in `songs` table
- [ ] Build "Sync New Likes" workflow (hourly)

### Phase 3: Listening Data
- [ ] Build "Last.fm Scrobble Sync" workflow
- [ ] Run initial historical import (if available)
- [ ] Build "Refresh Song Stats" workflow
- [ ] Verify materialized view works

### Phase 4: AI Enrichment
- [ ] Build "Analyze Untagged Songs" workflow
- [ ] Test with small batch (10 songs)
- [ ] Enable scheduled runs
- [ ] Monitor until all songs analyzed

### Phase 5: Playlist Generation
- [ ] Build "Update Dynamic Playlists" workflow
- [ ] Create initial playlists on Spotify
- [ ] Build "Update Genre Playlists" workflow
- [ ] Build "Update Mood Playlists" workflow
- [ ] Build "Snapshot Seasonal Playlist" workflow

### Phase 6: Manual Controls & Notifications
- [ ] Build "Slack Notifications" sub-workflow
- [ ] Build "Manual Override Handler" workflow
- [ ] Test all webhook endpoints

### Phase 7: Documentation
- [ ] Create system runbook
- [ ] Document all workflows
- [ ] Add to homelab README

---

## Required Credentials

| Service | What's Needed | Status |
|---------|---------------|--------|
| Spotify OAuth2 | Already configured | ✅ Ready |
| Last.fm API | API Key + Shared Secret | ✅ Have key |
| Slack Webhook | Webhook URL | ✅ Connected to n8n |
| PostgreSQL | Connection to LXC 105 | ❌ Need to setup |
| Claude Agent SSH | SSH credential | ✅ Ready |

---

## Next Steps

1. **Setup PostgreSQL access** - Allow n8n to connect to LXC 105
2. **Create database** - Run schema SQL
3. **Start Phase 2** - Import liked songs

### PostgreSQL Setup Commands

```bash
# On PostgreSQL LXC (105)

# 1. Create database and user
sudo -u postgres psql <<EOF
CREATE DATABASE spotify_library;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE spotify_library TO n8n;
\c spotify_library
GRANT ALL ON SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO n8n;
EOF

# 2. Allow remote connections from n8n (192.168.1.122)
echo "host    spotify_library    n8n    192.168.1.122/32    scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf

# 3. Ensure PostgreSQL listens on all interfaces
# Edit /etc/postgresql/*/main/postgresql.conf
# Set: listen_addresses = '*'

# 4. Restart PostgreSQL
systemctl restart postgresql

# 5. Test connection from n8n LXC
# On n8n LXC (109):
# psql -h 192.168.1.117 -U n8n -d spotify_library
```
