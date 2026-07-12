-- ============================================
-- SETUP COMPLET — MENU 3D MULTI-RESTAURANTS
-- Un seul fichier. Exécuter dans Supabase > SQL Editor
-- ============================================

-- ── 0. PURGE COMPLÈTE ──────────────────────────────────────────────
SET session_replication_role = replica;

DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
            FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public') LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;
END $$;

DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT typname FROM pg_type WHERE typnamespace = 'public'::regnamespace AND typtype = 'e') LOOP
    EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
  END LOOP;
END $$;

SET session_replication_role = DEFAULT;


-- ── 1. EXTENSIONS ──────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ── 2. FONCTION UPDATED_AT ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;


-- ── 3. TABLE RESTAURANTS ───────────────────────────────────────────
CREATE TABLE public.restaurants (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug        TEXT UNIQUE NOT NULL,
  nom         TEXT NOT NULL,
  description TEXT,
  adresse     TEXT,
  telephone   TEXT,
  logo_url    TEXT,
  couleur     TEXT DEFAULT '#c9a84c',
  actif       BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER trg_restaurants_updated_at
  BEFORE UPDATE ON public.restaurants
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 4. CATEGORIES ──────────────────────────────────────────────────
CREATE TABLE public.categories (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  nom           TEXT NOT NULL,
  description   TEXT,
  emoji         TEXT DEFAULT '🍽️',
  ordre         INTEGER DEFAULT 0,
  actif         BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_categories_resto ON public.categories(restaurant_id);


-- ── 5. PRODUITS ────────────────────────────────────────────────────
CREATE TABLE public.produits (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  categorie_id  UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  nom           TEXT NOT NULL,
  description   TEXT,
  prix          NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url     TEXT,
  disponible    BOOLEAN DEFAULT true,
  ordre         INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_produits_resto ON public.produits(restaurant_id);
CREATE INDEX idx_produits_cat   ON public.produits(categorie_id);

CREATE TRIGGER trg_produits_updated_at
  BEFORE UPDATE ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 6. COMMANDES ───────────────────────────────────────────────────
CREATE TABLE public.commandes (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id      UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  numero_table       TEXT NOT NULL,
  statut             TEXT NOT NULL DEFAULT 'recue'
                       CHECK (statut IN ('recue','en_cours','terminee','annulee')),
  demandes_speciales TEXT,
  montant_total      NUMERIC(10,2) DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_commandes_resto ON public.commandes(restaurant_id);

CREATE TRIGGER trg_commandes_updated_at
  BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 7. COMMANDE ITEMS ──────────────────────────────────────────────
CREATE TABLE public.commande_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commande_id UUID NOT NULL REFERENCES public.commandes(id) ON DELETE CASCADE,
  produit_id  UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  nom_produit TEXT NOT NULL,
  prix_unit   NUMERIC(10,2) NOT NULL,
  quantite    INTEGER NOT NULL DEFAULT 1,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_items_commande ON public.commande_items(commande_id);


-- ── 8. APPELS SERVEUR ──────────────────────────────────────────────
CREATE TABLE public.appels_serveur (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  numero_table  TEXT NOT NULL,
  message       TEXT DEFAULT 'Un client demande le serveur',
  traite        BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_appels_resto ON public.appels_serveur(restaurant_id);


-- ── 9. ADMIN PROFILES ──────────────────────────────────────────────
CREATE TABLE public.admin_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE SET NULL,
  email         TEXT NOT NULL,
  nom           TEXT,
  role          TEXT DEFAULT 'admin',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.handle_new_admin()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.admin_profiles (id, email, nom)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'nom','Admin'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin();


-- ── 10. RLS ────────────────────────────────────────────────────────
ALTER TABLE public.restaurants    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes      DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appels_serveur ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

-- Lecture publique
CREATE POLICY "pub_restaurants" ON public.restaurants FOR SELECT USING (actif = true);
CREATE POLICY "pub_categories"  ON public.categories  FOR SELECT USING (actif = true);
CREATE POLICY "pub_produits"    ON public.produits    FOR SELECT USING (disponible = true);

-- Clients : peuvent passer commande et appeler serveur
-- (supprimé) insert_commandes — RLS désactivée sur commandes
CREATE POLICY "insert_items"     ON public.commande_items FOR INSERT WITH CHECK (true);
CREATE POLICY "insert_appels"    ON public.appels_serveur FOR INSERT WITH CHECK (true);

-- Admin : accès complet via service_role ou uid admin
CREATE POLICY "admin_restaurants"  ON public.restaurants    FOR ALL USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "admin_categories"   ON public.categories     FOR ALL USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "admin_produits"     ON public.produits       FOR ALL USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
-- (supprimé) admin_commandes_r — RLS désactivée sur commandes
-- (supprimé) admin_commandes_u — RLS désactivée sur commandes
CREATE POLICY "admin_items_r"      ON public.commande_items FOR SELECT USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "admin_appels_r"     ON public.appels_serveur FOR SELECT USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "admin_appels_u"     ON public.appels_serveur FOR UPDATE USING (auth.role()='service_role' OR auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "admin_profiles_pol" ON public.admin_profiles FOR ALL USING (auth.role()='service_role' OR auth.uid() = id);


-- ── 11. STORAGE ────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public) VALUES ('menu-images','menu-images',true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "pub_images"    ON storage.objects FOR SELECT USING (bucket_id='menu-images');
CREATE POLICY "upload_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id='menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "update_images" ON storage.objects FOR UPDATE USING (bucket_id='menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));
CREATE POLICY "delete_images" ON storage.objects FOR DELETE USING (bucket_id='menu-images' AND auth.uid() IN (SELECT id FROM public.admin_profiles));


-- ══════════════════════════════════════════════════════════════════
-- 12. SEED : 14 RESTAURANTS + MENUS RÉELS
-- ══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  -- IDs restaurants
  r_leroyal        UUID; r_bigbite       UUID; r_kiros          UUID;
  r_reineducossa   UUID; r_chezfanny     UUID; r_joker          UUID;
  r_kwetu          UUID; r_lecentre      UUID; r_tiptop         UUID;
  r_lez            UUID; r_chilllounge   UUID; r_flamboyant     UUID;
  r_110street      UUID; r_chikshake     UUID;
  -- IDs catégories (réutilisés)
  cat1 UUID; cat2 UUID; cat3 UUID; cat4 UUID; cat5 UUID;
BEGIN

-- ─────────────────────────────────────────────────────────────────
-- 1. LE ROYAL (fast-food, burgers, fruits de mer — Sozacom)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('leroyal','Le Royal','Fast-food & fruits de mer. Burgers, frittes, poissons.',
        '3-1 Blvd du 30 juin, Immeuble SOZACOM, Gombe, Kinshasa','+243 830 050 050','#8B0000')
RETURNING id INTO r_leroyal;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_leroyal,'Burgers','🍔',1),(r_leroyal,'Frittes & Accompagnements','🍟',2),
  (r_leroyal,'Fruits de mer','🦐',3),(r_leroyal,'Boissons','🥤',4)
RETURNING id INTO cat1; -- ne retourne que le dernier, on va chercher par nom

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_leroyal AND nom='Burgers';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_leroyal AND nom='Frittes & Accompagnements';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_leroyal AND nom='Fruits de mer';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_leroyal AND nom='Boissons';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_leroyal,cat1,'Classic Burger',5.00),(r_leroyal,cat1,'Royal Beef Burger',7.00),
  (r_leroyal,cat1,'Cheese Burger',6.00),(r_leroyal,cat1,'Chicken Burger',5.50),
  (r_leroyal,cat2,'Frittes',2.50),(r_leroyal,cat2,'Frittes spéciales',3.50),
  (r_leroyal,cat3,'Poisson frit',8.00),(r_leroyal,cat3,'Crevettes grillées',12.00),
  (r_leroyal,cat3,'Plateau fruits de mer',18.00),
  (r_leroyal,cat4,'Coca Cola',2.00),(r_leroyal,cat4,'Jus naturel',2.50),(r_leroyal,cat4,'Eau minérale',1.00);


-- ─────────────────────────────────────────────────────────────────
-- 2. BIG BITE (fast-food, tacos, shawarma, pizza tortilla)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('bigbite','Big Bite','Tacos, shawarma, pizza tortilla, ailes de poulet.',
        'Kinshasa Mall, Kinshasa','+243 900 341 111','#FF4500')
RETURNING id INTO r_bigbite;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_bigbite,'Tacos','🌮',1),(r_bigbite,'Shawarma & Sandwich','🥙',2),
  (r_bigbite,'Pizza Tortilla','🍕',3),(r_bigbite,'Menus Famille','👨‍👩‍👧',4),
  (r_bigbite,'Menus Individuels','🍱',5),(r_bigbite,'Boissons','🥤',6);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_bigbite AND nom='Tacos';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_bigbite AND nom='Shawarma & Sandwich';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_bigbite AND nom='Pizza Tortilla';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_bigbite AND nom='Menus Famille';
SELECT id INTO cat5 FROM public.categories WHERE restaurant_id=r_bigbite AND nom='Menus Individuels';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,description,prix) VALUES
  (r_bigbite,cat1,'Tacos Poulet Combo','Tacos poulet + boisson + frites',13.77),
  (r_bigbite,cat1,'Tacos Viande Combo','Tacos viande + boisson + frites',13.77),
  (r_bigbite,cat1,'Mexican Tacos Sandwich','Tacos mexicain sauce épicée',9.38),
  (r_bigbite,cat2,'Shawarma Viande Sandwich','Pain pita, viande, sauce maison',5.27),
  (r_bigbite,cat2,'Shawarma Poulet Sandwich','Pain pita, poulet, légumes',5.27),
  (r_bigbite,cat2,'Twister Combo','Rouleau poulet + boisson',11.25),
  (r_bigbite,cat3,'Margherita Tortilla Pizza','Tomate, mozzarella',9.02),
  (r_bigbite,cat3,'Pepperoni Tortilla Pizza','Pepperoni, fromage',9.96),
  (r_bigbite,cat4,'Crispy Super Famille','Poulet croustillant x8 + frites + boissons',47.47),
  (r_bigbite,cat4,'Bucket Meal Famille','Bucket poulet + accompagnements',45.71),
  (r_bigbite,cat5,'Crispy Burger Promo','Burger + coca + frites + 3pcs poulet',10.43),
  (r_bigbite,cat5,'Mini Crispy Meal','Mini bucket individuel',9.14);


-- ─────────────────────────────────────────────────────────────────
-- 3. KIROS (libanais, méditerranéen, petit-déjeuner)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('kiros','Kiros Restaurant','Cuisine libanaise & méditerranéenne. Petit-déjeuner, pizzas, viandes.',
        '22 Avenue Rep Du Congo, Gombe, Kinshasa','+243 999 123 456','#2E8B57')
RETURNING id INTO r_kiros;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_kiros,'Petit-déjeuner','☕',1),(r_kiros,'Plats','🍖',2),
  (r_kiros,'Pizzas','🍕',3),(r_kiros,'Desserts','🎂',4),(r_kiros,'Boissons','🥤',5);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_kiros AND nom='Petit-déjeuner';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_kiros AND nom='Plats';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_kiros AND nom='Pizzas';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_kiros AND nom='Desserts';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_kiros,cat1,'Œufs brouillés & fatteh',8.00),(r_kiros,cat1,'Croissant',1.00),
  (r_kiros,cat1,'Petit-déjeuner complet',12.00),
  (r_kiros,cat2,'Steak grillé',15.00),(r_kiros,cat2,'Viande au four',20.00),
  (r_kiros,cat2,'Boulettes de viande sauce tomate',15.00),(r_kiros,cat2,'Poulet rôti',18.00),
  (r_kiros,cat3,'Pizza Margherita',25.00),(r_kiros,cat3,'Pizza Viande',28.00),
  (r_kiros,cat4,'Gâteau maison',6.00),(r_kiros,cat4,'Crème brûlée',7.00);


