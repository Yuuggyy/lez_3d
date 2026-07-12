import { useState, useEffect } from 'react';
import {
  signInAdmin, signOutAdmin,
  getCommandes, updateStatutCommande, deleteCommande,
  getAppels, traiterAppel,
  getAllProduits, getAllCategories,
  createProduit, updateProduit, deleteProduit,
  createCategorie, updateCategorie, deleteCategorie,
  getParametres, updateParametres, uploadImage,
} from '../lib/supabase';
import { supabase } from '../lib/supabase';

const STATUTS = ['recue', 'en_cours', 'terminee', 'annulee'];
const STATUT_LABELS = { recue: '📬 Reçue', en_cours: '🔥 En cours', terminee: '✅ Terminée', annulee: '❌ Annulée' };
const STATUT_NEXT   = { recue: 'en_cours', en_cours: 'terminee' };

const C = {
  primary:     '#1A1A1A',
  primaryMid:  '#2D2D2D',
  gold:        '#C9A96E',
  goldLight:   '#DFC090',
  beige:       '#F5F0E8',
  cream:       '#FAFAFA',
  dark:        '#0A0A0A',
  darkSoft:    'rgba(0,0,0,0.50)',
  border:      'rgba(0,0,0,0.10)',
  success:     '#1E8449',
  danger:      '#C0392B',
  warning:     '#D4891A',
};

