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

-- 7. Storage-Bucket für Medien-Dateien
-- Diese Konfiguration muss im Supabase Dashboard unter "Storage" durchgeführt werden

-- WICHTIG: Diese Schritte müssen manuell im Supabase Dashboard durchgeführt werden!

-- Schritt 1: Storage-Bucket erstellen
-- Gehe zu Storage > Buckets im Supabase Dashboard
-- Erstelle neuen Bucket mit Name: 'trip-media'
-- Eigenschaften:
--   - Public: true (für öffentliche URLs)
--   - File size limit: 10MB
--   - Allowed MIME types: image/jpeg, image/png, image/heif, image/webp

-- Schritt 2: Row-Level Security TEMPORÄR deaktivieren (für Tests)
-- Gehe zu Storage > Policies im Supabase Dashboard
-- Klicke auf "Disable RLS" für den trip-media Bucket
-- ACHTUNG: Das macht den Bucket öffentlich zugänglich!

-- Schritt 3: Für Production - Sichere Policies erstellen
-- Gehe zu Storage > Policies im Supabase Dashboard
-- Erstelle folgende Policies für den 'trip-media' Bucket:

-- Policy 1: "Allow uploads to trip cover images"
--   Operation: INSERT
--   Target roles: public
--   Policy definition: bucket_id = 'trip-media' AND (storage.foldername(name))[1] = 'cover_images'

-- Policy 2: "Allow public access to trip cover images"  
--   Operation: SELECT
--   Target roles: public
--   Policy definition: bucket_id = 'trip-media' AND (storage.foldername(name))[1] = 'cover_images'

-- Policy 3: "Allow updates to trip cover images"
--   Operation: UPDATE
--   Target roles: public  
--   Policy definition: bucket_id = 'trip-media' AND (storage.foldername(name))[1] = 'cover_images'

-- Policy 4: "Allow deletes of trip cover images"
--   Operation: DELETE
--   Target roles: public
--   Policy definition: bucket_id = 'trip-media' AND (storage.foldername(name))[1] = 'cover_images'

-- ====================
-- PRODUCTION-READY POLICIES (SQL-Befehle)
-- ====================

-- 1. RLS wieder aktivieren
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 2. Alte Policies löschen (falls vorhanden)
DROP POLICY IF EXISTS "Allow all operations on trip-media bucket" ON storage.objects;

-- 3. Sichere Policies erstellen
CREATE POLICY "Allow public upload of trip cover images" ON storage.objects
    FOR INSERT 
    TO public
    WITH CHECK (
        bucket_id = 'trip-media' 
        AND (storage.foldername(name))[1] = 'cover_images'
        AND (storage.foldername(name))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    );

CREATE POLICY "Allow public access to trip cover images" ON storage.objects
    FOR SELECT 
    TO public
    USING (
        bucket_id = 'trip-media' 
        AND (storage.foldername(name))[1] = 'cover_images'
    );

CREATE POLICY "Allow public update of trip cover images" ON storage.objects
    FOR UPDATE 
    TO public
    USING (
        bucket_id = 'trip-media' 
        AND (storage.foldername(name))[1] = 'cover_images'
    )
    WITH CHECK (
        bucket_id = 'trip-media' 
        AND (storage.foldername(name))[1] = 'cover_images'
    );

CREATE POLICY "Allow public delete of trip cover images" ON storage.objects
    FOR DELETE 
    TO public
    USING (
        bucket_id = 'trip-media' 
        AND (storage.foldername(name))[1] = 'cover_images'
    );

-- 4. Erfolgsmeldung
SELECT 'Storage-Policies erfolgreich konfiguriert!' as result;

-- 8. Erfolgsmeldung
SELECT 'Trip-Tabelle erfolgreich erstellt! Anzahl Einträge: ' || COUNT(*) as result FROM trips; 