-- ─────────────────────────────────────────────────────────────────
-- 4. REINE DU COSSA (spécialiste crevettes/cossas — fruits de mer)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('reineducossa','La Reine du Cossa','Spécialiste des cossas (crevettes géantes) et fruits de mer.',
        'Avenue Milambo N°5, Rond-point Safricas, Gombe, Kinshasa','+243 856 646 098','#006994')
RETURNING id INTO r_reineducossa;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_reineducossa,'Cossas (Signature)','🦐',1),(r_reineducossa,'Poissons','🐟',2),
  (r_reineducossa,'Accompagnements','🍚',3),(r_reineducossa,'Boissons','🥤',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_reineducossa AND nom='Cossas (Signature)';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_reineducossa AND nom='Poissons';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_reineducossa AND nom='Accompagnements';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,description,prix) VALUES
  (r_reineducossa,cat1,'Cassolette de cossas sauce teriyaki','Cossas poêlés, sauce teriyaki maison',30.00),
  (r_reineducossa,cat1,'Cassolette de cossas aux légumes sautés','Cossas & légumes de saison',35.00),
  (r_reineducossa,cat1,'Tempura de cossas sauce tartare','Cossas en tempura, sauce tartare maison',28.00),
  (r_reineducossa,cat1,'Cossas grillés nature','Cossas grillés, citron & piment',25.00),
  (r_reineducossa,cat1,'Brochettes de cossas','Brochettes marinées au gingembre',22.00),
  (r_reineducossa,cat2,'Tilapia braisé sauce piment','Poisson entier, piment & tomates',15.00),
  (r_reineducossa,cat2,'Capitaine grillé','Grand poisson du fleuve',20.00),
  (r_reineducossa,cat3,'Riz blanc','',3.00),(r_reineducossa,cat3,'Plantain frit','',3.00),
  (r_reineducossa,cat3,'Pondu (saka-saka)','Feuilles de manioc mijotées',4.00);


