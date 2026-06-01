function Get-AerStyleCss {
    return @'
:root[data-theme="dark"] {
  --bg:#0a0f1e;--bg2:#0d1526;--surface:#162033;--surface2:#1e293b;
  --border:#1e3352;--text:#e2e8f0;--muted:#64748b;
  --accent:#0ea5e9;--accent2:#38bdf8;
  --good:#22c55e;--warn:#f59e0b;--bad:#ef4444;--purple:#a78bfa;
  --sidebar-bg:#0b1120;
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{background:var(--bg);color:var(--text);font-family:'Segoe UI',Inter,system-ui,Arial,sans-serif;display:flex;min-height:100vh;transition:background .2s,color .2s}

/* ── Sidebar ─────────────────────────────────────────────────────────── */
.sidebar{width:220px;background:var(--sidebar-bg);display:flex;flex-direction:column;position:fixed;top:0;left:0;bottom:0;z-index:100;overflow-y:auto;border-right:1px solid rgba(255,255,255,.06);transition:width .2s ease}
.sidebar-brand{padding:18px 16px;display:flex;align-items:center;gap:11px;flex-shrink:0;border-bottom:1px solid rgba(255,255,255,.06)}
.brand-name{font-size:14px;font-weight:700;color:#fff;letter-spacing:-.2px;line-height:1.2}
.brand-sub{font-size:10px;color:rgba(255,255,255,.4);margin-top:2px}
.sidebar-search{padding:12px 14px;flex-shrink:0;display:flex;align-items:center;gap:8px;border-bottom:1px solid rgba(255,255,255,.06)}
.sidebar-search-box{position:relative;flex:1;min-width:0}
.sidebar-search-icon{position:absolute;left:10px;top:50%;transform:translateY(-50%);font-size:11px;opacity:.4;pointer-events:none}
.sidebar-search input{width:100%;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:7px 10px 7px 28px;font-size:12px;color:#fff;outline:none;transition:border-color .15s}
.sidebar-toggle{flex-shrink:0;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.08);color:rgba(255,255,255,.6);cursor:pointer;font-size:14px;line-height:1;padding:7px 10px;border-radius:8px;transition:all .15s}
.sidebar-toggle:hover{color:#fff;border-color:var(--accent);background:rgba(14,165,233,.12)}
.sidebar-search input::placeholder{color:rgba(255,255,255,.3)}
.sidebar-search input:focus{border-color:var(--accent)}
.nav-empty{padding:14px 16px;font-size:11.5px;color:rgba(255,255,255,.3);text-align:center}
.sidebar-nav{flex:1;padding:10px 0;overflow-y:auto}
.nav-section{display:flex;align-items:center;gap:6px;width:100%;padding:14px 16px 5px;font-size:9.5px;font-weight:600;letter-spacing:1.8px;color:rgba(255,255,255,.25);text-transform:uppercase;background:none;border:none;cursor:pointer;font-family:inherit;transition:color .15s}
.nav-section:hover{color:rgba(255,255,255,.45)}
.nav-section-label{flex:1;text-align:left}
.nav-section-chevron{font-size:8px;opacity:.6;transition:transform .2s}
.nav-group.collapsed .nav-section-chevron{transform:rotate(-90deg)}
.nav-group-items{overflow:hidden;max-height:600px;transition:max-height .25s ease}
.nav-group.collapsed .nav-group-items{max-height:0}
.sidebar-nav.searching .nav-group-items{max-height:600px}
.nav-item{display:flex;align-items:center;gap:9px;padding:9px 16px;color:rgba(255,255,255,.45);font-size:12.5px;font-weight:500;cursor:pointer;transition:all .15s;border-left:2px solid transparent;text-decoration:none}
.nav-item:hover{color:rgba(255,255,255,.8);background:rgba(255,255,255,.05)}
.nav-item.active{color:#fff;background:rgba(14,165,233,.15);border-left-color:var(--accent)}
.nav-icon{font-size:14px;width:18px;text-align:center;flex-shrink:0}
.nav-label{flex:1}
.nav-badge{font-size:9.5px;font-weight:700;padding:1px 6px;border-radius:10px;display:none}
.nav-badge.bad{background:rgba(239,68,68,.25);color:#fca5a5;display:inline}
.nav-badge.warn{background:rgba(245,158,11,.2);color:#fde68a;display:inline}
.nav-divider{height:1px;background:rgba(255,255,255,.06);margin:6px 10px}
.sidebar-footer{padding:14px 16px;border-top:1px solid rgba(255,255,255,.06);flex-shrink:0}
.sidebar-tenant-label{font-size:9.5px;color:rgba(255,255,255,.25);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px}
.sidebar-tenant-val{font-size:11px;color:rgba(255,255,255,.5);word-break:break-all;line-height:1.5}
.sidebar-version{font-size:10px;color:rgba(255,255,255,.2);margin-top:8px}

/* ── Sidebar collapse (icon rail) ────────────────────────────────────── */
body.sidebar-collapsed .sidebar{width:64px}
body.sidebar-collapsed .page-wrapper{margin-left:64px}
body.sidebar-collapsed .sidebar-brand{justify-content:center;padding:18px 0}
body.sidebar-collapsed .sidebar-brand-text,
body.sidebar-collapsed .sidebar-search-box,
body.sidebar-collapsed .sidebar-footer,
body.sidebar-collapsed .nav-label,
body.sidebar-collapsed .nav-section-label,
body.sidebar-collapsed .nav-section-chevron{display:none}
body.sidebar-collapsed .sidebar-search{justify-content:center;padding:12px 0}
body.sidebar-collapsed .nav-section{display:none}
body.sidebar-collapsed .nav-group + .nav-group{margin-top:6px;padding-top:6px;border-top:1px solid rgba(255,255,255,.06)}
body.sidebar-collapsed .nav-item{justify-content:center;padding:10px 0;position:relative}
body.sidebar-collapsed .nav-group-items{max-height:none!important}
body.sidebar-collapsed .nav-badge{position:absolute;top:5px;right:13px;min-width:0;width:7px;height:7px;padding:0;font-size:0;border-radius:50%}

/* ── Page wrapper ────────────────────────────────────────────────────── */
.page-wrapper{margin-left:220px;flex:1;min-width:0;display:flex;flex-direction:column;min-height:100vh;transition:margin-left .2s ease}

/* ── Topbar ──────────────────────────────────────────────────────────── */
.topbar{background:var(--bg);border-bottom:1px solid var(--border);padding:11px 28px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:50}
[data-theme="dark"] .topbar{background:rgba(10,15,30,.9);backdrop-filter:blur(10px)}
.topbar-left{display:flex;align-items:center;gap:14px;min-width:0}
.topbar-title{font-size:14px;font-weight:700;color:var(--text)}
.topbar-right{display:flex;align-items:center;gap:14px}
.topbar-meta{font-size:11.5px;color:var(--muted)}
.topbar-meta strong{color:var(--text)}
.topbar-actions{display:flex;align-items:center;gap:8px;padding-right:14px;border-right:1px solid var(--border)}
.topbar-action-label{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:var(--muted)}
.export-btn{display:inline-flex;align-items:center;gap:7px;min-height:32px;padding:7px 11px;border:1px solid var(--border);border-radius:8px;background:var(--surface);color:var(--text);text-decoration:none;font-size:11.5px;font-weight:800;letter-spacing:.4px;transition:border-color .15s,background .15s,transform .15s}
.export-btn:hover{transform:translateY(-1px);background:var(--surface2);border-color:var(--accent);color:var(--accent2)}
.export-btn.excel{border-color:rgba(34,197,94,.35);background:rgba(34,197,94,.09)}
.export-btn.excel:hover{border-color:var(--good);color:#86efac}
.export-btn.pdf{border-color:rgba(239,68,68,.35);background:rgba(239,68,68,.08)}
.export-btn.pdf:hover{border-color:var(--bad);color:#fca5a5}
.export-btn-icon{font-size:14px;line-height:1}
@media (max-width:820px){.topbar{align-items:flex-start;gap:10px;flex-direction:column}.topbar-right{width:100%;justify-content:space-between}.topbar-actions{padding-right:10px}.topbar-action-label{display:none}}
@media (max-width:520px){.topbar-right{align-items:flex-start;flex-direction:column}.topbar-actions{border-right:none;padding-right:0;flex-wrap:wrap}.export-btn{min-height:30px;padding:6px 10px}}
.export-panel{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:22px;padding:16px 18px;border:1px solid rgba(14,165,233,.32);border-radius:10px;background:linear-gradient(135deg,rgba(14,165,233,.12),rgba(34,197,94,.07));box-shadow:0 8px 26px rgba(0,0,0,.14)}
.export-panel-copy{min-width:0}
.export-panel-kicker{font-size:10px;font-weight:800;text-transform:uppercase;letter-spacing:1.4px;color:var(--accent2);margin-bottom:4px}
.export-panel-title{font-size:15px;font-weight:800;color:var(--text);line-height:1.2}
.export-panel-sub{font-size:11.5px;color:var(--muted);margin-top:4px;line-height:1.45}
.export-panel-actions{display:flex;align-items:center;gap:9px;flex-shrink:0}
@media (max-width:700px){.export-panel{align-items:flex-start;flex-direction:column}.export-panel-actions{width:100%;flex-wrap:wrap}}

/* ── Page content ────────────────────────────────────────────────────── */
.page-content{flex:1;padding:24px 28px}
.page{display:none}
.page.active{display:block;animation:fadein .18s ease}
@keyframes fadein{from{opacity:0;transform:translateY(5px)}to{opacity:1;transform:translateY(0)}}

/* ── Section title ───────────────────────────────────────────────────── */
.section-title{font-size:10px;font-weight:600;letter-spacing:1.6px;color:var(--muted);text-transform:uppercase;margin-bottom:14px;margin-top:0;display:flex;align-items:center;gap:8px}
.section-title::after{content:'';flex:1;height:1px;background:var(--border)}

/* ── Page header (detail pages) ─────────────────────────────────────── */
.page-header{display:flex;align-items:center;gap:14px;margin-bottom:22px;padding-bottom:18px;border-bottom:1px solid var(--border)}
.page-header-icon{font-size:30px;line-height:1}
.page-header-title{font-size:20px;font-weight:700;color:var(--text)}
.page-header-sub{font-size:12px;color:var(--muted);margin-top:3px}
.page-header-chips{margin-left:auto;display:flex;gap:8px;align-items:center}
.chip{padding:4px 12px;border-radius:20px;font-size:11.5px;font-weight:600}
.chip.bad{background:rgba(239,68,68,.12);border:1px solid rgba(239,68,68,.3);color:#f87171}
.chip.warn{background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.3);color:#fbbf24}
.chip.blue{background:rgba(14,165,233,.12);border:1px solid rgba(14,165,233,.3);color:var(--accent2)}
.chip.good{background:rgba(34,197,94,.12);border:1px solid rgba(34,197,94,.3);color:#4ade80}

/* ── KPI grid ────────────────────────────────────────────────────────── */
.kpi-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:26px}
.kpi-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:18px 20px;position:relative;overflow:hidden;transition:border-color .2s}
.kpi-card:hover{border-color:var(--accent)}
.kpi-card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px}
.kpi-card.purple::before{background:linear-gradient(90deg,#a78bfa,#6366f1)}
.kpi-card.blue::before{background:linear-gradient(90deg,#0ea5e9,#6366f1)}
.kpi-card.cyan::before{background:linear-gradient(90deg,#22d3ee,#0ea5e9)}
.kpi-card.sky::before{background:linear-gradient(90deg,#38bdf8,#22d3ee)}
.kpi-label{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:8px}
.kpi-value{font-size:28px;font-weight:800;line-height:1;margin-bottom:5px}
.kpi-card.purple .kpi-value{color:#c4b5fd}
.kpi-card.blue   .kpi-value{color:#38bdf8}
.kpi-card.cyan   .kpi-value{color:#67e8f9}
.kpi-card.sky    .kpi-value{color:#7dd3fc}
.kpi-hint{font-size:11px;color:var(--muted)}
.kpi-icon{position:absolute;right:16px;top:16px;font-size:24px;opacity:.1}

/* ── Stat tiles (compute summary) ────────────────────────────────────── */
.stat-tiles{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin-bottom:24px}
@media (max-width:1200px){.stat-tiles{grid-template-columns:repeat(3,1fr)}}
@media (max-width:640px){.stat-tiles{grid-template-columns:repeat(2,1fr)}}
.stat-tile{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 16px;display:flex;flex-direction:column;gap:7px;transition:border-color .2s}
.stat-tile:hover{border-color:var(--accent)}
.stat-tile-label{font-size:10px;text-transform:uppercase;letter-spacing:.7px;color:var(--muted);display:flex;align-items:center;gap:6px}
.stat-tile-value{font-size:22px;font-weight:800;color:var(--text);line-height:1}
.stat-tile-unit{font-size:12px;font-weight:600;color:var(--muted);margin-left:4px}
.stat-tile-sub{font-size:11px;color:var(--muted);margin-top:-2px}
.cat-pill{display:inline-block;font-size:11px;line-height:1.6;padding:1px 8px;border-radius:10px;margin:2px 4px 2px 0;border:1px solid var(--border);white-space:nowrap}
.cat-pill.on{color:#86efac;border-color:rgba(34,197,94,.35);background:rgba(34,197,94,.10)}
.cat-pill.off{color:var(--muted);background:var(--bg2)}
.diag-setting{border:1px solid var(--border);border-radius:8px;padding:10px 12px;margin-bottom:8px;background:var(--bg2)}
.diag-setting-name{font-weight:600;font-size:13px;margin-bottom:8px}
.diag-cats{display:flex;align-items:baseline;gap:8px;margin-top:6px;flex-wrap:wrap}
.diag-cats-label{font-size:10px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted);min-width:56px}

/* ── Summary cards (overview) ────────────────────────────────────────── */
.summary-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:8px}
.summary-card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;cursor:pointer;transition:all .2s;text-decoration:none;display:flex;align-items:center;gap:16px}
.summary-card:hover{transform:translateY(-2px);box-shadow:0 6px 20px rgba(0,0,0,.25)}
.summary-card.security:hover{border-color:var(--bad);box-shadow:0 6px 20px rgba(239,68,68,.12)}
.summary-card.cost:hover{border-color:var(--warn);box-shadow:0 6px 20px rgba(245,158,11,.12)}
.summary-card.advisor:hover{border-color:var(--accent);box-shadow:0 6px 20px rgba(14,165,233,.12)}
.summary-icon-wrap{width:48px;height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:22px;flex-shrink:0}
.summary-card.security .summary-icon-wrap{background:rgba(239,68,68,.12)}
.summary-card.cost     .summary-icon-wrap{background:rgba(245,158,11,.1)}
.summary-card.advisor  .summary-icon-wrap{background:rgba(14,165,233,.1)}
.summary-value{font-size:26px;font-weight:800;line-height:1;margin-bottom:3px}
.summary-card.security .summary-value{color:var(--bad)}
.summary-card.cost     .summary-value{color:var(--warn)}
.summary-card.advisor  .summary-value{color:var(--accent2)}
.summary-label{font-size:12px;font-weight:600;color:var(--text)}
.summary-hint{font-size:11px;color:var(--muted);margin-top:2px}
.summary-arrow{margin-left:auto;color:var(--muted);font-size:16px;flex-shrink:0;opacity:.5}

/* ── Cards ───────────────────────────────────────────────────────────── */
.card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px}
.card:last-child{margin-bottom:0}
.card h3{font-size:13px;font-weight:600;color:var(--text);margin-bottom:16px}
.charts-row{display:grid;grid-template-columns:1fr 1fr 1fr;gap:14px;margin-bottom:16px}

/* ── Donut ────────────────────────────────────────────────────────────── */
.donut-wrap{display:flex;align-items:center;gap:18px}
.legend-item{display:flex;align-items:flex-start;gap:8px;margin-bottom:7px;font-size:12px}
.legend-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;margin-top:4px}
.legend-label{color:var(--muted);flex:1;min-width:0;white-space:normal;word-break:break-word;line-height:1.35}
.legend-val{color:var(--text);font-weight:600;font-size:12px;flex-shrink:0;margin-left:4px}

/* ── Bar charts ──────────────────────────────────────────────────────── */
.bar-item{display:flex;align-items:center;gap:9px;margin-bottom:8px;font-size:12px}
.bar-label{color:var(--muted);width:120px;flex-shrink:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bar-track{flex:1;background:var(--bg2);border-radius:4px;height:5px}
.bar-fill{height:5px;border-radius:4px;transition:width .5s cubic-bezier(.4,0,.2,1)}
.bar-count{width:32px;text-align:right;font-weight:600;color:var(--accent2);font-size:11.5px}

/* ── Advisor ─────────────────────────────────────────────────────────── */
.advisor-header{display:flex;align-items:center;gap:12px;margin-bottom:18px}
.advisor-header h3{font-size:14px;font-weight:600}
.high-impact-badge{background:rgba(239,68,68,.2);color:#fca5a5;border:1px solid rgba(239,68,68,.3);font-size:11px;font-weight:700;padding:3px 10px;border-radius:20px}
.advisor-cards{display:grid;grid-template-columns:repeat(5,1fr);gap:12px}
.advisor-cat{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:16px;display:flex;align-items:center;gap:12px;transition:border-color .2s}
.advisor-cat:hover{border-color:var(--accent)}
.advisor-cat-icon{font-size:20px;flex-shrink:0}
.advisor-cat-count{font-size:24px;font-weight:800;line-height:1}
.advisor-cat-label{font-size:11.5px;font-weight:600;color:var(--text);margin-top:2px}
.advisor-cat-sub{font-size:10.5px;color:var(--muted)}
.advisor-cat.security    .advisor-cat-count{color:#f87171}
.advisor-cat.reliability .advisor-cat-count{color:#fbbf24}
.advisor-cat.cost        .advisor-cat-count{color:#4ade80}
.advisor-cat.performance .advisor-cat-count{color:#818cf8}
.advisor-cat.excellence  .advisor-cat-count{color:#38bdf8}

/* ── Issue list ──────────────────────────────────────────────────────── */
.issue-item{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid var(--border);font-size:12.5px}
.issue-item:last-child{border-bottom:none}
.badge{padding:2px 8px;border-radius:20px;font-size:9.5px;font-weight:700;letter-spacing:.4px;white-space:nowrap;flex-shrink:0}
.badge.critical{background:rgba(127,29,29,.8);color:#fca5a5}
.badge.high{background:rgba(124,45,18,.8);color:#fdba74}
.badge.medium{background:rgba(133,77,14,.7);color:#fef08a}
.badge.info{background:rgba(30,58,95,.8);color:#93c5fd}
.badge.low{background:rgba(12,74,110,.6);color:#7dd3fc}
.badge.waste{background:rgba(74,29,150,.8);color:#ddd6fe}
.issue-text{flex:1;min-width:0}
.issue-title{color:var(--text);font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.issue-sub{color:var(--muted);font-size:11px;margin-top:2px}
.issue-count{color:var(--accent2);font-weight:700;font-size:13px;flex-shrink:0;min-width:32px;text-align:right}

/* ── Bottom row (overview) ───────────────────────────────────────────── */
.bottom-row{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:8px}

/* ── Cloud structure grid ────────────────────────────────────────────── */
.cs-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;align-items:start}
@media (max-width:1100px){.cs-grid{grid-template-columns:1fr}}
.aer-table.simple{min-width:0;table-layout:auto}
.aer-table.simple thead th{padding:9px 12px}
.aer-table.simple tbody td{white-space:normal;word-break:break-word;padding:12px 12px}

/* ── Warn banner ─────────────────────────────────────────────────────── */
.warn-banner{background:rgba(69,26,3,.6);border:1px solid rgba(133,77,14,.5);color:#fef08a;border-radius:8px;padding:10px 14px;margin-bottom:20px;font-size:12.5px}

/* ── Empty state ─────────────────────────────────────────────────────── */
.empty-state{padding:28px 16px;text-align:center;color:var(--muted);font-size:12.5px}

/* ── Pagination ──────────────────────────────────────────────────────── */
.pager{display:flex;align-items:center;justify-content:space-between;margin-top:14px;padding-top:12px;border-top:1px solid var(--border)}
.pager-info{font-size:11.5px;color:var(--muted)}
.pager-controls{display:flex;align-items:center;gap:6px}
.pager-btn{background:var(--surface2);border:1px solid var(--border);border-radius:7px;padding:5px 11px;font-size:12px;color:var(--text);cursor:pointer;transition:all .15s;min-width:32px}
.pager-btn:hover:not(:disabled){border-color:var(--accent);color:var(--accent2)}
.pager-btn:disabled{opacity:.35;cursor:not-allowed}
.pager-btn.active{background:var(--accent);border-color:var(--accent);color:#fff;font-weight:700}
.pager-ellipsis{color:var(--muted);font-size:12px;padding:0 2px}

/* ── Data table ──────────────────────────────────────────────────────── */
.table-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:14px;flex-wrap:wrap}
.table-search{position:relative;flex:1;max-width:340px}
.table-search input{width:100%;background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:8px 12px 8px 32px;font-size:12.5px;color:var(--text);outline:none;transition:border-color .15s}
.table-search input:focus{border-color:var(--accent)}
.table-search-icon{position:absolute;left:11px;top:50%;transform:translateY(-50%);color:var(--muted);font-size:13px;pointer-events:none}
.table-active-filters{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.table-cols-btn{margin-left:auto;flex-shrink:0;background:var(--surface2);border:1px solid var(--border);color:var(--text);border-radius:8px;padding:7px 12px;font-size:12px;font-weight:600;cursor:pointer;transition:all .15s}
.table-cols-btn:hover{border-color:var(--accent);color:var(--accent2)}
.filter-tag{background:rgba(14,165,233,.12);border:1px solid rgba(14,165,233,.3);color:var(--accent2);font-size:10.5px;font-weight:600;padding:3px 8px;border-radius:14px;display:flex;align-items:center;gap:5px}
.filter-tag-x{cursor:pointer;opacity:.7;font-weight:700}
.filter-tag-x:hover{opacity:1}
.filter-clear-all{font-size:11px;color:var(--muted);cursor:pointer;text-decoration:underline;background:none;border:none}
.filter-clear-all:hover{color:var(--text)}

.table-scroll{overflow-x:auto;border:1px solid var(--border);border-radius:10px}
table.aer-table{width:100%;border-collapse:collapse;table-layout:fixed;font-size:12px;min-width:900px}
.aer-table thead th{background:var(--bg2);color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.5px;font-size:10px;text-align:left;padding:0;position:relative;border-bottom:1px solid var(--border);white-space:nowrap;overflow:hidden}
.th-inner{display:flex;align-items:center;gap:6px;padding:11px 12px}
.th-label{flex:1;overflow:hidden;text-overflow:ellipsis}
.th-filter-btn{background:none;border:none;color:var(--muted);cursor:pointer;font-size:11px;padding:2px;border-radius:4px;flex-shrink:0;transition:color .15s;line-height:1}
.th-filter-btn:hover{color:var(--accent2)}
.th-filter-btn.has-filter{color:var(--accent2)}
.col-resizer{position:absolute;right:0;top:0;height:100%;width:6px;cursor:col-resize;user-select:none}
.col-resizer:hover,.col-resizer.resizing{background:var(--accent)}
.aer-table tbody td{padding:10px 12px;border-bottom:1px solid var(--border);color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.aer-table tbody tr:last-child td{border-bottom:none}
.aer-table tbody tr:hover td{background:var(--surface2)}
.cell-muted{color:var(--muted)}
.cell-mono{font-family:'Cascadia Code','Consolas',monospace;font-size:11px}
.status-pill{display:inline-flex;align-items:center;gap:5px;font-size:11px}
.status-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;background:var(--muted)}
.status-dot.ok{background:var(--good)}
.status-dot.warn{background:var(--warn)}
.status-dot.bad{background:var(--bad)}
.portal-btn{display:inline-flex;align-items:center;gap:5px;background:var(--surface2);border:1px solid var(--border);border-radius:6px;padding:4px 9px;font-size:11px;color:var(--accent2);text-decoration:none;white-space:nowrap;transition:all .15s}
.portal-btn:hover{border-color:var(--accent);background:rgba(14,165,233,.1)}

/* ── Filter dropdown ─────────────────────────────────────────────────── */
.filter-dropdown{position:absolute;z-index:200;background:var(--surface);border:1px solid var(--border);border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.4);width:240px;display:none;overflow:hidden}
.filter-dropdown.open{display:block}
.filter-dd-search{padding:10px;border-bottom:1px solid var(--border)}
.filter-dd-search input{width:100%;background:var(--bg2);border:1px solid var(--border);border-radius:7px;padding:6px 10px;font-size:12px;color:var(--text);outline:none}
.filter-dd-search input:focus{border-color:var(--accent)}
.filter-dd-actions{display:flex;justify-content:space-between;padding:8px 12px;border-bottom:1px solid var(--border)}
.filter-dd-action{background:none;border:none;color:var(--accent2);font-size:11px;cursor:pointer;font-weight:600}
.filter-dd-action:hover{text-decoration:underline}
.filter-dd-list{max-height:240px;overflow-y:auto;padding:6px 0}
.filter-dd-item{display:flex;align-items:center;gap:9px;padding:6px 12px;font-size:12px;color:var(--text);cursor:pointer;transition:background .12s}
.filter-dd-item:hover{background:var(--surface2)}
.filter-dd-item input{cursor:pointer;accent-color:var(--accent);flex-shrink:0}
.filter-dd-item-label{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.filter-dd-item-count{color:var(--muted);font-size:10.5px;flex-shrink:0}
.filter-dd-empty{padding:14px;text-align:center;color:var(--muted);font-size:11.5px}

/* ── Table row accordion (resource detail) ───────────────────────────── */
.aer-table tbody tr.data-row{cursor:pointer}
.aer-table tbody tr.data-row .row-chevron{display:inline-block;transition:transform .2s;color:var(--muted);font-size:10px;margin-right:6px}
.aer-table tbody tr.data-row.expanded .row-chevron{transform:rotate(90deg);color:var(--accent2)}
.aer-table tbody tr.data-row.expanded td{background:var(--surface2)}
.detail-row > td{padding:0!important;background:var(--bg2)!important;border-bottom:1px solid var(--border)}
.res-detail{padding:18px 20px;animation:fadein .18s ease}
.res-detail-section{margin-bottom:16px}
.res-detail-section:last-child{margin-bottom:0}
.res-detail-label{font-size:10px;font-weight:600;letter-spacing:1px;text-transform:uppercase;color:var(--muted);margin-bottom:8px}
.res-detail-id{display:flex;align-items:center;gap:8px;background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:9px 12px;font-family:'Cascadia Code','Consolas',monospace;font-size:11.5px;color:var(--text);word-break:break-all;line-height:1.5}
.res-detail-text{font-size:12.5px;color:var(--text);line-height:1.6;background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:10px 13px;overflow-wrap:anywhere}
.res-detail-text ol,.res-detail-text ul{margin:6px 0;padding-left:22px}
.res-detail-text li{margin:3px 0}
.res-detail-text a{color:var(--accent2);word-break:break-all}
.res-detail-text p{margin:6px 0}
.res-detail-text code{background:var(--bg2);padding:1px 5px;border-radius:4px;font-size:11.5px}
.copy-btn{flex-shrink:0;background:var(--surface2);border:1px solid var(--border);border-radius:6px;padding:3px 9px;font-size:10.5px;color:var(--accent2);cursor:pointer;transition:all .15s;white-space:nowrap}
.copy-btn:hover{border-color:var(--accent);background:rgba(14,165,233,.1)}

/* ── Peering / relationship graph ────────────────────────────────────── */
.graph-toolbar{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:12px}
.graph-filters{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.graph-filter-btn{background:var(--surface2);border:1px solid var(--border);color:var(--text);border-radius:8px;padding:6px 11px;font-size:12px;font-weight:600;cursor:pointer;transition:all .15s}
.graph-filter-btn:hover{border-color:var(--accent);color:var(--accent2)}
.graph-filter-btn.active{border-color:var(--accent);color:var(--accent2);background:rgba(14,165,233,.1)}
.graph-wrap{overflow:auto;max-height:700px;cursor:grab;user-select:none;-webkit-user-select:none;border:1px solid var(--border);border-radius:10px;background:var(--bg2)}
.graph-wrap.panning{cursor:grabbing}
.graph-wrap.panning #vnet-graph-svg{pointer-events:none}
#vnet-graph-svg{display:block;margin:auto}
.graph-legend{display:flex;gap:18px;flex-wrap:wrap;margin-top:12px;font-size:11.5px;color:var(--muted)}
.graph-legend-item{display:flex;align-items:center;gap:7px}
.graph-line{display:inline-block;width:22px;height:0;border-top:1.5px solid #3a4a63}
.graph-line.gw{border-top:2px solid #f59e0b}
.graph-dot{display:inline-block;width:11px;height:11px;border-radius:3px}

/* ── Key/value grid (contextual row details) ─────────────────────────── */
.kv-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:14px 28px;align-items:start}
.kv{display:flex;flex-direction:column;gap:4px;min-width:0;padding-right:12px}
.kv-k{font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.kv-v{font-size:13px;color:var(--text);font-weight:600;overflow-wrap:anywhere;word-break:break-word;white-space:normal;line-height:1.45}

/* ── Tag pills ───────────────────────────────────────────────────────── */
.res-tags{display:flex;flex-wrap:wrap;gap:7px}
.tag-pill{display:inline-flex;align-items:center;max-width:100%;border-radius:16px;font-size:11px;font-weight:500;overflow:hidden;border:1px solid rgba(14,165,233,.3)}
.tag-key{padding:3px 8px;font-weight:600;letter-spacing:.2px;background:rgba(14,165,233,.15);color:var(--accent2);flex-shrink:0}
.tag-val{padding:3px 9px;background:rgba(255,255,255,.04);color:var(--text);overflow-wrap:anywhere;min-width:0}
.tags-empty{font-size:11.5px;color:var(--muted);font-style:italic}

/* ── Generic pills (cloud structure accordion) ───────────────────────── */
.pill-row{display:flex;flex-wrap:wrap;gap:8px}
.pill{display:inline-flex;align-items:center;gap:6px;padding:5px 13px;border-radius:16px;font-size:11.5px;font-weight:600;border:1px solid}
.pill-yellow{background:rgba(245,158,11,.15);color:#fbbf24;border-color:rgba(245,158,11,.4)}
.pill-blue{background:rgba(14,165,233,.15);color:#38bdf8;border-color:rgba(14,165,233,.4)}
.pill-cyan{background:rgba(34,211,238,.15);color:#67e8f9;border-color:rgba(34,211,238,.4)}
.pill-purple{background:rgba(167,139,250,.15);color:#c4b5fd;border-color:rgba(167,139,250,.4)}
.pill-orange{background:rgba(251,146,60,.15);color:#fdba74;border-color:rgba(251,146,60,.4)}

/* ── Hierarchy tree diagram (inline SVG org-chart) ───────────────────── */
.tree-toolbar{display:flex;justify-content:space-between;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:14px}
.tree-legend{display:flex;gap:18px;flex-wrap:wrap}
.tree-legend-item{display:flex;align-items:center;gap:7px;font-size:11.5px;color:var(--muted)}
.tree-dot{width:11px;height:11px;border-radius:3px;border:1px solid}
.tree-dot.root{background:rgba(14,165,233,.25);border-color:var(--accent)}
.tree-dot.mg{background:rgba(167,139,250,.2);border-color:rgba(167,139,250,.5)}
.tree-dot.sub{background:rgba(245,158,11,.2);border-color:rgba(245,158,11,.5)}
.tree-controls{display:flex;align-items:center;gap:6px}
.tree-btn{background:var(--surface);border:1px solid var(--border);color:var(--text);border-radius:8px;padding:6px 11px;font-size:12px;font-weight:600;cursor:pointer;line-height:1;transition:background .15s,border-color .15s,color .15s}
.tree-btn:hover:not(:disabled){border-color:var(--accent);color:var(--accent2)}
.tree-btn:disabled{opacity:.45;cursor:not-allowed}
.tree-btn.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.tree-btn.primary:hover:not(:disabled){filter:brightness(1.08);color:#fff}
.tree-zoom-label{font-size:12px;color:var(--muted);min-width:44px;text-align:center;font-variant-numeric:tabular-nums}
.tree-wrap{overflow:auto;padding:14px 6px 28px;max-height:660px;cursor:grab;user-select:none;-webkit-user-select:none}
.tree-wrap.panning{cursor:grabbing}
.tree-wrap.panning #mg-svg{pointer-events:none}
#mg-svg{display:block}
ul.tree{display:flex;justify-content:center;gap:26px;padding:0;margin:0;min-width:min-content}
ul.tree, .tree ul{list-style:none}
.tree ul{position:relative;padding-top:24px;display:flex;justify-content:center;margin:0}
.tree li{list-style:none;position:relative;padding:24px 12px 0;display:flex;flex-direction:column;align-items:center}
.tree li::before,.tree li::after{content:'';position:absolute;top:0;right:50%;border-top:1px solid var(--border);width:50%;height:24px}
.tree li::after{right:auto;left:50%;border-left:1px solid var(--border)}
.tree li:only-child::before,.tree li:only-child::after{display:none}
.tree li:only-child{padding-top:24px}
.tree li:first-child::before,.tree li:last-child::after{border:0 none}
.tree li:last-child::before{border-right:1px solid var(--border);border-radius:0 6px 0 0}
.tree li:first-child::after{border-radius:6px 0 0 0}
.tree ul::before{content:'';position:absolute;top:0;left:50%;border-left:1px solid var(--border);width:0;height:24px}
ul.tree > li{padding-top:0}
ul.tree > li::before,ul.tree > li::after{display:none}
.tree-node{display:inline-flex;align-items:center;gap:7px;border:1px solid var(--border);border-radius:10px;padding:9px 14px;font-size:12px;font-weight:600;white-space:nowrap;background:var(--surface);max-width:220px;overflow:hidden;text-overflow:ellipsis;transition:transform .15s,box-shadow .15s}
.tree-node:hover{transform:translateY(-1px);box-shadow:0 4px 14px rgba(0,0,0,.25)}
.tree-node.tree-root{border-color:var(--accent);background:rgba(14,165,233,.12);color:var(--accent2);font-weight:700}
.tree-node.tree-mg{border-color:rgba(167,139,250,.5);background:rgba(167,139,250,.1);color:#c4b5fd}
.tree-node.tree-sub{border-color:rgba(245,158,11,.45);background:rgba(245,158,11,.1);color:#fbbf24}

/* ── Footer ──────────────────────────────────────────────────────────── */
.footer{border-top:1px solid var(--border);padding:13px 28px;display:flex;justify-content:space-between;align-items:center;font-size:11px;color:var(--muted);flex-shrink:0}
'@
}
