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
-- ÉTAPE 9 : MENU O POETA (10 catégories, 130+ plats)
-- ────────────────────────────────────────────────────────────

INSERT INTO public.categories (nom, description, emoji, ordre, actif) VALUES
('Entrées - Antipasti',       'Entrées et antipasti italiens',        '🥗', 1, true),
('Salades',                   'Salades composées',                    '🥬', 2, true),
('Pâtes',                     'Pâtes simples',                        '🍝', 3, true),
('Pâtes, Gnocchi et Risotto', 'Pâtes fraîches, gnocchi et risottos',  '🍚', 4, true),
('Pizzas au Feu de Bois',     'Pizzas cuites au feu de bois',         '🍕', 5, true),
('Viandes et Volailles',      'Viandes grillées et volailles',        '🥩', 6, true),
('Poissons et Crustacés',     'Poissons et fruits de mer',            '🐟', 7, true),
('Sauces et Accompagnements', 'Sauces et garnitures',                 '🍟', 8, true),
('Desserts',                  'Douceurs et desserts italiens',        '🍰', 9, true),
('Cocktails et Boissons',     'Cocktails, vins et boissons fraîches', '🍹', 10, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Assiettes de Spécialités Italiennes', 'Légumes grillés, charcuterie', 26.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 1),
('Carpaccio de Bœuf roquette et Parmesan', NULL, 24.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 2),
('Avocat vinaigrette',  NULL, 13.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 3),
('Avocat crevettes grises', NULL, 26.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 4),
('Jambon de Parme et melon', NULL, 26.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 5),
('Cocktail de Crevettes', NULL, 22.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 6),
('Carpaccio de Capitaine', NULL, 20.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 7),
('Tartare de Saumon al Fresco', NULL, 25.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 8),
('Saumon fumé et ses accompagnements', NULL, 26.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 9),
('Cossas ail et piment', NULL, 18.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 10),
('Cuisses de Grenouille à l''ail', NULL, 22.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 11),
('Calamare Fritti',     NULL, 22.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 12),
('Scampi Fritti',       NULL, 22.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 13),
('Eperlan Fritti (Ndakala)', '100gr', 14.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 14),
('Parmigiana',          'Aubergines gratinées', 22.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 15),
('Mêlée de Champignons et Cossas au Basilic', NULL, 23.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 16),
('Minestrone',          NULL, 13.00, (SELECT id FROM categories WHERE nom='Entrées - Antipasti'), NULL, true, 17)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Salade Roquette et Parmesan', NULL, 20.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 1),
('Burrata alla Caprese', 'Tomates, pignons, basilic', 26.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 2),
('Salade Niçoise',      'Thon, œufs, olives, tomates, anchois', 22.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 3),
('Salade Chèvre',       'Chèvre, pommes, raisins secs, granola', 22.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 4),
('Salade Avé Cesare',   'Poulet, avocat, parmesan', 22.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 5),
('Salade Mixte',        'Tomates, concombres, oignons', 20.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 6),
('Salade Italienne',    'Tomates, olives, roquette, jambon de Parme', 22.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 7),
('Salade au Foie Gras', 'Foie gras, figues, poires, pain d''épices', 26.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 8),
('Salade Océane',       'Saumon fumé, crevettes, tomates, chicon, cœur de palmier', 26.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 9),
('Salade Halloumi',     'Tomates, menthe, oignons, courgettes grillées, halloumi', 26.00, (SELECT id FROM categories WHERE nom='Salades'), NULL, true, 10)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Nature',              NULL, 13.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 1),
('Pesto',               'Pignons, basilic', 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 2),
('Carbonara',           'Lardons, œuf, crème fraîche', 25.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 3),
('Pomodoro',            'Tomate', 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 4),
('Bolognese',           'Ragoût de bœuf', 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 5),
('Arrabbiata',          'Tomate, pili', 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 6),
('Puttanesca',          'Anchois, thon, câpres, tomates, olive noire', 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 7),
('Quattro Formaggi',    NULL, 20.00, (SELECT id FROM categories WHERE nom='Pâtes'), NULL, true, 8)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Spaghetti Crudaiola', 'Tomate fraîche froide, mozzarella, roquette, pesto', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 1),
('Spaghetti al Pollo',  'Poulet, champignons, crème fraîche', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 2),
('Penne Saumon Fumé, Crème', NULL, 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 3),
('Spaghetti ai Frutti di Mare', 'Fruits de mer', 34.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 4),
('Spaghetti alle Vongole', 'Coquillages', 34.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 5),
('Spaghetti ai Cartoccio', 'Fruits de mer, sauce tomate', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 6),
('Penne Foie Gras',     NULL, 34.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 7),
('Tagliatelle Primavera', 'Tomate fraîche, champignons, courgettes', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 8),
('Tagliatelle ai Funghi', 'Cèpes, crème fraîche', 28.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 9),
('Tagliatelle Mare e Monti', 'Champignons, petit pois, courgettes, cossa, tomates', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 10),
('Lasagna Maison',      'Bœuf', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 11),
('Ravioli Maison Carne', 'Bœuf, ou Spinaci e Ricotta, ou Cèpes (Solo, Duo ou Trio)', 26.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 12),
('Gnocchi',             'Sauce au choix', 28.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 13),
('Risotto ai Funghi ou al San Daniele', 'Cèpes, ou jambon San Daniele', 28.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 14),
('Risotto façon Paella', 'Riz safran, fruits de mer, saucisse de bœuf', 28.00, (SELECT id FROM categories WHERE nom='Pâtes, Gnocchi et Risotto'), NULL, true, 15)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Focaccia',            'Sel, épices', 12.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 1),
('Margherita',          'Tomate, mozzarella, origan', 22.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 2),
('Prosciutto',          'Tomate, mozzarella, jambon, champignons, olives vertes', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 3),
('Calzone',             'Tomate, mozzarella, jambon, parmesan + un ingrédient au choix', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 4),
('Diavola',             'Tomate, poivrons, mozzarella, salami piquant, olives', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 5),
('Tonino',              'Tomate, mozzarella, thon, oignons, olives', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 6),
('Hawaïenne',           'Tomate, mozzarella, jambon, ananas', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 7),
('Vegetariana',         'Tomates fraîches, mozzarella, champignons, oignons, olives, légumes grillés', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 8),
('Polo',                'Tomate, mozzarella, poulet', 23.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 9),
('Salmone',             'Crème fraîche, mozzarella, saumon fumé, aneth', 26.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 10),
('Reggiana',            'Tomate, mozzarella, parmesan, roquette, jambon de Parme', 26.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 11),
('Porcini',             'Crème fraîche, mozzarella, cèpes', 26.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 12),
('Pollo e Peperoni',    'Crème fraîche, mozzarella, poulet, poivrons', 26.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 13),
('Scampi',              'Crème fraîche, mozzarella, scampi', 29.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 14),
('Cossas',              'Crème fraîche, mozzarella, ail, cossas (écrevisses)', 26.00, (SELECT id FROM categories WHERE nom='Pizzas au Feu de Bois'), NULL, true, 15)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Filet de Bœuf grillé', 'Sauce au choix', 38.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 1),
('Entrecôte grillée',   'Sauce au choix', 34.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 2),
('Côte de Bœuf (350gr)', 'Sauce au choix', 45.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 3),
('Brochette de Bœuf',   NULL, 28.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 4),
('Escalope de Veau',    'Sauce au choix', 32.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 5),
('Côte de Veau grillée', 'Sauce au choix', 34.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 6),
('Piccata de Veau',     'Sauce citron, câpres', 32.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 7),
('Saltimbocca alla Romana', 'Veau, jambon de Parme, sauge, vin blanc', 34.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 8),
('Poulet grillé',       'Sauce au choix', 24.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 9),
('Brochette de Poulet', NULL, 22.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 10),
('Poulet à la Diable',  'Mariné, grillé, épices', 26.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 11),
('Côtelettes d''Agneau', 'Sauce au choix', 38.00, (SELECT id FROM categories WHERE nom='Viandes et Volailles'), NULL, true, 12)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Capitaine grillé',    'Sauce au choix', 28.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 1),
('Saumon grillé',       'Sauce au choix', 34.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 2),
('Dorade grillée',      'Sauce au choix', 30.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 3),
('Sole meunière',       'Beurre, citron', 30.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 4),
('Crevettes grillées',  'Sauce au choix', 32.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 5),
('Langoustines grillées', NULL, 38.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 6),
('Homard grillé',       'Sauce au choix', 55.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 7),
('Calamars grillés',    NULL, 28.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 8),
('Brochette de Fruits de Mer', 'Crevettes, calamars, poisson', 32.00, (SELECT id FROM categories WHERE nom='Poissons et Crustacés'), NULL, true, 9)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Sauce Béarnaise',     NULL, 5.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 1),
('Sauce Poivre',        NULL, 5.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 2),
('Sauce Champignons',   NULL, 5.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 3),
('Sauce Roquefort',     NULL, 5.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 4),
('Frites',              NULL, 8.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 5),
('Légumes grillés',     NULL, 9.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 6),
('Riz',                 NULL, 7.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 7),
('Gratin dauphinois',   NULL, 9.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 8),
('Épinards à la crème', NULL, 8.00, (SELECT id FROM categories WHERE nom='Sauces et Accompagnements'), NULL, true, 9)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Tiramisu Maison',     NULL, 12.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 1),
('Panna Cotta',         'Coulis de fruits rouges', 10.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 2),
('Profiteroles',        'Glace vanille, sauce chocolat', 12.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 3),
('Crème Brûlée',        NULL, 10.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 4),
('Salade de Fruits Frais', NULL, 10.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 5),
('Glaces et Sorbets',   '2 boules au choix', 8.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 6),
('Fondant au Chocolat', 'Coulant, glace vanille', 12.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 7),
('Mousse au Chocolat',  NULL, 10.00, (SELECT id FROM categories WHERE nom='Desserts'), NULL, true, 8)
ON CONFLICT DO NOTHING;

INSERT INTO public.produits (nom, description, prix, categorie_id, image_url, disponible, ordre) VALUES
('Bière Primus',        '65cl', 4.00,  (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 1),
('Bière Turbo King',    '65cl', 4.00,  (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 2),
('Bière Doppel',        '33cl', 4.00,  (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 3),
('Bière importée',      '33cl', 5.00,  (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 4),
('Vin rouge / blanc',   'Verre', 8.00, (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 5),
('Jus de fruit frais',  NULL, 6.00,   (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 6),
('Cocktail Maison',     NULL, 10.00,  (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 7),
('Cappuccino',          NULL, 5.00,   (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 8),
('Espresso',            NULL, 3.00,   (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 9),
('Soda / Eau Gazeuse',  NULL, 3.00,   (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 10),
('Eau Plate 75cl',      NULL, 3.00,   (SELECT id FROM categories WHERE nom='Cocktails et Boissons'), NULL, true, 11)
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- VÉRIFICATION FINALE
-- ────────────────────────────────────────────────────────────
SELECT
  (SELECT count(*) FROM public.categories) AS nb_categories,
  (SELECT count(*) FROM public.produits)   AS nb_produits,
  (SELECT count(*) FROM public.admin_profiles) AS nb_admins,
  'Setup O Poeta terminé OK' AS status;