-- ─────────────────────────────────────────────────────────────────
-- 5. CHEZ FANNY (cuisine congolaise, buffet, 7j/7)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('chezfanny','Chez Fanny','Cuisine congolaise authentique. Buffet et plats à la carte. 7j/7.',
        '5 Avenue de la Montagne, Ngaliema, Kinshasa','+243 975 286 614','#8B4513')
RETURNING id INTO r_chezfanny;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_chezfanny,'Plats Congolais','🇨🇩',1),(r_chezfanny,'Viandes & Grillades','🥩',2),
  (r_chezfanny,'Accompagnements','🍚',3),(r_chezfanny,'Boissons','🥤',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_chezfanny AND nom='Plats Congolais';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_chezfanny AND nom='Viandes & Grillades';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_chezfanny AND nom='Accompagnements';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,description,prix) VALUES
  (r_chezfanny,cat1,'Soso ya mwamba','Poulet au mwamba (plat national)',12.00),
  (r_chezfanny,cat1,'Pondu au poisson','Feuilles de manioc, poisson fumé',10.00),
  (r_chezfanny,cat1,'Makayabu (morue salée)','Morue préparée à la congolaise',11.00),
  (r_chezfanny,cat1,'Fufu au gombo','Fufu de manioc, sauce gombo',8.00),
  (r_chezfanny,cat2,'Poulet braisé','Poulet entier mariné, braisé au feu de bois',14.00),
  (r_chezfanny,cat2,'Ngolo braisé','Porc braisé, sauce locale',13.00),
  (r_chezfanny,cat2,'Poisson braisé','Tilapia ou capitaine braisé',12.00),
  (r_chezfanny,cat3,'Riz blanc',3.00),(r_chezfanny,cat3,'Plantain frit',3.00),
  (r_chezfanny,cat3,'Kwanga (pain de manioc)',2.00);