function LoginForm({ onLogin }) {
  const [email, setEmail] = useState('');
  const [pwd, setPwd]     = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault(); setError(''); setLoading(true);
    const { data, error } = await signInAdmin(email, pwd);
    setLoading(false);
    if (error) { setError(error.message); return; }
    onLogin(data.user);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: `linear-gradient(160deg, ${C.dark} 0%, ${C.primary} 60%, ${C.primaryMid} 100%)`,
      padding: 20,
    }}>
      <div style={{ width: '100%', maxWidth: 420 }}>
        <div style={{ textAlign: 'center', marginBottom: 44 }}>
          <div style={{ width: 80, height: 80, borderRadius: '50%', margin: '0 auto 20px',
            background: `linear-gradient(135deg, ${C.gold}, ${C.goldLight})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 8px 32px rgba(0,0,0,0.30)`,
          }}>
            <span style={{ fontSize: 36 }}>🍷</span>
          </div>
          <h1 style={{ fontSize: 32, fontWeight: 700, color: '#F5F0E8', letterSpacing: '0.04em' }}>
            Lez
          </h1>
          <p style={{ color: C.gold, fontSize: 13, marginTop: 6, letterSpacing: '0.12em', textTransform: 'uppercase' }}>
            Espace Administration
          </p>
        </div>
        <div style={{ background: 'rgba(255,255,255,0.04)', backdropFilter: 'blur(12px)',
          borderRadius: 20, padding: 36, border: '1px solid rgba(255,255,255,0.12)',
          boxShadow: '0 20px 60px rgba(0,0,0,0.35)',
        }}>
          <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            {['Email', 'Mot de passe'].map((lbl, i) => (
              <div key={lbl}>
                <label style={{ display: 'block', fontSize: 11, fontWeight: 600, color: C.gold,
                  textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 8 }}>{lbl}</label>
                <input type={i === 0 ? 'email' : 'password'}
                  value={i === 0 ? email : pwd}
                  onChange={e => i === 0 ? setEmail(e.target.value) : setPwd(e.target.value)}
                  required autoFocus={i === 0}
                  style={{ width: '100%', padding: '13px 16px',
                    background: 'rgba(255,255,255,0.07)', border: '1.5px solid rgba(255,255,255,0.15)',
                    borderRadius: 12, color: '#F5F0E8', fontSize: 15, fontFamily: 'inherit', outline: 'none',
                  }}
                />
              </div>
            ))}
            {error && <div style={{ background: 'rgba(192,57,43,0.15)', border: '1px solid rgba(192,57,43,0.4)', borderRadius: 10, padding: '10px 14px', color: '#FF7961', fontSize: 13 }}>⚠️ {error}</div>}
            <button type="submit" disabled={loading} style={{
              marginTop: 8, padding: 14, borderRadius: 12, border: 'none', cursor: loading ? 'wait' : 'pointer',
              background: `linear-gradient(135deg, ${C.gold}, ${C.goldLight})`,
              color: '#fff', fontSize: 15, fontWeight: 700,
              boxShadow: '0 4px 20px rgba(0,0,0,0.25)',
            }}>
              {loading ? '⏳ Connexion…' : '🔐 Se connecter'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

function CommandesTab() {
  const [commandes, setCommandes] = useState([]);
  const [loading, setLoading]     = useState(true);
  const [filtre, setFiltre]       = useState('all');

  const load = async () => {
    setLoading(true);
    const { data } = await getCommandes();
    setCommandes(data || []);
    setLoading(false);
  };

  useEffect(() => { load(); const iv = setInterval(load, 15000); return () => clearInterval(iv); }, []);

  const nextStatut = async (cmd) => {
    const next = STATUT_NEXT[cmd.statut];
    if (!next) return;
    await updateStatutCommande(cmd.id, next);
    load();
  };

  const handleDelete = async (cmd) => {
    if (!confirm('Supprimer cette commande ?')) return;
    await deleteCommande(cmd.id);
    load();
  };

  const filtered = filtre === 'all' ? commandes : commandes.filter(c => c.statut === filtre);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24, flexWrap: 'wrap', gap: 12 }}>
        <h2 style={{ fontSize: 24, color: C.primary, fontWeight: 700 }}>📋 Commandes</h2>
        <button onClick={load} style={{ padding: '8px 16px', borderRadius: 8, border: `1px solid ${C.border}`, background: 'transparent', color: C.primary, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>🔄 Actualiser</button>
      </div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {['all', ...STATUTS].map(s => (
          <button key={s} onClick={() => setFiltre(s)} style={{
            padding: '6px 14px', borderRadius: 20,
            border: `1.5px solid ${filtre === s ? C.gold : C.border}`,
            background: filtre === s ? `linear-gradient(135deg, ${C.gold}, ${C.goldLight})` : 'transparent',
            color: filtre === s ? '#fff' : C.darkSoft,
            fontSize: 12, fontWeight: 600, cursor: 'pointer',
          }}>{s === 'all' ? 'Toutes' : STATUT_LABELS[s]}</button>
        ))}
      </div>
      {loading ? <div style={{ display:'flex', justifyContent:'center', padding:60 }}><div className="spinner"/></div>
      : filtered.length === 0 ? <div style={{ textAlign:'center', padding:60, color:C.darkSoft }}><div style={{fontSize:48,marginBottom:12}}>🍽️</div><p>Aucune commande</p></div>
      : <div style={{ display:'flex', flexDirection:'column', gap:12 }}>
        {filtered.map(cmd => (
          <div key={cmd.id} style={{ background:'#fff', borderRadius:14, padding:'18px 20px',
            border:`1px solid ${C.border}`, boxShadow:'0 2px 10px rgba(0,0,0,0.05)',
            display:'flex', flexDirection:'column', gap:10 }}>
            <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', flexWrap:'wrap', gap:8 }}>
              <div style={{ display:'flex', gap:10, alignItems:'center' }}>
                <span style={{ fontWeight:700, fontSize:16, color:C.primary }}>Table {cmd.numero_table}</span>
                <span style={{ background: cmd.statut==='recue' ? `rgba(0,0,0,0.07)` : cmd.statut==='terminee' ? 'rgba(30,132,73,0.12)' : 'rgba(0,0,0,0.07)',
                  color: cmd.statut==='terminee' ? C.success : cmd.statut==='annulee' ? C.danger : C.dark,
                  padding:'3px 10px', borderRadius:20, fontSize:12, fontWeight:600 }}>
                  {STATUT_LABELS[cmd.statut]}
                </span>
              </div>
              <span style={{ fontSize:18, fontWeight:800, color:C.gold }}>{cmd.total?.toFixed(2)} $</span>
            </div>
            {cmd.notes && <p style={{fontSize:13,color:C.warning,fontStyle:'italic'}}>💬 {cmd.notes}</p>}
            <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
              {STATUT_NEXT[cmd.statut] && <button onClick={()=>nextStatut(cmd)} style={{ padding:'7px 14px', borderRadius:8, border:'none', cursor:'pointer',
                background:`linear-gradient(135deg,${C.primary},${C.primaryMid})`, color:'#F5F0E8', fontSize:12, fontWeight:600 }}>
                → {STATUT_LABELS[STATUT_NEXT[cmd.statut]]}
              </button>}
              <button onClick={()=>handleDelete(cmd)} style={{ padding:'7px 14px', borderRadius:8, cursor:'pointer',
                background:'rgba(192,57,43,0.08)', border:'1px solid rgba(192,57,43,0.2)', color:C.danger, fontSize:12, fontWeight:600 }}>
                🗑️ Supprimer
              </button>
            </div>
          </div>
        ))}
      </div>}
    </div>
  );
}

