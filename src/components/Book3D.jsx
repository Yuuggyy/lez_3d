import { useState, useRef, useCallback, useEffect } from 'react';

// ─── Couleurs Lez ───────────────────────────────────────
const C = {
  primary:    '#1A3A2A',
  primaryMid: '#2D5E42',
  gold:       '#B8943F',
  goldLight:  '#D4AF6A',
  beige:      '#F5EDD8',
  cream:      '#FBF8F0',
  dark:       '#1A1A14',
  darkSoft:   'rgba(0,0,0,0.52)',
  border:     'rgba(201,169,110,0.20)',
};

/* ─── ProduitCard ─────────────────────────────────────────── */
export function ProduitCard({ produit, onAdd, isMobile }) {
  const [qty, setQty] = useState(1);
  const hasImage = produit.image_url && produit.image_url.trim() !== '';

  if (isMobile) {
    return (
      <div style={{
        padding: '14px 0', borderBottom: `1px solid rgba(201,169,110,0.15)`,
        display: 'flex', gap: hasImage ? 12 : 0, alignItems: 'flex-start',
      }}>
        {hasImage && (
          <div style={{
            width: 68, height: 68, borderRadius: 12, overflow: 'hidden', flexShrink: 0,
            background: C.cream, border: `1px solid ${C.border}`,
          }}>
            <img src={produit.image_url} alt={produit.nom}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }} loading="lazy" />
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <span style={{
              fontFamily: "'Cormorant Garamond', Georgia, serif",
              fontSize: 16, fontWeight: 700, color: C.dark, whiteSpace: 'nowrap',
            }}>{produit.nom}</span>
            <span style={{ flex: 1, borderBottom: `1.5px dotted rgba(201,169,110,0.35)`, position: 'relative', top: -3, minWidth: 8 }} />
            <span style={{ fontSize: 15, fontWeight: 800, color: C.gold, whiteSpace: 'nowrap' }}>
              {Number(produit.prix).toFixed(2)} $
            </span>
          </div>
          {produit.description && (
            <p style={{ fontSize: 12.5, color: C.darkSoft, fontStyle: 'italic', marginTop: 3, lineHeight: 1.35 }}>
              {produit.description}
            </p>
          )}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <button onClick={() => setQty(q => Math.max(1, q - 1))} style={{
                width: 26, height: 26, borderRadius: '50%', border: `1px solid ${C.border}`,
                background: 'transparent', cursor: 'pointer', fontSize: 14, color: C.darkSoft,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>−</button>
              <span style={{ fontSize: 14, fontWeight: 700, color: C.dark, minWidth: 16, textAlign: 'center' }}>{qty}</span>
              <button onClick={() => setQty(q => q + 1)} style={{
                width: 26, height: 26, borderRadius: '50%', border: 'none',
                background: `linear-gradient(135deg, ${C.gold}, ${C.goldLight})`,
                cursor: 'pointer', fontSize: 14, color: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>+</button>
            </div>
            <button onClick={() => { onAdd({ ...produit, quantite: qty, prix_unit: produit.prix }); setQty(1); }} style={{
              flex: 1, padding: '7px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              background: `linear-gradient(135deg, ${C.primary}, ${C.primaryMid})`,
              color: C.beige, fontSize: 13, fontWeight: 700,
            }}>Ajouter</button>
          </div>
        </div>
      </div>
    );
  }

  // Desktop
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 16, padding: '14px 0',
      borderBottom: `1px solid rgba(201,169,110,0.12)`,
    }}>
      {hasImage && (
        <div style={{
          width: 72, height: 72, borderRadius: 12, overflow: 'hidden', flexShrink: 0,
          background: C.cream, border: `1px solid ${C.border}`,
        }}>
          <img src={produit.image_url} alt={produit.nom}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }} loading="lazy" />
        </div>
      )}
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={{
            fontFamily: "'Cormorant Garamond', Georgia, serif",
            fontSize: 17, fontWeight: 700, color: C.dark,
          }}>{produit.nom}</span>
          <span style={{ flex: 1, borderBottom: `1.5px dotted rgba(201,169,110,0.30)`, position: 'relative', top: -4 }} />
          <span style={{ fontSize: 16, fontWeight: 800, color: C.gold }}>{Number(produit.prix).toFixed(2)} $</span>
        </div>
        {produit.description && (
          <p style={{ fontSize: 13, color: C.darkSoft, fontStyle: 'italic', marginTop: 4, lineHeight: 1.4 }}>
            {produit.description}
          </p>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <button onClick={() => setQty(q => Math.max(1, q - 1))} style={{
            width: 28, height: 28, borderRadius: '50%', border: `1px solid ${C.border}`,
            background: 'transparent', cursor: 'pointer', fontSize: 15, color: C.darkSoft,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>−</button>
          <span style={{ fontSize: 14, fontWeight: 700, color: C.dark, minWidth: 18, textAlign: 'center' }}>{qty}</span>
          <button onClick={() => setQty(q => q + 1)} style={{
            width: 28, height: 28, borderRadius: '50%', border: 'none',
            background: `linear-gradient(135deg, ${C.gold}, ${C.goldLight})`,
            cursor: 'pointer', fontSize: 15, color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>+</button>
        </div>
        <button onClick={() => { onAdd({ ...produit, quantite: qty, prix_unit: produit.prix }); setQty(1); }} style={{
          padding: '8px 16px', borderRadius: 8, border: 'none', cursor: 'pointer',
          background: `linear-gradient(135deg, ${C.primary}, ${C.primaryMid})`,
          color: C.beige, fontSize: 13, fontWeight: 700,
        }}>Ajouter</button>
      </div>
    </div>
  );
}

/* ─── Page d'une catégorie dans le livre ─────────────────── */
function PageContent({ categorie, produits, onAdd, isMobile }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* En-tête catégorie */}
      <div style={{
        padding: isMobile ? '14px 16px 10px' : '20px 28px 14px',
        borderBottom: `2px solid ${C.gold}`,
        background: `linear-gradient(135deg, ${C.primary} 0%, ${C.primaryMid} 100%)`,
        flexShrink: 0,
      }}>
        <h2 style={{
          fontFamily: "'Cormorant Garamond', Georgia, serif",
          fontSize: isMobile ? 22 : 28, fontWeight: 700,
          color: C.beige, margin: 0,
          letterSpacing: '0.03em',
        }}>
          {categorie.emoji && <span style={{ marginRight: 10 }}>{categorie.emoji}</span>}
          {categorie.nom}
        </h2>
        {categorie.description && (
          <p style={{ color: C.gold, fontSize: isMobile ? 12 : 13, marginTop: 4, fontStyle: 'italic' }}>
            {categorie.description}
          </p>
        )}
      </div>

      {/* Produits */}
      <div style={{
        flex: 1, overflowY: 'auto', padding: isMobile ? '0 16px' : '0 28px',
        scrollbarWidth: 'thin',
      }}>
        {produits.map(p => (
          <ProduitCard key={p.id} produit={p} onAdd={onAdd} isMobile={isMobile} />
        ))}
      </div>
    </div>
  );
}

/* ─── Book3D — livre avec flip ───────────────────────────── */
export default function Book3D({ pages, onAdd, isMobile, parametres }) {
  const [currentPage, setCurrentPage] = useState(0);
  const [flipping, setFlipping]       = useState(false);
  const [flipDir, setFlipDir]         = useState('next');
  const touchStartX = useRef(null);

  const goTo = useCallback((dir) => {
    if (flipping) return;
    if (dir === 'next' && currentPage >= pages.length - 1) return;
    if (dir === 'prev' && currentPage <= 0) return;
    setFlipping(true);
    setFlipDir(dir);
    setTimeout(() => {
      setCurrentPage(p => dir === 'next' ? p + 1 : p - 1);
      setFlipping(false);
    }, 300);
  }, [flipping, currentPage, pages.length]);

  const onTouchStart = (e) => { touchStartX.current = e.touches[0].clientX; };
  const onTouchEnd   = (e) => {
    if (touchStartX.current === null) return;
    const dx = e.changedTouches[0].clientX - touchStartX.current;
    if (Math.abs(dx) > 40) goTo(dx < 0 ? 'next' : 'prev');
    touchStartX.current = null;
  };

  if (pages.length === 0) return (
    <div style={{ textAlign: 'center', padding: '80px 20px', color: C.darkSoft }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>🍽️</div>
      <p style={{ fontSize: 16, fontFamily: "'Cormorant Garamond', Georgia, serif" }}>La carte est vide pour l'instant.</p>
    </div>
  );

  const page = pages[currentPage];
  const bookH = isMobile ? 'calc(100dvh - 180px)' : 'calc(100vh - 200px)';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', userSelect: 'none' }}>

      {/* Indicateur de pages — catégories */}
      <div style={{
        display: 'flex', gap: 6, padding: isMobile ? '10px 16px' : '12px 0',
        overflowX: 'auto', flexShrink: 0, scrollbarWidth: 'none',
      }}>
        {pages.map((p, i) => (
          <button key={i} onClick={() => !flipping && setCurrentPage(i)} style={{
            padding: isMobile ? '5px 12px' : '6px 14px',
            borderRadius: 20, border: 'none', cursor: 'pointer', flexShrink: 0,
            background: i === currentPage
              ? `linear-gradient(135deg, ${C.gold}, ${C.goldLight})`
              : `rgba(26,26,26,0.08)`,
            color: i === currentPage ? '#fff' : C.dark,
            fontSize: 12, fontWeight: i === currentPage ? 700 : 400,
            transition: 'all 0.2s',
            boxShadow: i === currentPage ? `0 2px 10px rgba(201,169,110,0.30)` : 'none',
          }}>
            {p.categorie.emoji} {p.categorie.nom}
          </button>
        ))}
      </div>

      {/* Livre */}
      <div
        onTouchStart={onTouchStart}
        onTouchEnd={onTouchEnd}
        style={{
          flex: 1, position: 'relative', overflow: 'hidden',
          borderRadius: isMobile ? 16 : 20,
          background: C.white,
          border: `1px solid ${C.border}`,
          boxShadow: `0 8px 40px rgba(26,26,26,0.12), 0 2px 8px rgba(26,26,26,0.06)`,
          transform: flipping
            ? `perspective(1200px) rotateY(${flipDir === 'next' ? '-4deg' : '4deg'})`
            : 'perspective(1200px) rotateY(0deg)',
          transition: 'transform 0.3s cubic-bezier(0.4,0,0.2,1)',
        }}>
        <PageContent
          categorie={page.categorie}
          produits={page.produits}
          onAdd={onAdd}
          isMobile={isMobile}
        />
      </div>

      {/* Navigation */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: isMobile ? '12px 16px' : '16px 0',
        flexShrink: 0,
      }}>
        <button onClick={() => goTo('prev')} disabled={currentPage === 0 || flipping} style={{
          padding: isMobile ? '10px 18px' : '10px 22px',
          borderRadius: 10, border: `1px solid ${C.border}`,
          background: 'transparent', cursor: currentPage === 0 ? 'not-allowed' : 'pointer',
          color: currentPage === 0 ? 'rgba(26,26,20,0.2)' : C.primary,
          fontSize: 14, fontWeight: 600, transition: 'all 0.2s',
        }}>← Précédent</button>

        <span style={{ fontSize: 12, color: C.darkSoft, fontWeight: 500 }}>
          {currentPage + 1} / {pages.length}
        </span>

        <button onClick={() => goTo('next')} disabled={currentPage >= pages.length - 1 || flipping} style={{
          padding: isMobile ? '10px 18px' : '10px 22px',
          borderRadius: 10, border: 'none',
          background: currentPage >= pages.length - 1
            ? 'rgba(26,26,20,0.08)'
            : `linear-gradient(135deg, ${C.primary}, ${C.primaryMid})`,
          cursor: currentPage >= pages.length - 1 ? 'not-allowed' : 'pointer',
          color: currentPage >= pages.length - 1 ? 'rgba(26,26,20,0.25)' : C.beige,
          fontSize: 14, fontWeight: 700, transition: 'all 0.2s',
        }}>Suivant →</button>
      </div>
    </div>
  );
}