-- ─────────────────────────────────────────────────────────────────
-- 6. JOKER (lounge-bar-restaurant — Ngaliema/UPN)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('joker','Joker Restaurant & Bar','Lounge, bar, live vibes. Cuisine locale & internationale.',
        '08 Avenue Masikita, Ngaliema/UPN, Q. Ngomba Kikusa, Kinshasa','','#6A0DAD')
RETURNING id INTO r_joker;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_joker,'Entrées','🥗',1),(r_joker,'Plats','🍽️',2),
  (r_joker,'Bar & Cocktails','🍸',3),(r_joker,'Desserts','🍰',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_joker AND nom='Entrées';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_joker AND nom='Plats';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_joker AND nom='Bar & Cocktails';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_joker,cat1,'Salade mixte',6.00),(r_joker,cat1,'Ailes de poulet x6',8.00),
  (r_joker,cat2,'Poulet braisé complet',14.00),(r_joker,cat2,'Riz au gras viande',10.00),
  (r_joker,cat2,'Steak bœuf sauce champignons',18.00),(r_joker,cat2,'Poisson frit',12.00),
  (r_joker,cat3,'Cocktail maison',6.00),(r_joker,cat3,'Bière locale',3.00),
  (r_joker,cat3,'Whisky Joker Special',10.00),(r_joker,cat3,'Jus frais',3.00);


