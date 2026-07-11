-- PARAMÈTRES RESTAURANT Le Z
CREATE TABLE IF NOT EXISTS public.parametres (
  id             INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  nom_restaurant TEXT DEFAULT 'Le Z',
  logo_url       TEXT,
  adresse        TEXT DEFAULT 'Immeuble Matrix, 8ème étage, 119 Boulevard du 30 Juin, Gombe, Kinshasa',
  telephone      TEXT DEFAULT '+243 828 664 628',
  whatsapp       TEXT DEFAULT '243828664628',
  horaires       TEXT DEFAULT 'Mardi - Dimanche 12h00 - 22h30',
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO public.parametres (id, nom_restaurant, adresse, telephone, whatsapp, horaires)
VALUES (1, 'Le Z', 'Immeuble Matrix, 8ème étage, 119 Boulevard du 30 Juin, Gombe, Kinshasa', '+243 828 664 628', '243828664628', 'Mardi - Dimanche 12h00 - 22h30')
ON CONFLICT (id) DO NOTHING;
CREATE TRIGGER trg_parametres_updated_at BEFORE UPDATE ON public.parametres FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
ALTER TABLE public.parametres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "param_select" ON public.parametres FOR SELECT USING (true);
CREATE POLICY "param_update" ON public.parametres FOR UPDATE USING (auth.uid() IN (SELECT id FROM public.admin_profiles));
SELECT 'Le Z — paramètres OK' AS status;
