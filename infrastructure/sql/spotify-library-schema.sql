-- =============================================================================
-- Spotify Library Organization System - Database Schema
-- =============================================================================
-- Database: spotify_library
-- Target: PostgreSQL 15+ on LXC 105 (192.168.1.117)
-- Created: 2025-12-28
-- =============================================================================

-- Run this AFTER creating the database and user (see setup commands below)

-- =============================================================================
-- CORE TABLES
-- =============================================================================

-- Core song library (synced from Spotify Liked Songs)
CREATE TABLE IF NOT EXISTS songs (
    id SERIAL PRIMARY KEY,
    spotify_id VARCHAR(64) UNIQUE NOT NULL,
    spotify_uri VARCHAR(128),
    title VARCHAR(512) NOT NULL,
    artist VARCHAR(512) NOT NULL,
    artist_id VARCHAR(64),
    album VARCHAR(512),
    album_id VARCHAR(64),
    duration_ms INTEGER,
    release_date DATE,
    spotify_popularity INTEGER,
    preview_url TEXT,
    explicit BOOLEAN DEFAULT FALSE,
    added_at TIMESTAMP,  -- when liked on Spotify
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Spotify audio features (from Spotify Audio Features API)
CREATE TABLE IF NOT EXISTS audio_features (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    danceability NUMERIC(4,3),      -- 0.0 to 1.0
    energy NUMERIC(4,3),            -- 0.0 to 1.0
    key INTEGER,                    -- 0-11 (C, C#, D, etc.)
    loudness NUMERIC(5,2),          -- dB, typically -60 to 0
    mode INTEGER,                   -- 0 = minor, 1 = major
    speechiness NUMERIC(4,3),       -- 0.0 to 1.0
    acousticness NUMERIC(4,3),      -- 0.0 to 1.0
    instrumentalness NUMERIC(4,3),  -- 0.0 to 1.0
    liveness NUMERIC(4,3),          -- 0.0 to 1.0
    valence NUMERIC(4,3),           -- 0.0 to 1.0 (musical positiveness)
    tempo NUMERIC(6,2),             -- BPM
    time_signature INTEGER,         -- 3, 4, 5, etc.
    fetched_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(song_id)
);

-- AI-generated metadata (from Claude analysis)
CREATE TABLE IF NOT EXISTS song_metadata (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    genre VARCHAR(64),
    sub_genre VARCHAR(64),
    mood VARCHAR(64),
    energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 10),
    era VARCHAR(16),  -- decade: 60s, 70s, 80s, 90s, 2000s, 2010s, 2020s
    vocal_style VARCHAR(32),  -- male, female, mixed, instrumental
    ai_tags TEXT[],  -- array of descriptive tags
    ai_description TEXT,  -- short description of the song
    analyzed_at TIMESTAMP DEFAULT NOW(),
    analysis_version INTEGER DEFAULT 1,
    UNIQUE(song_id)
);

-- =============================================================================
-- LISTENING DATA (Last.fm Integration)
-- =============================================================================

-- Listening history from Last.fm scrobbles
CREATE TABLE IF NOT EXISTS play_history (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    played_at TIMESTAMP NOT NULL,
    duration_played_ms INTEGER,
    skipped BOOLEAN DEFAULT FALSE,
    source VARCHAR(32) DEFAULT 'lastfm',  -- lastfm, spotify, manual
    lastfm_track_mbid VARCHAR(64),
    UNIQUE(song_id, played_at)
);

-- =============================================================================
-- PLAYLIST MANAGEMENT
-- =============================================================================

-- Managed playlists (auto-generated playlists we control)
CREATE TABLE IF NOT EXISTS managed_playlists (
    id SERIAL PRIMARY KEY,
    spotify_playlist_id VARCHAR(64) UNIQUE,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    playlist_type VARCHAR(32) NOT NULL,  -- dynamic, seasonal, genre, mood, curated
    update_frequency VARCHAR(16) DEFAULT 'daily',  -- hourly, daily, weekly, manual
    query_rules JSONB,  -- SQL-like rules as JSON
    max_tracks INTEGER DEFAULT 50,
    is_active BOOLEAN DEFAULT TRUE,
    last_synced TIMESTAMP,
    sync_error TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Current playlist contents (what's actually in each playlist)
CREATE TABLE IF NOT EXISTS playlist_songs (
    id SERIAL PRIMARY KEY,
    playlist_id INTEGER REFERENCES managed_playlists(id) ON DELETE CASCADE,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    position INTEGER,
    added_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(playlist_id, song_id)
);

-- Playlist sync history (for debugging and rollback)
CREATE TABLE IF NOT EXISTS playlist_sync_log (
    id SERIAL PRIMARY KEY,
    playlist_id INTEGER REFERENCES managed_playlists(id) ON DELETE CASCADE,
    synced_at TIMESTAMP DEFAULT NOW(),
    tracks_added INTEGER DEFAULT 0,
    tracks_removed INTEGER DEFAULT 0,
    total_tracks INTEGER,
    duration_ms INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT
);

-- =============================================================================
-- TAGGING SYSTEM
-- =============================================================================

-- Tag definitions
CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(64) UNIQUE NOT NULL,
    tag_type VARCHAR(32) NOT NULL,  -- genre, mood, era, activity, custom
    color VARCHAR(7),  -- hex color for UI
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Song-Tag relationships
CREATE TABLE IF NOT EXISTS song_tags (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    source VARCHAR(16) DEFAULT 'ai',  -- ai, manual, spotify
    confidence NUMERIC(3,2),  -- 0.00 to 1.00 for AI-assigned tags
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(song_id, tag_id)
);

-- =============================================================================
-- USER OVERRIDES & PREFERENCES
-- =============================================================================

-- Manual overrides for songs
CREATE TABLE IF NOT EXISTS song_overrides (
    id SERIAL PRIMARY KEY,
    song_id INTEGER REFERENCES songs(id) ON DELETE CASCADE,
    exclude_from_playlists INTEGER[],  -- array of managed_playlists IDs to exclude from
    pinned_to_playlists INTEGER[],     -- array of managed_playlists IDs to always include
    manual_tags TEXT[],                -- override AI tags with manual ones
    hidden BOOLEAN DEFAULT FALSE,      -- hide from all auto-playlists
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(song_id)
);

-- =============================================================================
-- SYSTEM TABLES
-- =============================================================================

-- Sync state tracking
CREATE TABLE IF NOT EXISTS sync_state (
    id SERIAL PRIMARY KEY,
    sync_type VARCHAR(32) UNIQUE NOT NULL,  -- spotify_likes, lastfm_scrobbles, audio_features
    last_sync_at TIMESTAMP,
    last_sync_cursor TEXT,  -- pagination cursor or timestamp for incremental syncs
    items_synced INTEGER DEFAULT 0,
    status VARCHAR(16) DEFAULT 'idle',  -- idle, running, error
    error_message TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Workflow execution log
CREATE TABLE IF NOT EXISTS workflow_log (
    id SERIAL PRIMARY KEY,
    workflow_name VARCHAR(128) NOT NULL,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    status VARCHAR(16) DEFAULT 'running',  -- running, success, error
    items_processed INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB
);

-- =============================================================================
-- MATERIALIZED VIEW: Song Statistics
-- =============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS song_stats AS
SELECT 
    s.id AS song_id,
    s.spotify_id,
    s.title,
    s.artist,
    COUNT(ph.id) AS total_plays,
    COUNT(ph.id) FILTER (WHERE ph.skipped = TRUE) AS total_skips,
    ROUND(
        COUNT(ph.id) FILTER (WHERE ph.skipped = TRUE)::NUMERIC / 
        NULLIF(COUNT(ph.id), 0) * 100, 2
    ) AS skip_rate,
    COUNT(ph.id) FILTER (WHERE ph.played_at > NOW() - INTERVAL '7 days') AS plays_last_7d,
    COUNT(ph.id) FILTER (WHERE ph.played_at > NOW() - INTERVAL '30 days') AS plays_last_30d,
    COUNT(ph.id) FILTER (WHERE ph.played_at > NOW() - INTERVAL '90 days') AS plays_last_90d,
    MAX(ph.played_at) AS last_played_at,
    MIN(ph.played_at) AS first_played_at,
    EXTRACT(EPOCH FROM (NOW() - MAX(ph.played_at))) / 86400 AS days_since_played
FROM songs s
LEFT JOIN play_history ph ON s.id = ph.song_id
GROUP BY s.id, s.spotify_id, s.title, s.artist;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_song_stats_song_id ON song_stats(song_id);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Songs table
CREATE INDEX IF NOT EXISTS idx_songs_spotify_id ON songs(spotify_id);
CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist);
CREATE INDEX IF NOT EXISTS idx_songs_added_at ON songs(added_at);
CREATE INDEX IF NOT EXISTS idx_songs_release_date ON songs(release_date);

-- Audio features
CREATE INDEX IF NOT EXISTS idx_audio_features_energy ON audio_features(energy);
CREATE INDEX IF NOT EXISTS idx_audio_features_valence ON audio_features(valence);
CREATE INDEX IF NOT EXISTS idx_audio_features_tempo ON audio_features(tempo);

-- Song metadata
CREATE INDEX IF NOT EXISTS idx_song_metadata_genre ON song_metadata(genre);
CREATE INDEX IF NOT EXISTS idx_song_metadata_mood ON song_metadata(mood);
CREATE INDEX IF NOT EXISTS idx_song_metadata_era ON song_metadata(era);
CREATE INDEX IF NOT EXISTS idx_song_metadata_energy ON song_metadata(energy_level);

-- Play history
CREATE INDEX IF NOT EXISTS idx_play_history_song_id ON play_history(song_id);
CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at);
CREATE INDEX IF NOT EXISTS idx_play_history_source ON play_history(source);

-- Playlist songs
CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist ON playlist_songs(playlist_id);
CREATE INDEX IF NOT EXISTS idx_playlist_songs_song ON playlist_songs(song_id);

-- Tags
CREATE INDEX IF NOT EXISTS idx_song_tags_song ON song_tags(song_id);
CREATE INDEX IF NOT EXISTS idx_song_tags_tag ON song_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_tags_type ON tags(tag_type);

-- =============================================================================
-- SEED DATA: Default Tags
-- =============================================================================

INSERT INTO tags (name, tag_type, color, description) VALUES
    -- Moods
    ('chill', 'mood', '#87CEEB', 'Relaxed, laid-back vibes'),
    ('energetic', 'mood', '#FF6B6B', 'High energy, upbeat'),
    ('melancholic', 'mood', '#6B5B95', 'Sad, emotional'),
    ('uplifting', 'mood', '#FFD93D', 'Happy, positive'),
    ('aggressive', 'mood', '#C41E3A', 'Intense, powerful'),
    ('romantic', 'mood', '#FF69B4', 'Love songs'),
    ('focus', 'mood', '#4ECDC4', 'Good for concentration'),
    ('party', 'mood', '#FF9F1C', 'Party/dance music'),
    ('peaceful', 'mood', '#98D8C8', 'Calm, serene'),
    ('nostalgic', 'mood', '#DDA0DD', 'Throwback vibes'),
    
    -- Activities
    ('workout', 'activity', '#E63946', 'Exercise music'),
    ('driving', 'activity', '#457B9D', 'Road trip vibes'),
    ('studying', 'activity', '#2A9D8F', 'Background study music'),
    ('sleeping', 'activity', '#264653', 'Sleep/relaxation'),
    ('cooking', 'activity', '#E9C46A', 'Kitchen vibes'),
    ('morning', 'activity', '#F4A261', 'Morning routine'),
    ('evening', 'activity', '#9B5DE5', 'Wind-down music'),
    
    -- Eras
    ('60s', 'era', '#FFB347', 'The Sixties'),
    ('70s', 'era', '#FF6961', 'The Seventies'),
    ('80s', 'era', '#77DD77', 'The Eighties'),
    ('90s', 'era', '#AEC6CF', 'The Nineties'),
    ('2000s', 'era', '#CB99C9', 'The Two-Thousands'),
    ('2010s', 'era', '#FDFD96', 'The Twenty-Tens'),
    ('2020s', 'era', '#84B6F4', 'The Twenty-Twenties')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- SEED DATA: Initial Sync State
-- =============================================================================

INSERT INTO sync_state (sync_type, status) VALUES
    ('spotify_likes', 'idle'),
    ('lastfm_scrobbles', 'idle'),
    ('audio_features', 'idle'),
    ('ai_analysis', 'idle')
ON CONFLICT (sync_type) DO NOTHING;

-- =============================================================================
-- SEED DATA: Default Managed Playlists
-- =============================================================================

INSERT INTO managed_playlists (name, description, playlist_type, update_frequency, query_rules, max_tracks) VALUES
    -- Dynamic playlists (daily updates)
    ('[Auto] Heavy Rotation', 
     'Your most played songs this month with low skip rate',
     'dynamic', 'daily',
     '{"order_by": "plays_last_30d DESC", "where": "skip_rate < 40", "limit": 30}',
     30),
    
    ('[Auto] On Repeat', 
     'Songs you''ve been playing on repeat this week',
     'dynamic', 'daily',
     '{"order_by": "plays_last_7d DESC", "where": "plays_last_7d >= 3", "limit": 25}',
     25),
    
    ('[Auto] Fresh Finds', 
     'Recently liked songs you''re enjoying',
     'dynamic', 'daily',
     '{"order_by": "added_at DESC", "where": "added_at > NOW() - INTERVAL ''30 days'' AND total_plays >= 2", "limit": 30}',
     30),
    
    -- Weekly updates
    ('[Auto] Rediscovered', 
     'Old favorites you''re listening to again',
     'dynamic', 'weekly',
     '{"where": "last_played_at < NOW() - INTERVAL ''6 months'' AND plays_last_7d >= 2", "limit": 25}',
     25),
    
    ('[Auto] Deep Cuts', 
     'Hidden gems in your library you rarely play',
     'dynamic', 'weekly',
     '{"where": "total_plays < 3 AND added_at < NOW() - INTERVAL ''6 months''", "limit": 40}',
     40),
    
    ('[Auto] Skip Jail', 
     'Songs you frequently skip - maybe time to unlike?',
     'dynamic', 'weekly',
     '{"order_by": "skip_rate DESC", "where": "skip_rate > 60 AND total_plays >= 5", "limit": 30}',
     30),
    
    -- Mood playlists
    ('[Auto] Chill Vibes', 
     'Relaxed, laid-back music',
     'mood', 'daily',
     '{"where": "mood IN (''chill'', ''peaceful'', ''relaxed'')", "limit": 50}',
     50),
    
    ('[Auto] Energy Boost', 
     'High-energy tracks to pump you up',
     'mood', 'daily',
     '{"where": "energy_level >= 8", "limit": 40}',
     40),
    
    ('[Auto] Focus Mode', 
     'Music for concentration',
     'mood', 'daily',
     '{"where": "mood = ''focus'' AND energy_level BETWEEN 4 AND 7", "limit": 40}',
     40),
    
    -- Curated (monthly)
    ('[Auto] Classics', 
     'Popular older tracks in your library',
     'curated', 'weekly',
     '{"where": "spotify_popularity > 70 AND release_date < ''2010-01-01''", "limit": 50}',
     50),
    
    ('[Auto] Hidden Gems', 
     'Underrated songs you love',
     'curated', 'weekly',
     '{"where": "spotify_popularity < 40 AND total_plays >= 10", "limit": 40}',
     40)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables with updated_at
DROP TRIGGER IF EXISTS update_songs_updated_at ON songs;
CREATE TRIGGER update_songs_updated_at
    BEFORE UPDATE ON songs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_managed_playlists_updated_at ON managed_playlists;
CREATE TRIGGER update_managed_playlists_updated_at
    BEFORE UPDATE ON managed_playlists
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_song_overrides_updated_at ON song_overrides;
CREATE TRIGGER update_song_overrides_updated_at
    BEFORE UPDATE ON song_overrides
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sync_state_updated_at ON sync_state;
CREATE TRIGGER update_sync_state_updated_at
    BEFORE UPDATE ON sync_state
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- REFRESH MATERIALIZED VIEW (call daily via n8n workflow)
-- =============================================================================

-- To refresh the song_stats view:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY song_stats;

-- =============================================================================
-- GRANT PERMISSIONS (run after creating user)
-- =============================================================================

-- These are run separately after database setup:
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO n8n;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO n8n;
-- GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO n8n;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO n8n;