-- ─────────────────────────────────────────────────────────────────
-- 7. KWETU (cuisine congolaise & africaine, buffet weekend)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('kwetu','Kwetu Restaurant','Cuisine africaine & congolaise. Nyama choma, buffet weekend.',
        '88 Avenue Nguma 3, Macampagne, Kinshasa','+243 999 919 871','#228B22')
RETURNING id INTO r_kwetu;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_kwetu,'Grillades (Nyama Choma)','🔥',1),(r_kwetu,'Plats Congolais','🇨🇩',2),
  (r_kwetu,'Buffet (Weekend)','🍽️',3),(r_kwetu,'Boissons','🥤',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_kwetu AND nom='Grillades (Nyama Choma)';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_kwetu AND nom='Plats Congolais';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_kwetu AND nom='Buffet (Weekend)';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_kwetu,cat1,'Nyama Choma (viande grillée)',15.00),(r_kwetu,cat1,'Poulet grillé entier',14.00),
  (r_kwetu,cat1,'Poisson braisé',12.00),(r_kwetu,cat1,'Côtelettes de porc grillées',13.00),
  (r_kwetu,cat2,'Pondu au poisson fumé',10.00),(r_kwetu,cat2,'Soso ya mwamba',12.00),
  (r_kwetu,cat2,'Fufu de manioc',3.00),(r_kwetu,cat2,'Liboke de poisson',14.00),
  (r_kwetu,cat3,'Buffet complet (weekend)','',20.00);


-- ─────────────────────────────────────────────────────────────────
-- 8. LE CENTRE (pizza, fruits de mer, cuisine internationale)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('lecentre','Le Centre','Pizza, fruits de mer, cuisine internationale. Vue panoramique.',
        'Rond-point Forescom, Immeuble SEDEC, 2e étage, Gombe, Kinshasa','+243 843 000 003','#1E90FF')
RETURNING id INTO r_lecentre;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_lecentre,'Pizzas','🍕',1),(r_lecentre,'Fruits de mer','🦞',2),
  (r_lecentre,'Grillades','🥩',3),(r_lecentre,'Salades','🥗',4),(r_lecentre,'Boissons','🥤',5);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_lecentre AND nom='Pizzas';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_lecentre AND nom='Fruits de mer';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_lecentre AND nom='Grillades';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_lecentre AND nom='Salades';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_lecentre,cat1,'Pizza Margherita',18.00),(r_lecentre,cat1,'Pizza 4 Fromages',22.00),
  (r_lecentre,cat1,'Pizza Fruits de mer',25.00),(r_lecentre,cat1,'Pizza Mixte',20.00),
  (r_lecentre,cat2,'Plateau fruits de mer (2 pers)',45.00),(r_lecentre,cat2,'Crevettes sautées',25.00),
  (r_lecentre,cat2,'Homard grillé',40.00),(r_lecentre,cat2,'Calamars frits',18.00),
  (r_lecentre,cat3,'Entrecôte grillée',28.00),(r_lecentre,cat3,'Poulet rôti au four',18.00),
  (r_lecentre,cat4,'Salade César',10.00),(r_lecentre,cat4,'Salade niçoise',12.00);


-- ─────────────────────────────────────────────────────────────────
-- 9. TIP TOP (buffet, braisé, cuisine locale)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('tiptop','Tip Top','Buffet et grillades. Poulet braisé, poisson, spaghetti.',
        'Kinshasa','','#DAA520')
RETURNING id INTO r_tiptop;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_tiptop,'Braisés & Grillades','🔥',1),(r_tiptop,'Plats du Buffet','🍽️',2),
  (r_tiptop,'Accompagnements','🍚',3),(r_tiptop,'Boissons','🥤',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_tiptop AND nom='Braisés & Grillades';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_tiptop AND nom='Plats du Buffet';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_tiptop AND nom='Accompagnements';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_tiptop,cat1,'Porc braisé',12.00),(r_tiptop,cat1,'Ailes de poulet braisées',10.00),
  (r_tiptop,cat1,'Tilapia frit',11.00),(r_tiptop,cat1,'Ngolo braisé',12.00),
  (r_tiptop,cat2,'Buffet du jour (entrée + plat + dessert)',15.00),
  (r_tiptop,cat2,'Poulet mayo',8.00),(r_tiptop,cat2,'Spaghetti bolognaise',9.00),
  (r_tiptop,cat2,'Riz au gras au poulet',10.00),
  (r_tiptop,cat3,'Riz jaune',3.00),(r_tiptop,cat3,'Plantain',3.00),(r_tiptop,cat3,'Salade',3.00);


