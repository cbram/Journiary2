-- Supabase Schema für Journiary Trip-Synchronisation
-- Ausführen im SQL Editor des Supabase Dashboards

-- 1. Trip-Tabelle erstellen
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    trip_description TEXT,
    cover_image_url TEXT,
    travel_companions TEXT,
    visited_countries TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT false,
    total_distance DOUBLE PRECISION DEFAULT 0.0,
    gps_tracking_enabled BOOLEAN DEFAULT true,
    
    -- Sync-Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sync_version INTEGER DEFAULT 1,
    
    -- Für spätere User-Integration (erstmal NULL erlauben)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 2. Trigger für automatische updated_at Aktualisierung
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.sync_version = OLD.sync_version + 1;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_trips_updated_at 
    BEFORE UPDATE ON trips 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 3. Index für bessere Performance
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_updated_at ON trips(updated_at);
CREATE INDEX IF NOT EXISTS idx_trips_sync_version ON trips(sync_version);

-- 4. RLS (Row Level Security) aktivieren
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

-- 5. Policies für RLS (erstmal alle Operationen erlauben, später einschränken)
-- Temporäre Policy für Development (später durch User-spezifische Policies ersetzen)
CREATE POLICY "Enable all operations for development" ON trips
    FOR ALL USING (true)
    WITH CHECK (true);

-- Kommentare hinzufügen für Dokumentation
COMMENT ON TABLE trips IS 'Journiary Trip-Entitäten für iOS-App Synchronisation';
COMMENT ON COLUMN trips.sync_version IS 'Automatisch inkrementiert bei Updates für Konfliktauflösung';
COMMENT ON COLUMN trips.user_id IS 'Referenz auf auth.users - erstmal NULL für Development';

-- 6. Test-Daten einfügen (optional)
INSERT INTO trips (name, trip_description, start_date, is_active, total_distance) 
VALUES 
    ('Test-Reise Berlin', 'Eine Testfahrt durch Berlin', NOW() - INTERVAL '1 day', false, 12.5),
    ('Aktuelle Reise', 'Laufende Reise für Tests', NOW(), true, 0.0)
ON CONFLICT (id) DO NOTHING;

-- 7. Erfolgsmeldung
SELECT 'Trip-Tabelle erfolgreich erstellt! Anzahl Einträge: ' || COUNT(*) as result FROM trips; 