import { createClient } from '@supabase/supabase-js';
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const supabase = createClient(supabaseUrl, supabaseAnonKey);
export const signInAdmin = (email, password) => supabase.auth.signInWithPassword({ email, password });
export const signOutAdmin = () => supabase.auth.signOut();