-- ─────────────────────────────────────────────────────────────────
-- 10. LEZ (à définir — cuisine locale)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('lez','Lez Restaurant','Cuisine locale & grillades.',
        'Kinshasa','','#c9a84c')
RETURNING id INTO r_lez;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_lez,'Plats','🍽️',1),(r_lez,'Grillades','🔥',2),(r_lez,'Boissons','🥤',3);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_lez AND nom='Plats';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_lez AND nom='Grillades';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_lez,cat1,'Riz au poulet',10.00),(r_lez,cat1,'Pondu',8.00),(r_lez,cat1,'Fufu gombo',8.00),
  (r_lez,cat2,'Poulet braisé',12.00),(r_lez,cat2,'Poisson braisé',11.00);


-- ─────────────────────────────────────────────────────────────────
-- 11. CHILL LOUNGE (bar-restaurant, cocktails, plats, Macampagne)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('chilllounge','Chill Lounge Bar & Restaurant','Bar & restaurant. Cocktails, plats, ambiance lounge. 10h-23h.',
        'Croisement Allée Verte et Joli Parc, Place Commerciale de Macampagne, Kinshasa','','#4B0082')
RETURNING id INTO r_chilllounge;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_chilllounge,'Cocktails & Bar','🍸',1),(r_chilllounge,'Entrées','🥗',2),
  (r_chilllounge,'Plats','🍽️',3),(r_chilllounge,'Snacks','🍟',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_chilllounge AND nom='Cocktails & Bar';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_chilllounge AND nom='Entrées';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_chilllounge AND nom='Plats';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_chilllounge AND nom='Snacks';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_chilllounge,cat1,'Chill Cocktail Spécial',7.00),(r_chilllounge,cat1,'Mojito',6.00),
  (r_chilllounge,cat1,'Bière locale',3.00),(r_chilllounge,cat1,'Jus frais',3.00),
  (r_chilllounge,cat2,'Salade d''avocat',6.00),(r_chilllounge,cat2,'Ailes de poulet',8.00),
  (r_chilllounge,cat3,'Poulet braisé & riz',13.00),(r_chilllounge,cat3,'Tilapia frit',12.00),
  (r_chilllounge,cat3,'Pâtes bolognaise',10.00),
  (r_chilllounge,cat4,'Frittes',3.00),(r_chilllounge,cat4,'Samoussa x4',5.00);


-- ─────────────────────────────────────────────────────────────────
-- 12. FLAMBOYANT (restaurant-lounge, cuisine locale & internationale)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('flamboyant','Flamboyant Restaurant & Lounge','Cuisine locale & internationale. Buffet dîner 40$. Bar.',
        '14 Avenue de la Mongala, Gombe, Kinshasa','+243 819 555 339','#FF6347')
RETURNING id INTO r_flamboyant;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_flamboyant,'Entrées Gourmandes','🥗',1),(r_flamboyant,'Plats Principaux','🍖',2),
  (r_flamboyant,'Desserts','🍰',3),(r_flamboyant,'Bar & Boissons','🍹',4);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_flamboyant AND nom='Entrées Gourmandes';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_flamboyant AND nom='Plats Principaux';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_flamboyant AND nom='Desserts';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_flamboyant AND nom='Bar & Boissons';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_flamboyant,cat1,'Velouté de légumes',7.00),(r_flamboyant,cat1,'Carpaccio de bœuf',12.00),
  (r_flamboyant,cat2,'Buffet complet dîner','Entrées + plat + dessert',40.00),
  (r_flamboyant,cat2,'Entrecôte sauce poivre',28.00),(r_flamboyant,cat2,'Poulet rôti aux herbes',20.00),
  (r_flamboyant,cat2,'Poisson du jour',22.00),(r_flamboyant,cat2,'Risotto aux champignons',18.00),
  (r_flamboyant,cat3,'Tiramisu maison',8.00),(r_flamboyant,cat3,'Fondant chocolat',7.00),
  (r_flamboyant,cat4,'Cocktail signature',9.00),(r_flamboyant,cat4,'Vin rouge (verre)',8.00);