function AppelsTab() {
  const [appels, setAppels] = useState([]);
  const [loading, setLoading] = useState(true);
  const load = async () => { setLoading(true); const {data} = await getAppels(); setAppels(data||[]); setLoading(false); };
  useEffect(() => { load(); const iv = setInterval(load,10000); return ()=>clearInterval(iv); }, []);
  const handleTraiter = async (id) => { await traiterAppel(id); load(); };
  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:24, flexWrap:'wrap', gap:12 }}>
        <h2 style={{ fontSize:24, color:C.primary, fontWeight:700 }}>🔔 Appels serveur</h2>
        <button onClick={load} style={{ padding:'8px 16px', borderRadius:8, border:`1px solid ${C.border}`, background:'transparent', color:C.primary, cursor:'pointer', fontSize:13, fontWeight:600 }}>🔄</button>
      </div>
      {loading ? <div style={{display:'flex',justifyContent:'center',padding:60}}><div className="spinner"/></div>
      : appels.length===0 ? <div style={{textAlign:'center',padding:60,color:C.darkSoft}}><div style={{fontSize:48,marginBottom:12}}>🔕</div><p>Aucun appel</p></div>
      : <div style={{display:'flex',flexDirection:'column',gap:10}}>
        {appels.map(a => (
          <div key={a.id} style={{background:'#fff',borderRadius:14,padding:'16px 20px',
            border:`1.5px solid ${a.traite ? C.border : C.gold}`,
            display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',gap:12}}>
            <div>
              <span style={{fontWeight:700,color:C.primary}}>Table {a.numero_table}</span>
              {a.message && <p style={{fontSize:13,color:C.darkSoft,marginTop:4}}>{a.message}</p>}
            </div>
            {!a.traite && <button onClick={()=>handleTraiter(a.id)} style={{padding:'8px 16px',borderRadius:8,border:'none',cursor:'pointer',
              background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,color:'#fff',fontSize:13,fontWeight:600}}>✅ Traité</button>}
            {a.traite && <span style={{fontSize:12,color:C.success}}>✅ Traité</span>}
          </div>
        ))}
      </div>}
    </div>
  );
}

