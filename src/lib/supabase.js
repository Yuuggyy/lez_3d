import { createClient } from '@supabase/supabase-js';

const supabaseUrl  = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ── Catégories & Produits ──
export const getCategories = () =>
  supabase.from('categories').select('*').eq('actif', true).order('ordre');

export const getProduits = () =>
  supabase.from('produits').select('*, categories(nom, emoji)').eq('disponible', true).order('ordre');

export const getProduitsByCategorie = (catId) =>
  supabase.from('produits').select('*').eq('categorie_id', catId).eq('disponible', true).order('ordre');

// ── Commandes ──
export const createCommande = async (numeroTable, items, demandesSpeciales) => {
  const montantTotal = items.reduce((sum, i) => sum + i.prix_unit * i.quantite, 0);
  const { data: cmd, error } = await supabase
    .from('commandes')
    .insert({ numero_table: numeroTable, demandes_speciales: demandesSpeciales, montant_total: montantTotal })
    .select().single();
  if (error) return { error };
  const lignes = items.map(i => ({
    commande_id: cmd.id,
    produit_id:  i.id,
    nom_produit: i.nom,
    prix_unit:   i.prix_unit,
    quantite:    i.quantite,
  }));
  const { error: err2 } = await supabase.from('commande_items').insert(lignes);
  return { data: cmd, error: err2 };
};

export const getCommandes = () =>
  supabase.from('commandes')
    .select('*, commande_items(*, produits(nom))')
    .order('created_at', { ascending: false });

export const updateStatutCommande = (id, statut) =>
  supabase.from('commandes').update({ statut }).eq('id', id);

export const deleteCommande = (id) =>
  supabase.from('commandes').delete().eq('id', id);

// ── Appel serveur ──
export const appelServeur = (numeroTable) =>
  supabase.from('appels_serveur').insert({ numero_table: numeroTable });

export const getAppels = () =>
  supabase.from('appels_serveur').select('*').order('created_at', { ascending: false });

export const traiterAppel = (id) =>
  supabase.from('appels_serveur').update({ traite: true }).eq('id', id);

// ── Admin Auth ──
export const signInAdmin  = (email, password) =>
  supabase.auth.signInWithPassword({ email, password });

export const signOutAdmin = () => supabase.auth.signOut();

// ── Produits Admin ──
export const getAllProduits = () =>
  supabase.from('produits').select('*, categories(nom)').order('ordre');

export const createProduit = (p) =>
  supabase.from('produits').insert(p).select().single();

export const updateProduit = (id, p) =>
  supabase.from('produits').update(p).eq('id', id);

export const deleteProduit = (id) =>
  supabase.from('produits').delete().eq('id', id);

// ── Catégories Admin ──
export const getAllCategories = () =>
  supabase.from('categories').select('*').order('ordre');

export const createCategorie = (c) =>
  supabase.from('categories').insert(c).select().single();

export const updateCategorie = (id, c) =>
  supabase.from('categories').update(c).eq('id', id);

export const deleteCategorie = (id) =>
  supabase.from('categories').delete().eq('id', id);

// ── Paramètres ──
export const getParametres = () =>
  supabase.from('parametres').select('*').eq('id', 1).single();

export const updateParametres = (data) =>
  supabase.from('parametres').update(data).eq('id', 1);

// ── Upload image ──
export const uploadImage = async (file, folder = 'logos') => {
  const ext = file.name.split('.').pop();
  const fileName = `${folder}/${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from('menu-images').upload(fileName, file, {
    cacheControl: '3600', upsert: true,
  });
  if (error) return { error };
  const { data } = supabase.storage.from('menu-images').getPublicUrl(fileName);
  return { data: { publicUrl: data.publicUrl } };
};