-- ─────────────────────────────────────────────────────────────────
-- 13. 110 STREET (burgers, sandwichs, salades, plats)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('110street','110 Street International Diner','Burgers, sandwichs, salades, plats internationaux.',
        '110 Croisement Blvd 30 Juin & Blvd 24 Novembre, Gombe, Kinshasa','+243 900 110 110','#DC143C')
RETURNING id INTO r_110street;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_110street,'Burgers','🍔',1),(r_110street,'Sandwichs','🥪',2),
  (r_110street,'Salades','🥗',3),(r_110street,'Plats','🍽️',4),
  (r_110street,'Desserts','🍰',5),(r_110street,'Boissons','🥤',6);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_110street AND nom='Burgers';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_110street AND nom='Sandwichs';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_110street AND nom='Salades';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_110street AND nom='Plats';
SELECT id INTO cat5 FROM public.categories WHERE restaurant_id=r_110street AND nom='Desserts';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_110street,cat1,'Classic Burger',8.00),(r_110street,cat1,'Cheese Burger Chicken',9.00),
  (r_110street,cat1,'Cheese Burger Beef',10.00),(r_110street,cat1,'Double Smash Burger',13.00),
  (r_110street,cat2,'Sandwich Poulet grillé',7.00),(r_110street,cat2,'Club Sandwich',8.00),
  (r_110street,cat3,'Salade César',9.00),(r_110street,cat3,'Salade Grecque',9.00),
  (r_110street,cat4,'Pâtes Alfredo',12.00),(r_110street,cat4,'Poulet sauce curry',14.00),
  (r_110street,cat5,'Brownie',5.00),(r_110street,cat5,'Glace maison',4.00);


-- ─────────────────────────────────────────────────────────────────
-- 14. CHIK SHAKE (poulet croustillant, shakes, burgers — Galleria)
-- ─────────────────────────────────────────────────────────────────
INSERT INTO public.restaurants (slug,nom,description,adresse,telephone,couleur)
VALUES ('chikshake','Chic Shake','Poulet croustillant, milkshakes, burgers. Expérience fun.',
        'Galleria Mall, 3e étage, Avenue Colonel Lukasa, Kinshasa','+243 810 420 001','#FF1493')
RETURNING id INTO r_chikshake;

INSERT INTO public.categories (restaurant_id,nom,emoji,ordre) VALUES
  (r_chikshake,'Poulet Croustillant','🍗',1),(r_chikshake,'Burgers','🍔',2),
  (r_chikshake,'Milkshakes','🥛',3),(r_chikshake,'Accompagnements','🍟',4),(r_chikshake,'Boissons','🥤',5);

SELECT id INTO cat1 FROM public.categories WHERE restaurant_id=r_chikshake AND nom='Poulet Croustillant';
SELECT id INTO cat2 FROM public.categories WHERE restaurant_id=r_chikshake AND nom='Burgers';
SELECT id INTO cat3 FROM public.categories WHERE restaurant_id=r_chikshake AND nom='Milkshakes';
SELECT id INTO cat4 FROM public.categories WHERE restaurant_id=r_chikshake AND nom='Accompagnements';

INSERT INTO public.produits (restaurant_id,categorie_id,nom,prix) VALUES
  (r_chikshake,cat1,'Crispy Chicken Box (4pcs)',10.00),(r_chikshake,cat1,'Crispy Chicken Box (8pcs)',18.00),
  (r_chikshake,cat1,'Crispy Chicken Sandwich',9.00),(r_chikshake,cat1,'Ailes croustillantes x12',15.00),
  (r_chikshake,cat2,'Cheese Burger Chicken',9.00),(r_chikshake,cat2,'Cheese Burger Beef',10.00),
  (r_chikshake,cat2,'Double Smash Burger',13.00),
  (r_chikshake,cat3,'Milkshake Vanille',6.00),(r_chikshake,cat3,'Milkshake Chocolat',6.00),
  (r_chikshake,cat3,'Milkshake Fraise',6.00),(r_chikshake,cat3,'Milkshake Oreo',7.00),
  (r_chikshake,cat4,'Frittes dorées',3.00),(r_chikshake,cat4,'Coleslaw',2.50),(r_chikshake,cat4,'Onion Rings',4.00);

END $$;


SELECT 'Setup complet — 14 restaurants + menus créés ✅' AS status;