function ProduitsTab() {
  const [produits,setProduits]=useState([]); const [categories,setCategories]=useState([]);
  const [loading,setLoading]=useState(true); const [form,setForm]=useState(null); const [saving,setSaving]=useState(false);
  const load=async()=>{setLoading(true);const[{data:p},{data:c}]=await Promise.all([getAllProduits(),getAllCategories()]);setProduits(p||[]);setCategories(c||[]);setLoading(false);};
  useEffect(()=>{load();},[]);
  const openNew=()=>setForm({nom:'',description:'',prix:'',categorie_id:'',disponible:true});
  const openEdit=(p)=>setForm({...p,prix:p.prix?.toString()||''});
  const handleSave=async()=>{if(!form.nom||!form.prix)return;setSaving(true);const payload={nom:form.nom,description:form.description,prix:parseFloat(form.prix),categorie_id:form.categorie_id||null,disponible:form.disponible};if(form.id)await updateProduit(form.id,payload);else await createProduit(payload);setSaving(false);setForm(null);load();};
  const handleDelete=async(p)=>{if(!confirm('Supprimer "'+p.nom+'" ?'))return;await deleteProduit(p.id);load();};
  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:24,flexWrap:'wrap',gap:12}}>
        <h2 style={{fontSize:24,color:C.primary,fontWeight:700}}>🍽️ Produits</h2>
        <button onClick={openNew} style={{padding:'9px 18px',borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.primary},${C.primaryMid})`,color:'#F5F0E8',fontSize:13,fontWeight:600}}>+ Ajouter</button>
      </div>
      {loading?<div style={{display:'flex',justifyContent:'center',padding:60}}><div className="spinner"/></div>
      :<div style={{display:'flex',flexDirection:'column',gap:8}}>
        {produits.map(p=>(
          <div key={p.id} style={{background:'#fff',borderRadius:12,padding:'14px 18px',border:`1px solid ${C.border}`,display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',gap:10}}>
            <div>
              <span style={{fontWeight:600,color:C.dark}}>{p.nom}</span>
              {p.description&&<p style={{fontSize:12,color:C.darkSoft,marginTop:2}}>{p.description}</p>}
              <p style={{fontSize:13,color:C.gold,fontWeight:700,marginTop:4}}>{p.prix} $</p>
            </div>
            <div style={{display:'flex',gap:8,alignItems:'center'}}>
              <span style={{fontSize:12,padding:'3px 10px',borderRadius:20,background:p.disponible?'rgba(30,132,73,0.10)':'rgba(192,57,43,0.10)',color:p.disponible?C.success:C.danger}}>{p.disponible?'✅ Dispo':'❌ Indispo'}</span>
              <button onClick={()=>openEdit(p)} style={{padding:'6px 12px',borderRadius:8,border:`1px solid ${C.border}`,background:'transparent',color:C.primary,cursor:'pointer',fontSize:12}}>✏️</button>
              <button onClick={()=>handleDelete(p)} style={{padding:'6px 12px',borderRadius:8,border:'1px solid rgba(192,57,43,0.2)',background:'rgba(192,57,43,0.06)',color:C.danger,cursor:'pointer',fontSize:12}}>🗑️</button>
            </div>
          </div>
        ))}
      </div>}
      {form&&(
        <div style={{position:'fixed',inset:0,background:'rgba(0,0,0,0.45)',backdropFilter:'blur(4px)',display:'flex',alignItems:'center',justifyContent:'center',zIndex:1000,padding:20}}>
          <div style={{background:'#fff',borderRadius:20,padding:32,width:'100%',maxWidth:480,boxShadow:'0 20px 60px rgba(0,0,0,0.2)'}}>
            <h3 style={{fontSize:22,color:C.primary,marginBottom:24}}>{form.id?'✏️ Modifier':'+ Nouveau produit'}</h3>
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Nom *</label>
                <input value={form.nom} onChange={e=>setForm({...form,nom:e.target.value})} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit'}}/></div>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Description</label>
                <textarea value={form.description||''} onChange={e=>setForm({...form,description:e.target.value})} rows={2} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit',resize:'vertical'}}/></div>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Prix ($) *</label>
                <input type="number" step="0.01" value={form.prix} onChange={e=>setForm({...form,prix:e.target.value})} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit'}}/></div>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Catégorie</label>
                <select value={form.categorie_id||''} onChange={e=>setForm({...form,categorie_id:e.target.value})} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit',background:'#fff'}}>
                  <option value="">— Sans catégorie —</option>
                  {categories.map(c=><option key={c.id} value={c.id}>{c.nom}</option>)}
                </select></div>
              <label style={{display:'flex',alignItems:'center',gap:10,cursor:'pointer'}}>
                <input type="checkbox" checked={form.disponible} onChange={e=>setForm({...form,disponible:e.target.checked})}/>
                <span style={{fontSize:14,color:C.dark}}>Disponible</span>
              </label>
            </div>
            <div style={{display:'flex',gap:10,marginTop:24}}>
              <button onClick={()=>setForm(null)} style={{flex:1,padding:12,borderRadius:10,border:`1px solid ${C.border}`,background:'transparent',cursor:'pointer',color:C.darkSoft,fontWeight:600}}>Annuler</button>
              <button onClick={handleSave} disabled={saving} style={{flex:2,padding:12,borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,color:'#fff',fontWeight:700}}>{saving?'⏳…':'💾 Enregistrer'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CategoriesTab() {
  const [categories,setCategories]=useState([]); const [loading,setLoading]=useState(true);
  const [form,setForm]=useState(null); const [saving,setSaving]=useState(false);
  const load=async()=>{setLoading(true);const{data}=await getAllCategories();setCategories(data||[]);setLoading(false);};
  useEffect(()=>{load();},[]);
  const openNew=()=>setForm({nom:'',description:'',emoji:'',ordre:0});
  const openEdit=(c)=>setForm({...c});
  const handleSave=async()=>{if(!form.nom)return;setSaving(true);if(form.id)await updateCategorie(form.id,{nom:form.nom,description:form.description,emoji:form.emoji,ordre:parseInt(form.ordre)||0});else await createCategorie({nom:form.nom,description:form.description,emoji:form.emoji,ordre:parseInt(form.ordre)||0});setSaving(false);setForm(null);load();};
  const handleDelete=async(c)=>{if(!confirm('Supprimer "'+c.nom+'" ?'))return;await deleteCategorie(c.id);load();};
  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:24,flexWrap:'wrap',gap:12}}>
        <h2 style={{fontSize:24,color:C.primary,fontWeight:700}}>📂 Catégories</h2>
        <button onClick={openNew} style={{padding:'9px 18px',borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.primary},${C.primaryMid})`,color:'#F5F0E8',fontSize:13,fontWeight:600}}>+ Ajouter</button>
      </div>
      {loading?<div style={{display:'flex',justifyContent:'center',padding:60}}><div className="spinner"/></div>
      :<div style={{display:'flex',flexDirection:'column',gap:8}}>
        {categories.map(c=>(
          <div key={c.id} style={{background:'#fff',borderRadius:12,padding:'14px 18px',border:`1px solid ${C.border}`,display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',gap:10}}>
            <span style={{fontWeight:600,color:C.dark}}>{c.emoji} {c.nom}</span>
            <div style={{display:'flex',gap:8}}>
              <button onClick={()=>openEdit(c)} style={{padding:'6px 12px',borderRadius:8,border:`1px solid ${C.border}`,background:'transparent',color:C.primary,cursor:'pointer',fontSize:12}}>✏️</button>
              <button onClick={()=>handleDelete(c)} style={{padding:'6px 12px',borderRadius:8,border:'1px solid rgba(192,57,43,0.2)',background:'rgba(192,57,43,0.06)',color:C.danger,cursor:'pointer',fontSize:12}}>🗑️</button>
            </div>
          </div>
        ))}
      </div>}
      {form&&(
        <div style={{position:'fixed',inset:0,background:'rgba(0,0,0,0.45)',backdropFilter:'blur(4px)',display:'flex',alignItems:'center',justifyContent:'center',zIndex:1000,padding:20}}>
          <div style={{background:'#fff',borderRadius:20,padding:32,width:'100%',maxWidth:400,boxShadow:'0 20px 60px rgba(0,0,0,0.2)'}}>
            <h3 style={{fontSize:22,color:C.primary,marginBottom:24}}>{form.id?'✏️ Modifier':'+ Nouvelle catégorie'}</h3>
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Nom *</label>
                <input value={form.nom} onChange={e=>setForm({...form,nom:e.target.value})} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit'}}/></div>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Emoji</label>
                <input value={form.emoji||''} onChange={e=>setForm({...form,emoji:e.target.value})} placeholder="🍔" style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:18,fontFamily:'inherit'}}/></div>
              <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Ordre</label>
                <input type="number" value={form.ordre||0} onChange={e=>setForm({...form,ordre:e.target.value})} style={{width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit'}}/></div>
            </div>
            <div style={{display:'flex',gap:10,marginTop:24}}>
              <button onClick={()=>setForm(null)} style={{flex:1,padding:12,borderRadius:10,border:`1px solid ${C.border}`,background:'transparent',cursor:'pointer',color:C.darkSoft,fontWeight:600}}>Annuler</button>
              <button onClick={handleSave} disabled={saving} style={{flex:2,padding:12,borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,color:'#fff',fontWeight:700}}>{saving?'⏳…':'💾 Enregistrer'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ParametresTab() {
  const [params,setParams]=useState(null); const [nomRestaurant,setNom]=useState('');
  const [preview,setPreview]=useState(null); const [uploading,setUploading]=useState(false);
  const [saving,setSaving]=useState(false); const [error,setError]=useState(''); const [success,setSuccess]=useState('');
  const [pwdForm,setPwdForm]=useState({current:'',new1:'',new2:''}); const [pwdError,setPwdError]=useState('');
  const [pwdSuccess,setPwdSuccess]=useState(''); const [pwdLoading,setPwdLoading]=useState(false);

  const load=async()=>{const{data}=await getParametres();setParams(data);setNom(data?.nom_restaurant||'');setPreview(data?.logo_url||null);};
  useEffect(()=>{load();},[]);

  const handleFileChange=async(e)=>{const file=e.target.files?.[0];if(!file)return;setError('');setSuccess('');if(!file.type.startsWith('image/')){setError('Image requise.');return;}if(file.size>5*1024*1024){setError('Max 5 Mo.');return;}setPreview(URL.createObjectURL(file));setUploading(true);const{data,error:uploadErr}=await uploadImage(file,'logos');setUploading(false);if(uploadErr){setError(uploadErr.message);return;}await updateParametres({logo_url:data.publicUrl});setPreview(data.publicUrl);setSuccess('✅ Photo mise à jour !');load();};
  const handleSaveNom=async()=>{setSaving(true);setError('');setSuccess('');const{error}=await updateParametres({nom_restaurant:nomRestaurant});setSaving(false);if(error){setError(error.message);return;}setSuccess('✅ Nom mis à jour !');};
  const handleRemoveLogo=async()=>{if(!confirm('Retirer la photo ?'))return;await updateParametres({logo_url:null});setPreview(null);setSuccess('✅ Photo retirée.');};

  const handleChangePassword=async()=>{setPwdError('');setPwdSuccess('');if(!pwdForm.new1||!pwdForm.new2){setPwdError('Remplissez les deux champs.');return;}if(pwdForm.new1!==pwdForm.new2){setPwdError('Les mots de passe ne correspondent pas.');return;}if(pwdForm.new1.length<6){setPwdError('Minimum 6 caractères.');return;}setPwdLoading(true);const{error}=await supabase.auth.updateUser({password:pwdForm.new1});setPwdLoading(false);if(error){setPwdError(error.message);return;}setPwdSuccess('✅ Mot de passe modifié !');setPwdForm({current:'',new1:'',new2:''});};

  if(!params) return <div style={{display:'flex',justifyContent:'center',padding:60}}><div className="spinner"/></div>;

  const inp={width:'100%',padding:'11px 14px',border:`1.5px solid ${C.border}`,borderRadius:10,fontSize:14,fontFamily:'inherit',background:'#fff'};
  const crd={background:'#fff',borderRadius:16,border:`1px solid ${C.border}`,boxShadow:'0 2px 10px rgba(0,0,0,0.05)',padding:24,marginBottom:20};

  return (
    <div>
      <h2 style={{fontSize:24,color:C.primary,fontWeight:700,marginBottom:24}}>⚙️ Paramètres</h2>
      {success&&<div style={{background:'rgba(30,132,73,0.10)',border:'1px solid rgba(30,132,73,0.3)',borderRadius:10,padding:'10px 16px',marginBottom:16,color:C.success,fontSize:13}}>{success}</div>}
      {error&&<div style={{background:'rgba(192,57,43,0.10)',border:'1px solid rgba(192,57,43,0.3)',borderRadius:10,padding:'10px 16px',marginBottom:16,color:C.danger,fontSize:13}}>⚠️ {error}</div>}

      <div style={crd}>
        <h3 style={{color:C.primary,marginBottom:16,fontSize:16,fontWeight:700}}>📷 Photo de profil / Logo</h3>
        <div style={{display:'flex',alignItems:'center',gap:20,flexWrap:'wrap'}}>
          <div style={{width:90,height:90,borderRadius:'50%',overflow:'hidden',background:'rgba(0,0,0,0.05)',border:`2px solid ${C.border}`,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            {preview?<img src={preview} alt="Logo" style={{width:'100%',height:'100%',objectFit:'cover'}}/>:<span style={{fontSize:32}}>🍷</span>}
          </div>
          <div style={{display:'flex',flexDirection:'column',gap:10}}>
            <label style={{padding:'9px 16px',borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,color:'#fff',fontSize:13,fontWeight:600,display:'inline-flex'}}>
              {uploading?'⏳ Envoi…':'📤 Changer la photo'}
              <input type="file" accept="image/*" onChange={handleFileChange} disabled={uploading} style={{display:'none'}}/>
            </label>
            {preview&&<button onClick={handleRemoveLogo} style={{padding:'7px 14px',borderRadius:8,border:'1px solid rgba(192,57,43,0.25)',background:'rgba(192,57,43,0.07)',color:C.danger,cursor:'pointer',fontSize:12,fontWeight:600}}>🗑️ Retirer</button>}
          </div>
        </div>
      </div>

      <div style={crd}>
        <h3 style={{color:C.primary,marginBottom:16,fontSize:16,fontWeight:700}}>🏷️ Nom du restaurant</h3>
        <div style={{display:'flex',gap:12,flexWrap:'wrap'}}>
          <input value={nomRestaurant} onChange={e=>setNom(e.target.value)} style={{...inp,flex:1,minWidth:200}} placeholder="Lez"/>
          <button onClick={handleSaveNom} disabled={saving} style={{padding:'11px 20px',borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,color:'#fff',fontWeight:700}}>{saving?'⏳':'💾 Enregistrer'}</button>
        </div>
      </div>

      <div style={crd}>
        <h3 style={{color:C.primary,marginBottom:6,fontSize:16,fontWeight:700}}>🔑 Modifier le mot de passe</h3>
        <p style={{fontSize:13,color:C.darkSoft,marginBottom:16}}>Choisissez un nouveau mot de passe pour votre compte admin.</p>
        {pwdSuccess&&<div style={{background:'rgba(30,132,73,0.10)',border:'1px solid rgba(30,132,73,0.3)',borderRadius:10,padding:'10px 14px',marginBottom:14,color:C.success,fontSize:13}}>{pwdSuccess}</div>}
        {pwdError&&<div style={{background:'rgba(192,57,43,0.10)',border:'1px solid rgba(192,57,43,0.3)',borderRadius:10,padding:'10px 14px',marginBottom:14,color:C.danger,fontSize:13}}>⚠️ {pwdError}</div>}
        <div style={{display:'flex',flexDirection:'column',gap:12}}>
          <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Nouveau mot de passe</label>
            <input type="password" value={pwdForm.new1} onChange={e=>setPwdForm({...pwdForm,new1:e.target.value})} style={inp} placeholder="••••••••"/></div>
          <div><label style={{fontSize:11,fontWeight:600,color:C.gold,textTransform:'uppercase',letterSpacing:'0.08em',display:'block',marginBottom:6}}>Confirmer</label>
            <input type="password" value={pwdForm.new2} onChange={e=>setPwdForm({...pwdForm,new2:e.target.value})} style={inp} placeholder="••••••••"/></div>
          <button onClick={handleChangePassword} disabled={pwdLoading} style={{padding:'12px 20px',borderRadius:10,border:'none',cursor:'pointer',background:`linear-gradient(135deg,${C.primary},${C.primaryMid})`,color:'#F5F0E8',fontWeight:700,fontSize:14,alignSelf:'flex-start'}}>{pwdLoading?'⏳ Modification…':'🔐 Mettre à jour'}</button>
        </div>
      </div>
    </div>
  );
}

export default function AdminPage() {
  const [user,setUser]=useState(null); const [tab,setTab]=useState('commandes'); const [loading,setLoading]=useState(true);
  useEffect(()=>{supabase.auth.getSession().then(({data:{session}})=>{setUser(session?.user||null);setLoading(false);});}, []);
  if(loading) return <div style={{minHeight:'100vh',display:'flex',alignItems:'center',justifyContent:'center',background:C.primary}}><div className="spinner"/></div>;
  if(!user) return <LoginForm onLogin={setUser}/>;
  const TABS=[{id:'commandes',label:'📋 Commandes'},{id:'appels',label:'🔔 Appels'},{id:'produits',label:'🍽️ Produits'},{id:'categories',label:'📂 Catégories'},{id:'parametres',label:'⚙️ Paramètres'}];
  return (
    <div style={{display:'flex',minHeight:'100vh',background:'#FAFAFA'}}>
      <aside style={{width:230,flexShrink:0,background:C.primary,display:'flex',flexDirection:'column',padding:'28px 0',position:'fixed',top:0,left:0,bottom:0,zIndex:100,boxShadow:'4px 0 24px rgba(0,0,0,0.18)'}}>
        <div style={{padding:'0 24px 24px',borderBottom:'1px solid rgba(255,255,255,0.12)',marginBottom:12}}>
          <div style={{width:44,height:44,borderRadius:'50%',background:`linear-gradient(135deg,${C.gold},${C.goldLight})`,display:'flex',alignItems:'center',justifyContent:'center',marginBottom:12}}>
            <span style={{fontSize:20}}>🍷</span>
          </div>
          <h2 style={{fontSize:18,color:'#F5F0E8',fontWeight:700,lineHeight:1.2}}>{"Lez"}</h2>
          <p style={{fontSize:11,color:C.gold,marginTop:4,letterSpacing:'0.08em'}}>Administration</p>
          <p style={{fontSize:11,color:'rgba(255,255,255,0.35)',marginTop:8}}>{user.email}</p>
        </div>
        <nav style={{flex:1,padding:'0 12px',display:'flex',flexDirection:'column',gap:4}}>
          {TABS.map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{width:'100%',textAlign:'left',padding:'11px 14px',borderRadius:10,border:'none',cursor:'pointer',
              background:tab===t.id?'rgba(255,255,255,0.12)':'transparent',
              color:tab===t.id?C.gold:'rgba(255,255,255,0.55)',
              fontSize:14,fontWeight:tab===t.id?700:400,
              borderLeft:tab===t.id?`3px solid ${C.gold}`:'3px solid transparent',
              transition:'all 0.15s'}}>{t.label}</button>
          ))}
        </nav>
        <div style={{padding:'12px 16px',borderTop:'1px solid rgba(255,255,255,0.10)',display:'flex',flexDirection:'column',gap:8}}>
          <button onClick={()=>window.open('/','_blank')} style={{width:'100%',padding:'9px 14px',borderRadius:10,border:'1px solid rgba(255,255,255,0.15)',background:'transparent',color:'rgba(255,255,255,0.55)',cursor:'pointer',fontSize:13}}>👁️ Voir le menu</button>
          <button onClick={async()=>{await signOutAdmin();setUser(null);}} style={{width:'100%',padding:'9px 14px',borderRadius:10,border:'1px solid rgba(192,57,43,0.3)',background:'rgba(192,57,43,0.08)',color:'#FF7961',cursor:'pointer',fontSize:13,fontWeight:600}}>🚪 Déconnexion</button>
        </div>
      </aside>
      <main style={{marginLeft:230,flex:1,padding:'36px 32px',maxWidth:900}}>
        {tab==='commandes'&&<CommandesTab/>}{tab==='appels'&&<AppelsTab/>}
        {tab==='produits'&&<ProduitsTab/>}{tab==='categories'&&<CategoriesTab/>}
        {tab==='parametres'&&<ParametresTab/>}
      </main>
    </div>
  );
}
