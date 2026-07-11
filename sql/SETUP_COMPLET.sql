-- ============================================================
-- O POETA — SETUP COMPLET (UN SEUL SCRIPT, UNE SEULE FOIS)
-- Copier-coller en entier dans Supabase > SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 1 : PURGE TOTALE
-- ────────────────────────────────────────────────────────────
SET session_replication_role = replica;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
  LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
  )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;
END $$;

SET session_replication_role = DEFAULT;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 2 : EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 3 : TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE public.categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom         TEXT NOT NULL,
  description TEXT,
  emoji       TEXT DEFAULT '🍽️',
  ordre       INTEGER DEFAULT 0,
  actif       BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.produits (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  categorie_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  nom          TEXT NOT NULL,
  description  TEXT,
  prix         NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url    TEXT,
  disponible   BOOLEAN DEFAULT true,
  ordre        INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commandes (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table       TEXT NOT NULL,
  statut             TEXT NOT NULL DEFAULT 'recue'
                       CHECK (statut IN ('recue', 'en_cours', 'terminee', 'annulee')),
  demandes_speciales TEXT,
  montant_total      NUMERIC(10,2) DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.commande_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commande_id UUID NOT NULL REFERENCES public.commandes(id) ON DELETE CASCADE,
  produit_id  UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  nom_produit TEXT NOT NULL,
  prix_unit   NUMERIC(10,2) NOT NULL,
  quantite    INTEGER NOT NULL DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.appels_serveur (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero_table TEXT NOT NULL,
  message      TEXT DEFAULT 'Un client demande le serveur',
  traite       BOOLEAN DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.admin_profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  nom        TEXT,
  role       TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.parametres (
  id             INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nom_restaurant TEXT DEFAULT 'Le Z',
  logo_url       TEXT,
  adresse        TEXT DEFAULT 'Immeuble Matrix, 8ème étage, 119 Boulevard du 30 Juin, Gombe, Kinshasa',
  telephone      TEXT DEFAULT '+243 828 664 628',
  whatsapp       TEXT DEFAULT '243828664628',
  horaires       TEXT DEFAULT 'Mardi - Dimanche 12h00 - 22h30',
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 4 : FONCTIONS ET TRIGGERS
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_produits_updated_at
  BEFORE UPDATE ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_commandes_updated_at
  BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_parametres_updated_at
  BEFORE UPDATE ON public.parametres
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger : crée automatiquement un profil admin quand un user s'inscrit
CREATE OR REPLACE FUNCTION public.handle_new_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_profiles (id, email, nom)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'nom', 'Admin'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin();

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 5 : RLS (UN SEUL BLOC, SANS AMBIGUÏTÉ)
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appels_serveur  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parametres      ENABLE ROW LEVEL SECURITY;

-- CATÉGORIES : lecture publique, écriture admin
CREATE POLICY "cat_select"  ON public.categories FOR SELECT USING (true);
CREATE POLICY "cat_insert"  ON public.categories FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_update"  ON public.categories FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cat_delete"  ON public.categories FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PRODUITS : lecture publique, écriture admin
CREATE POLICY "prod_select" ON public.produits FOR SELECT USING (true);
CREATE POLICY "prod_insert" ON public.produits FOR INSERT WITH CHECK (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_update" ON public.produits FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "prod_delete" ON public.produits FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDES : insertion SANS connexion, gestion admin
CREATE POLICY "cmd_insert"  ON public.commandes FOR INSERT WITH CHECK (true);
CREATE POLICY "cmd_select"  ON public.commandes FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_update"  ON public.commandes FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "cmd_delete"  ON public.commandes FOR DELETE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- COMMANDE ITEMS : insertion SANS connexion, lecture admin
CREATE POLICY "item_insert" ON public.commande_items FOR INSERT WITH CHECK (true);
CREATE POLICY "item_select" ON public.commande_items FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- APPELS SERVEUR : insertion SANS connexion, gestion admin
CREATE POLICY "appel_insert" ON public.appels_serveur FOR INSERT WITH CHECK (true);
CREATE POLICY "appel_select" ON public.appels_serveur FOR SELECT USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "appel_update" ON public.appels_serveur FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- PARAMÈTRES : lecture publique, écriture admin
CREATE POLICY "param_select" ON public.parametres FOR SELECT USING (true);
CREATE POLICY "param_update" ON public.parametres FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ADMIN PROFILES : accès propre uniquement
CREATE POLICY "ap_select" ON public.admin_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "ap_update" ON public.admin_profiles FOR UPDATE USING (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 6 : STORAGE BUCKET
-- ────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('menu-images', 'menu-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "img_select" ON storage.objects;
DROP POLICY IF EXISTS "img_insert" ON storage.objects;
DROP POLICY IF EXISTS "img_update" ON storage.objects;
DROP POLICY IF EXISTS "img_delete" ON storage.objects;
DROP POLICY IF EXISTS "lecture_publique_images" ON storage.objects;
DROP POLICY IF EXISTS "upload_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "update_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "delete_admin_images" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_select_all" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_update_admin" ON storage.objects;
DROP POLICY IF EXISTS "menu_images_delete_admin" ON storage.objects;

CREATE POLICY "img_select" ON storage.objects FOR SELECT USING (bucket_id = 'menu-images');
CREATE POLICY "img_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_update" ON storage.objects FOR UPDATE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "img_delete" ON storage.objects FOR DELETE USING (bucket_id = 'menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 7 : DONNÉES PAR DÉFAUT
-- ────────────────────────────────────────────────────────────

INSERT INTO public.parametres (id, nom_restaurant, adresse, telephone, whatsapp, horaires)
VALUES (1, 'Le Z', 'Immeuble Matrix, 8ème étage, 119 Boulevard du 30 Juin, Gombe, Kinshasa', '+243 828 664 628', '243828664628', 'Mardi - Dimanche 12h00 - 22h30')
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 8 : BACKFILL ADMIN (pour compte existant avant le trigger)
-- ────────────────────────────────────────────────────────────

INSERT INTO public.admin_profiles (id, email, nom)
SELECT id, email, COALESCE(raw_user_meta_data->>'nom', 'Admin')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- ÉTAPE 9 : MENU LE Z (restaurant lounge, 8e etage - Blvd 30 Juin)
INSERT INTO public.categories (nom, description, emoji, ordre, actif) VALUES
('Entrees','Entrees legeres et raffinees','🥗',1,true),
('Plats Principaux','Cuisine locale et internationale','🍽️',2,true),
('Grillades','Viandes et poissons grilles','🔥',3,true),
('Desserts','Patisseries et douceurs','🍰',4,true),
('Bar et Boissons','Vins, cocktails, bieres, softs','🍸',5,true)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, disponible, ordre) VALUES
('Veloute du Jour','Potage du moment, creme fraiche',8.00,(SELECT id FROM categories WHERE nom='Entrees'),true,1),
('Salade Mixte','Tomates, concombres, oignons rouges',9.00,(SELECT id FROM categories WHERE nom='Entrees'),true,2),
('Carpaccio de Boeuf','Roquette, parmesan, capres, huile d olive',18.00,(SELECT id FROM categories WHERE nom='Entrees'),true,3),
('Ailes de Poulet Epicees','6 ailes, sauce dip maison',9.00,(SELECT id FROM categories WHERE nom='Entrees'),true,4),
('Riz au Poulet','Riz jaune, poulet mijote, epices',12.00,(SELECT id FROM categories WHERE nom='Plats Principaux'),true,1),
('Pondu','Feuilles de manioc mijotees, huile de palme',10.00,(SELECT id FROM categories WHERE nom='Plats Principaux'),true,2),
('Fufu au Gombo','Fufu de manioc, sauce gombo poisson',10.00,(SELECT id FROM categories WHERE nom='Plats Principaux'),true,3),
('Spaghetti Bolognaise','Pates, sauce viande hachee maison',12.00,(SELECT id FROM categories WHERE nom='Plats Principaux'),true,4),
('Poulet Roti','Demi-poulet roti, legumes du jour',16.00,(SELECT id FROM categories WHERE nom='Plats Principaux'),true,5),
('Poulet Braise','Poulet entier braise, epices locales',14.00,(SELECT id FROM categories WHERE nom='Grillades'),true,1),
('Poisson Braise','Tilapia braise au feu, citron, piment',13.00,(SELECT id FROM categories WHERE nom='Grillades'),true,2),
('Entrecote Grillee','250g, sauce poivre, frites maison',24.00,(SELECT id FROM categories WHERE nom='Grillades'),true,3),
('Brochettes Boeuf','Brochettes marinees grillees, legumes',16.00,(SELECT id FROM categories WHERE nom='Grillades'),true,4),
('Fondant au Chocolat','Coulant, boule de glace vanille',9.00,(SELECT id FROM categories WHERE nom='Desserts'),true,1),
('Creme Brulee',NULL,8.00,(SELECT id FROM categories WHERE nom='Desserts'),true,2),
('Tiramisu',NULL,9.00,(SELECT id FROM categories WHERE nom='Desserts'),true,3),
('Cocktail Signature Le Z','Recette exclusive du bar Le Z',9.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,1),
('Vin Rouge (verre)',NULL,8.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,2),
('Mojito',NULL,8.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,3),
('Biere Primus 65cl',NULL,4.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,4),
('Jus Frais','Mangue, passion, ananas',5.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,5),
('Eau Minerale 75cl',NULL,3.00,(SELECT id FROM categories WHERE nom='Bar et Boissons'),true,6)
ON CONFLICT DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- VÉRIFICATION FINALE
-- ────────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM public.categories) AS nb_categories,
  (SELECT count(*) FROM public.produits)   AS nb_produits,
  (SELECT count(*) FROM public.admin_profiles) AS nb_admins,
  'Setup terminé OK' AS status;
