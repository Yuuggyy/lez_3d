-- ── SEED PRODUITS : Lez ──────────────────────────────
INSERT INTO public.restaurants (nom, slug)
VALUES ('Lez', 'lez')
ON CONFLICT (slug) DO NOTHING;

DO $$
DECLARE rid UUID;
BEGIN
  SELECT id INTO rid FROM public.restaurants WHERE slug = 'lez';
  INSERT INTO public.produits (restaurant_id, nom, description, prix, categorie, disponible) VALUES
    (rid, 'Veloute du Jour', 'Potage du moment, creme fraiche', 8.00, 'Entrees', true),
    (rid, 'Salade Mixte', 'Tomates, concombres, oignons rouges', 9.00, 'Entrees', true),
    (rid, 'Carpaccio de Boeuf', 'Roquette, parmesan, capres, huile d olive', 18.00, 'Entrees', true),
    (rid, 'Ailes de Poulet Epicees', '6 ailes, sauce dip maison', 9.00, 'Entrees', true),
    (rid, 'Riz au Poulet', 'Riz jaune, poulet mijote, epices', 12.00, 'Plats Principaux', true),
    (rid, 'Pondu', 'Feuilles de manioc mijotees, huile de palme', 10.00, 'Plats Principaux', true),
    (rid, 'Fufu au Gombo', 'Fufu de manioc, sauce gombo poisson', 10.00, 'Plats Principaux', true),
    (rid, 'Spaghetti Bolognaise', 'Pates, sauce viande hachee maison', 12.00, 'Plats Principaux', true),
    (rid, 'Poulet Roti', 'Demi-poulet roti, legumes du jour', 16.00, 'Plats Principaux', true),
    (rid, 'Poulet Braise', 'Poulet entier braise, epices locales', 14.00, 'Grillades', true),
    (rid, 'Poisson Braise', 'Tilapia braise au feu, citron, piment', 13.00, 'Grillades', true),
    (rid, 'Entrecote Grillee', '250g, sauce poivre, frites maison', 24.00, 'Grillades', true),
    (rid, 'Brochettes Boeuf', 'Brochettes marinees grillees, legumes', 16.00, 'Grillades', true),
    (rid, 'Fondant au Chocolat', 'Coulant, boule de glace vanille', 9.00, 'Desserts', true),
    (rid, 'Creme Brulee', NULL, 8.00, 'Desserts', true),
    (rid, 'Tiramisu', NULL, 9.00, 'Desserts', true),
    (rid, 'Cocktail Signature Le Z', 'Recette exclusive du bar Le Z', 9.00, 'Bar et Boissons', true),
    (rid, 'Vin Rouge (verre)', NULL, 8.00, 'Bar et Boissons', true),
    (rid, 'Mojito', NULL, 8.00, 'Bar et Boissons', true),
    (rid, 'Biere Primus 65cl', NULL, 4.00, 'Bar et Boissons', true),
    (rid, 'Jus Frais', 'Mangue, passion, ananas', 5.00, 'Bar et Boissons', true),
    (rid, 'Eau Minerale 75cl', NULL, 3.00, 'Bar et Boissons', true)
  ON CONFLICT DO NOTHING;
END $$;
