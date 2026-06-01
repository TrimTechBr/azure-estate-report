function Get-AerAppJs {
    return @'
(function () {
  var d    = window.AerData || {};
  var inv  = d.inventory || {};
  var sec  = d.security  || {};
  var cost = d.cost      || {};
  var adv  = d.advisor   || {};
  var vm   = d.virtualMachines || {};
  var vmss = d.virtualMachineScaleSets || {};
  var db   = d.databases || {};
  var rel  = d.relationalDatabases || {};
  var meta = d.metadata  || {};
  var tenant = meta.TenantDomain || '';

  /* ── Helpers ──────────────────────────────────────────────────────── */
  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html !== undefined) e.innerHTML = html;
    return e;
  }
  function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }
  function pct(v, t) { return t > 0 ? Math.round(v / t * 100) : 0; }
  /* ConvertTo-Json unwraps single-element arrays to objects (and [] to null);
     normalise anything we treat as a list back into a real array. */
  function toArr(x) { return Array.isArray(x) ? x : (x == null ? [] : [x]); }
  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
  var COLORS = ['#0ea5e9','#6366f1','#22c55e','#f59e0b','#a78bfa',
                '#34d399','#f472b6','#fb923c','#38bdf8','#4ade80'];

  /* ── Theme: dark only (light mode removed; data-theme="dark" is set in HTML) ── */

  /* ── Sidebar: collapse, groups & menu search ──────────────────────── */
  var sidebarNav = document.getElementById('sidebar-nav');
  /* localStorage can throw on file:// (null origin) — never let it block the UI */
  function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function lsSet(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  /* whole-sidebar collapse (icon rail), persisted across pages */
  var sbCollapsed = lsGet('aer-sidebar-collapsed') === '1';
  function applySidebarCollapsed() {
    document.body.classList.toggle('sidebar-collapsed', sbCollapsed);
    var t = document.getElementById('sidebar-toggle');
    if (t) t.title = sbCollapsed ? 'Expand sidebar' : 'Collapse sidebar';
  }
  applySidebarCollapsed();
  var sbToggle = document.getElementById('sidebar-toggle');
  if (sbToggle) sbToggle.addEventListener('click', function () {
    sbCollapsed = !sbCollapsed;
    applySidebarCollapsed();                                   /* apply visual change first … */
    lsSet('aer-sidebar-collapsed', sbCollapsed ? '1' : '0');   /* … then persist */
  });

  /* collapsible parent groups, persisted per group */
  Array.prototype.slice.call(document.querySelectorAll('.sidebar-nav .nav-group')).forEach(function (g) {
    var key = 'aer-nav-' + g.getAttribute('data-group');
    if (lsGet(key) === '1') g.classList.add('collapsed');
    var sec = g.querySelector('.nav-section');
    if (sec) sec.addEventListener('click', function () {
      if (document.body.classList.contains('sidebar-collapsed')) return;
      g.classList.toggle('collapsed');
      lsSet(key, g.classList.contains('collapsed') ? '1' : '0');
    });
  });

  /* menu search (filters items; force-expands groups while searching) */
  var menuSearch = document.getElementById('menu-search');
  if (menuSearch) {
    var navItems = Array.prototype.slice.call(document.querySelectorAll('.sidebar-nav .nav-item'));
    var navSections = Array.prototype.slice.call(document.querySelectorAll('.sidebar-nav .nav-section'));
    var navEmpty = document.getElementById('nav-empty');
    menuSearch.addEventListener('input', function (e) {
      var q = e.target.value.toLowerCase().trim();
      var anyVisible = false;
      navItems.forEach(function (item) {
        var label = (item.querySelector('.nav-label') || {}).textContent || '';
        var show = !q || label.toLowerCase().indexOf(q) !== -1;
        item.style.display = show ? '' : 'none';
        if (show) anyVisible = true;
      });
      // when searching, hide section headers and force groups open for a clean list
      navSections.forEach(function (s) { s.style.display = q ? 'none' : ''; });
      if (sidebarNav) sidebarNav.classList.toggle('searching', !!q);
      if (navEmpty) navEmpty.style.display = anyVisible ? 'none' : 'block';
    });
  }

  /* ── Sidebar badges ───────────────────────────────────────────────── */
  function setBadge(page, count, cls) {
    var nb = document.querySelector('[data-page="' + page + '"] .nav-badge');
    if (!nb) return;
    nb.className = 'nav-badge ' + (cls || '');
    nb.textContent = count > 999 ? '999+' : String(count);
    nb.style.display = count > 0 ? 'inline' : 'none';
  }
  setBadge('security', sec.TotalGaps || 0, 'bad');
  setBadge('cost', cost.TotalWastedResources || 0, 'warn');

  /* ── Error banner ─────────────────────────────────────────────────── */
  var errs = toArr(d.collectionErrors);
  if (errs.length > 0) {
    var errEl = document.getElementById('err-banner');
    if (errEl) errEl.appendChild(el('div', 'warn-banner',
      '⚠ ' + errs.length + ' collection error(s) — some data may be incomplete. ' +
      'Collectors with errors: ' + errs.map(function (e) { return e.Collector; }).join(', ')
    ));
  }

  /* ════════════════════════════ OVERVIEW ════════════════════════════ */

  /* KPI cards */
  var kpiGrid = document.getElementById('kpi-grid');
  if (kpiGrid) {
    [
      { label:'Management Groups', value:fmt(inv.ManagementGroups), hint:'in tenant hierarchy',         cls:'purple', icon:'⬡' },
      { label:'Subscriptions',     value:fmt(inv.Subscriptions),    hint:'enabled · scanned',           cls:'blue',   icon:'☁' },
      { label:'Resource Groups',   value:fmt(inv.TotalResourceGroups), hint:'across all subscriptions', cls:'cyan',   icon:'▦' },
      { label:'Total Resources',   value:fmt(inv.TotalResources),   hint:'across all subscriptions',    cls:'sky',    icon:'◈' }
    ].forEach(function (k) {
      kpiGrid.appendChild(el('div', 'kpi-card ' + k.cls,
        '<div class="kpi-icon">' + k.icon + '</div>' +
        '<div class="kpi-label">' + k.label + '</div>' +
        '<div class="kpi-value">' + k.value + '</div>' +
        '<div class="kpi-hint">' + k.hint + '</div>'
      ));
    });
  }

  /* Donut: resources by subscription (top N named + aggregated "Others") */
  var donutEl = document.getElementById('chart-by-sub');
  var bySubList = toArr(inv.BySubscription);
  if (donutEl && bySubList.length) {
    var allSubs = bySubList.slice().sort(function (a, b) { return (b.Count || 0) - (a.Count || 0); });
    var subTotal = allSubs.reduce(function (acc, x) { return acc + (x.Count || 0); }, 0);
    var total = inv.TotalResources || subTotal || 1;
    var TOP = 8;
    var segs = allSubs.slice(0, TOP).map(function (s, i) {
      return { name: s.SubscriptionName || s.SubscriptionId || '—', count: s.Count || 0, color: COLORS[i % COLORS.length] };
    });
    var rest = allSubs.slice(TOP);
    if (rest.length) {
      var othersCount = rest.reduce(function (acc, x) { return acc + (x.Count || 0); }, 0);
      segs.push({
        name: 'Others (' + rest.length + ' subscription' + (rest.length > 1 ? 's' : '') + ')',
        count: othersCount, color: '#64748b'
      });
    }
    var offset = 25;
    var circles = segs.map(function (seg) {
      var p = pct(seg.count, total);
      var o = -offset; offset -= p;
      return '<circle cx="18" cy="18" r="15.9" fill="none" stroke="' + seg.color +
             '" stroke-width="4" stroke-dasharray="' + p + ' ' + (100 - p) +
             '" stroke-dashoffset="' + o + '"/>';
    });
    var legend = segs.map(function (seg) {
      return '<div class="legend-item">' +
        '<span class="legend-dot" style="background:' + seg.color + '"></span>' +
        '<span class="legend-label" title="' + esc(seg.name) + '">' + esc(seg.name) + '</span>' +
        '<span class="legend-val">' + fmt(seg.count) + '</span></div>';
    }).join('');
    donutEl.innerHTML =
      '<div class="donut-wrap">' +
        '<svg width="86" height="86" viewBox="0 0 36 36" style="flex-shrink:0">' +
          '<circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--bg2)" stroke-width="4"/>' +
          circles.join('') +
          '<text x="18" y="20" text-anchor="middle" fill="var(--text)" font-size="4.5" font-weight="700">' + fmt(total) + '</text>' +
        '</svg><div style="flex:1;min-width:0">' + legend + '</div></div>';
  }

  /* Bar charts */
  function renderBars(id, rows, labelKey, countKey) {
    var wrap = document.getElementById(id);
    if (!wrap) return;
    rows = toArr(rows);
    if (!rows.length) { wrap.innerHTML = '<div class="empty-state">No data available.</div>'; return; }
    var max = Math.max.apply(null, rows.map(function (r) { return r[countKey] || 0; })) || 1;
    wrap.innerHTML = rows.slice(0, 7).map(function (r, i) {
      return '<div class="bar-item">' +
        '<span class="bar-label">' + esc(r[labelKey] || '—') + '</span>' +
        '<div class="bar-track"><div class="bar-fill" style="width:' + pct(r[countKey], max) + '%;background:' + COLORS[i % COLORS.length] + '"></div></div>' +
        '<span class="bar-count">' + fmt(r[countKey]) + '</span></div>';
    }).join('');
  }
  function renderDonut(elId, segs, total, centerText) {
    var elx = document.getElementById(elId);
    if (!elx) return;
    segs = toArr(segs).filter(function (s) { return (s.count || 0) > 0; });
    if (!segs.length) { elx.innerHTML = '<div class="empty-state">No data available.</div>'; return; }
    total = total || segs.reduce(function (a, s) { return a + (s.count || 0); }, 0) || 1;
    var offset = 25;
    var circles = segs.map(function (s, i) {
      var p = pct(s.count, total); var o = -offset; offset -= p;
      var color = s.color || COLORS[i % COLORS.length];
      return '<circle cx="18" cy="18" r="15.9" fill="none" stroke="' + color +
        '" stroke-width="4" stroke-dasharray="' + p + ' ' + (100 - p) + '" stroke-dashoffset="' + o + '"/>';
    });
    var legend = segs.map(function (s, i) {
      var color = s.color || COLORS[i % COLORS.length];
      return '<div class="legend-item"><span class="legend-dot" style="background:' + color + '"></span>' +
        '<span class="legend-label" title="' + esc(s.name) + '">' + esc(s.name) + '</span>' +
        '<span class="legend-val">' + fmt(s.count) + '</span></div>';
    }).join('');
    elx.innerHTML = '<div class="donut-wrap"><svg width="86" height="86" viewBox="0 0 36 36" style="flex-shrink:0">' +
      '<circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--bg2)" stroke-width="4"/>' + circles.join('') +
      '<text x="18" y="20" text-anchor="middle" fill="var(--text)" font-size="4.5" font-weight="700">' + (centerText || fmt(total)) + '</text>' +
      '</svg><div style="flex:1;min-width:0">' + legend + '</div></div>';
  }
  renderBars('chart-by-type',   toArr(inv.ByType),   'Type',   'Count');
  renderBars('chart-by-region', toArr(inv.ByRegion), 'Region', 'Count');

  /* Advisor (shared renderer for overview + advisor page) */
  function renderAdvisor(gridId, badgeId) {
    var grid = document.getElementById(gridId);
    var badge = document.getElementById(badgeId);
    if (badge) badge.textContent = fmt(adv.HighImpactCount || 0) + ' High Impact';
    if (!grid) return;
    var icons  = { Security:'🔒', Reliability:'⚡', Cost:'💰', Performance:'📈', OperationalExcellence:'⭐' };
    var labels = { OperationalExcellence: 'Operational Excellence' };
    grid.innerHTML = '';
    var cats = toArr(adv.ByCategory).filter(function (cat) { return (cat.Count || 0) > 0; });
    if (!cats.length) { grid.innerHTML = '<div class="empty-state">✓ No recommendations.</div>'; return; }
    cats.forEach(function (cat) {
      var css = cat.Category === 'OperationalExcellence' ? 'excellence' : cat.Category.toLowerCase();
      grid.appendChild(el('div', 'advisor-cat ' + css,
        '<div class="advisor-cat-icon">' + (icons[cat.Category] || '•') + '</div>' +
        '<div><div class="advisor-cat-count">' + fmt(cat.Count) + '</div>' +
        '<div class="advisor-cat-label">' + (labels[cat.Category] || cat.Category) + '</div>' +
        '<div class="advisor-cat-sub">recommendations</div></div>'
      ));
    });
  }
  renderAdvisor('advisor-grid', 'advisor-high-badge');
  renderAdvisor('advisor-grid-pg', 'advisor-high-badge-pg');

  /* Overview issue lists (full, as original index.html) */
  function issueHtml(item, kind) {
    if (kind === 'security') {
      return '<span class="badge ' + (item.Severity || '').toLowerCase() + '">' + esc(item.Severity) + '</span>' +
        '<div class="issue-text"><div class="issue-title">' + esc(item.Title) + '</div>' +
        '<div class="issue-sub">' + esc(item.ResourceType) + '</div></div>' +
        '<span class="issue-count">' + fmt(item.Count) + '</span>';
    }
    return '<span class="badge waste">waste</span>' +
      '<div class="issue-text"><div class="issue-title">' + esc(item.Title) + '</div>' +
      '<div class="issue-sub">' + esc(item.Note) + '</div></div>' +
      '<span class="issue-count">' + fmt(item.Count) + '</span>';
  }
  function renderListFull(containerId, items, kind) {
    var c = document.getElementById(containerId);
    if (!c) return;
    var rows = (items || []).filter(function (it) { return (it.Count || 0) > 0; });
    if (!rows.length) { c.innerHTML = '<div class="empty-state">✓ No affected resources found.</div>'; return; }
    c.innerHTML = rows.map(function (it) { return '<div class="issue-item">' + issueHtml(it, kind) + '</div>'; }).join('');
  }
  renderListFull('security-list-ov', toArr(sec.Items), 'security');
  renderListFull('cost-list-ov', toArr(cost.Items), 'cost');

  /* ════════════════════════════ HEADERS ═════════════════════════════ */
  function setHeader(id, icon, title, subtitle, chipsHtml) {
    var h = document.getElementById(id);
    if (!h) return;
    h.innerHTML =
      '<div class="page-header-icon">' + icon + '</div>' +
      '<div><div class="page-header-title">' + title + '</div>' +
      '<div class="page-header-sub">' + subtitle + '</div></div>' +
      '<div class="page-header-chips">' + (chipsHtml || '') + '</div>';
  }
  setHeader('inv-header', '📦', 'Resource Inventory',
    'Complete list of resources across all scanned subscriptions',
    '<span class="chip blue">' + fmt(inv.TotalResources) + ' resources</span>' +
    '<span class="chip good">' + fmt(inv.TotalResourceGroups) + ' resource groups</span>');
  setHeader('sec-header', '📋', 'General Findings',
    'Security, governance and configuration gaps detected across your environment',
    '<span class="chip bad">' + fmt(sec.TotalGaps) + ' findings</span>');
  setHeader('cost-header', '💰', 'Cost Optimization',
    'Orphaned or idle resources that may be incurring unnecessary costs',
    '<span class="chip warn">' + fmt(cost.TotalWastedResources) + ' resources to review</span>');
  setHeader('adv-header', '⭐', 'Azure Advisor',
    'Microsoft recommendations for reliability, security, cost and performance',
    '<span class="chip blue">' + fmt(adv.TotalRecommendations) + ' total</span>');
  var struct = d.structure || {};
  var mgRows = toArr(struct.ManagementGroups);
  var subRows = toArr(struct.Subscriptions);
  setHeader('cs-header', '🏛️', 'Cloud Structure',
    'Management group hierarchy and subscription placement across the tenant',
    '<span class="chip blue">' + fmt(mgRows.length) + ' management groups</span>' +
    '<span class="chip good">' + fmt(subRows.length) + ' subscriptions</span>');

  setHeader('vm-header', '🖥️', 'Virtual Machines',
    'Compute inventory across all scanned subscriptions',
    '<span class="chip blue">' + fmt(vm.TotalVMs || 0) + ' VMs</span>');

  /* Virtual Machines — summary tiles */
  var vmTiles = document.getElementById('vm-tiles');
  if (vmTiles) {
    [
      { icon: '🖥️', label: 'Total VMs',    value: fmt(vm.TotalVMs || 0) },
      { icon: '🐧', label: 'Linux VMs',    value: fmt(vm.LinuxVMs || 0) },
      { icon: '🪟', label: 'Windows VMs',  value: fmt(vm.WindowsVMs || 0) },
      { icon: '⚙',  label: 'Total vCores', value: fmt(vm.TotalvCores || 0) },
      { icon: '▤',  label: 'Total Memory', value: fmt(vm.TotalMemoryGB || 0), unit: 'GB' },
      { icon: '▦',  label: 'Total Disk',   value: fmt(vm.TotalDiskGB || 0), unit: 'GB' }
    ].forEach(function (t) {
      vmTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + (t.unit ? '<span class="stat-tile-unit">' + t.unit + '</span>' : '') + '</div>'));
    });
  }

  /* ════════════════ PAGINATED ISSUE LISTS (Security/Cost) ════════════ */
  function makePaginatedList(containerId, pagerId, items, kind, pageSize) {
    var container = document.getElementById(containerId);
    var pager = document.getElementById(pagerId);
    if (!container) return;
    // hide zero-count items
    var rows = (items || []).filter(function (it) { return (it.Count || 0) > 0; });
    var page = 0;
    var totalPages = Math.max(1, Math.ceil(rows.length / pageSize));

    function render() {
      if (!rows.length) {
        container.innerHTML = '<div class="empty-state">✓ No affected resources found.</div>';
        if (pager) pager.style.display = 'none';
        return;
      }
      var slice = rows.slice(page * pageSize, (page + 1) * pageSize);
      container.innerHTML = slice.map(function (it) {
        return '<div class="issue-item">' + issueHtml(it, kind) + '</div>';
      }).join('');
      renderPager(pager, page, totalPages, rows.length, pageSize, function (p) { page = p; render(); });
    }
    render();
  }
  /* ════════════ FINDINGS TABLES (Security / Cost / Observability) ════════ */
  function findingResourcesDetail(row) {
    var res = toArr(row.resources);
    if (!res.length) return '<div class="res-detail"><span class="tags-empty">No affected resources captured.</span></div>';
    var body = res.map(function (x) {
      return '<tr><td>' + esc(x.Name || '—') + '</td><td>' + monoCell(x.Type || '—') + '</td><td>' + esc(x.ResourceGroup || '—') + '</td><td>' + esc(x.SubscriptionName || '—') + '</td><td>' + portalLink(x.Id) + '</td></tr>';
    }).join('');
    var more = (row.count > res.length) ? '<div class="cell-muted" style="margin-top:6px">Showing first ' + res.length + ' of ' + fmt(row.count) + '.</div>' : '';
    return '<div class="res-detail"><div class="res-detail-section">' +
      '<div class="res-detail-label">Affected resources (' + fmt(row.count) + ')</div>' +
      '<div class="table-scroll"><table class="aer-table simple"><thead><tr><th>Resource</th><th>Type</th><th>Resource group</th><th>Subscription</th><th></th></tr></thead><tbody>' +
      body + '</tbody></table></div>' + more + '</div></div>';
  }
  function sevBadge(s) { return '<span class="badge ' + String(s || 'info').toLowerCase() + '">' + esc(s || '—') + '</span>'; }

  initDataTable({
    ids: { thead:'secf-thead', tbody:'secf-tbody', colgroup:'secf-colgroup', pager:'secf-pager', tags:'secf-active-filters', search:'secf-global-search' },
    pageSize: 15, emptyText: '✓ No security findings.',
    data: toArr(sec.Items).filter(function (it) { return (it.Count || 0) > 0; }).map(function (r) {
      return { severity: r.Severity || 'Info', title: r.Title || '—', restype: r.ResourceType || '—', count: (r.Count || 0), resources: toArr(r.Resources) };
    }),
    columns: [
      { key:'severity', label:'Severity',           width:110, render:function (r) { return sevBadge(r.severity); } },
      { key:'title',    label:'Finding',            width:360 },
      { key:'restype',  label:'Affected Type',      width:240, render:function (r) { return monoCell(r.restype); } },
      { key:'count',    label:'Affected Resources', width:160, render:function (r) { return fmt(r.count); } }
    ],
    detail: findingResourcesDetail
  });

  initDataTable({
    ids: { thead:'costf-thead', tbody:'costf-tbody', colgroup:'costf-colgroup', pager:'costf-pager', tags:'costf-active-filters', search:'costf-global-search' },
    pageSize: 15, emptyText: '✓ No cost findings.',
    data: toArr(cost.Items).filter(function (it) { return (it.Count || 0) > 0; }).map(function (r) {
      return { title: r.Title || '—', restype: r.ResourceType || '—', note: r.Note || '', count: (r.Count || 0), resources: toArr(r.Resources) };
    }),
    columns: [
      { key:'title',   label:'Finding',            width:280 },
      { key:'restype', label:'Affected Type',      width:230, render:function (r) { return monoCell(r.restype); } },
      { key:'note',    label:'Reason',             width:280 },
      { key:'count',   label:'Affected Resources', width:160, render:function (r) { return fmt(r.count); } }
    ],
    detail: findingResourcesDetail
  });

  /* Observability recommendations — derived client-side from collected data */
  var obsFindings = [];
  (function () {
    function pushF(sev, title, restype, list) {
      list = toArr(list);
      if (list.length) obsFindings.push({ severity: sev, title: title, restype: restype, count: list.length, resources: list });
    }
    pushF('Medium', 'Resources without diagnostic settings', 'diagnosable resources',
      toArr((d.diagnosticSettings || {}).Resources).filter(function (r) { return !r.Enabled; })
        .map(function (r) { return { Name: r.Name, Type: r.Type, ResourceGroup: r.ResourceGroup, SubscriptionName: r.SubscriptionName, Id: r.Id }; }));
    pushF('Medium', 'VM / Arc machines without Azure Monitor Agent', 'machines',
      toArr((d.dataCollection || {}).Machines).filter(function (m) { return !m.AmaInstalled; })
        .map(function (m) { return { Name: m.Name, Type: m.Kind, ResourceGroup: m.ResourceGroup, SubscriptionName: m.SubscriptionName, Id: m.Id }; }));
    pushF('Low', 'Log Analytics workspaces with retention under 30 days', 'workspaces',
      toArr((d.obsInventory || {}).Workspaces).filter(function (w) { return w.Retention && w.Retention < 30; })
        .map(function (w) { return { Name: w.Name, Type: 'log analytics', ResourceGroup: w.ResourceGroup, SubscriptionName: w.SubscriptionName, Id: w.Id }; }));
    pushF('Info', 'Log Analytics workspaces without data export to storage', 'workspaces',
      toArr((d.obsInventory || {}).Workspaces).filter(function (w) { return !w.ExportToStorage; })
        .map(function (w) { return { Name: w.Name, Type: 'log analytics', ResourceGroup: w.ResourceGroup, SubscriptionName: w.SubscriptionName, Id: w.Id }; }));
  })();
  var obsSevOrder = { Critical: 0, High: 1, Medium: 2, Low: 3, Info: 4 };
  setBadge('obsfindings', obsFindings.length, 'warn');
  setHeader('obsf-header', '📈', 'Observability Recommendations',
    'Monitoring coverage gaps detected across the scanned environment',
    '<span class="chip warn">' + fmt(obsFindings.reduce(function (a, f) { return a + f.count; }, 0)) + ' resources to review</span>');
  initDataTable({
    ids: { thead:'obsf-thead', tbody:'obsf-tbody', colgroup:'obsf-colgroup', pager:'obsf-pager', tags:'obsf-active-filters', search:'obsf-global-search' },
    pageSize: 15, emptyText: '✓ No observability gaps detected.',
    data: obsFindings.map(function (r) {
      return { severity: r.severity, title: r.title, restype: r.restype, count: r.count, resources: r.resources };
    }).sort(function (a, b) { return (obsSevOrder[a.severity] != null ? obsSevOrder[a.severity] : 9) - (obsSevOrder[b.severity] != null ? obsSevOrder[b.severity] : 9); }),
    columns: [
      { key:'severity', label:'Severity',           width:110, render:function (r) { return sevBadge(r.severity); } },
      { key:'title',    label:'Recommendation',     width:360 },
      { key:'restype',  label:'Affected Type',      width:200, render:function (r) { return monoCell(r.restype); } },
      { key:'count',    label:'Affected Resources', width:160, render:function (r) { return fmt(r.count); } }
    ],
    detail: findingResourcesDetail
  });

  /* ════════════════════════ SHARED PAGER ════════════════════════════ */
  function renderPager(pager, page, totalPages, totalItems, pageSize, onGo) {
    if (!pager) return;
    pager.style.display = 'flex';
    var from = totalItems === 0 ? 0 : page * pageSize + 1;
    var to = Math.min((page + 1) * pageSize, totalItems);
    var info = el('div', 'pager-info', 'Showing ' + from + '–' + to + ' of ' + fmt(totalItems));
    var ctrl = el('div', 'pager-controls');

    function mkBtn(label, targetPage, opts) {
      opts = opts || {};
      var b = el('button', 'pager-btn' + (opts.active ? ' active' : ''), label);
      if (opts.disabled) b.disabled = true;
      else b.addEventListener('click', function () { onGo(targetPage); });
      return b;
    }
    ctrl.appendChild(mkBtn('‹', page - 1, { disabled: page === 0 }));

    // numbered window
    var pages = [];
    for (var i = 0; i < totalPages; i++) {
      if (i === 0 || i === totalPages - 1 || Math.abs(i - page) <= 1) pages.push(i);
      else if (pages[pages.length - 1] !== '…') pages.push('…');
    }
    pages.forEach(function (p) {
      if (p === '…') ctrl.appendChild(el('span', 'pager-ellipsis', '…'));
      else ctrl.appendChild(mkBtn(String(p + 1), p, { active: p === page }));
    });

    ctrl.appendChild(mkBtn('›', page + 1, { disabled: page >= totalPages - 1 }));
    pager.innerHTML = '';
    pager.appendChild(info);
    pager.appendChild(ctrl);
  }

  /* ════════════════ SIMPLE PAGINATED TABLE (Cloud Structure) ═════════ */
  function initSimpleTable(cfg) {
    var tbody = document.getElementById(cfg.tbodyId);
    var pager = document.getElementById(cfg.pagerId);
    if (!tbody) return;
    var rows = cfg.rows || [];
    var page = 0, PAGE_SIZE = 5, slice = [];

    function render() {
      var totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
      if (page >= totalPages) page = totalPages - 1;
      if (page < 0) page = 0;
      slice = rows.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);
      if (!slice.length) {
        tbody.innerHTML = '<tr><td colspan="' + cfg.colspan + '"><div class="empty-state">' + cfg.emptyText + '</div></td></tr>';
      } else {
        tbody.innerHTML = slice.map(function (row, idx) {
          var cells = cfg.renderCells(row).slice();
          if (cfg.detail) cells[0] = '<span class="row-chevron">&#9656;</span>' + cells[0];
          var attr = cfg.detail ? ' class="data-row" data-idx="' + idx + '"' : '';
          return '<tr' + attr + '>' + cells.map(function (c) { return '<td>' + c + '</td>'; }).join('') + '</tr>';
        }).join('');
      }
      renderPager(pager, page, totalPages, rows.length, PAGE_SIZE, function (p) { page = p; render(); });
    }

    if (cfg.detail) {
      tbody.addEventListener('click', function (e) {
        var tr = e.target.closest('tr.data-row');
        if (!tr) return;
        var idx = parseInt(tr.getAttribute('data-idx'), 10);
        var next = tr.nextElementSibling;
        if (next && next.classList.contains('detail-row')) {
          next.parentNode.removeChild(next);
          tr.classList.remove('expanded');
        } else {
          tr.classList.add('expanded');
          var dr = document.createElement('tr');
          dr.className = 'detail-row';
          dr.innerHTML = '<td colspan="' + cfg.colspan + '">' + cfg.detail(slice[idx]) + '</td>';
          tr.parentNode.insertBefore(dr, tr.nextSibling);
        }
      });
    }
    render();
  }

  initSimpleTable({
    tbodyId: 'mg-tbody', pagerId: 'mg-pager', colspan: 3,
    rows: toArr((d.structure || {}).ManagementGroups),
    emptyText: 'No management groups found.',
    renderCells: function (r) {
      return [monoCell(r.Id), esc(r.Name || '—'), esc(r.Parent || '—')];
    },
    detail: function (r) {
      var groups = toArr(r.ChildGroups);
      var subs = toArr(r.Subscriptions);
      var html = '<div class="res-detail">';
      if (groups.length) {
        html += '<div class="res-detail-section">' +
          '<div class="res-detail-label">Child management groups (' + groups.length + ')</div>' +
          '<div class="pill-row">' + groups.map(function (g) {
            return '<span class="pill pill-purple">🏛 ' + esc(g) + '</span>';
          }).join('') + '</div></div>';
      }
      var subBody = subs.length
        ? '<div class="pill-row">' + subs.map(function (s) {
            return '<span class="pill pill-yellow">☁ ' + esc(s) + '</span>';
          }).join('') + '</div>'
        : '<span class="tags-empty">No subscriptions directly under this management group</span>';
      html += '<div class="res-detail-section">' +
        '<div class="res-detail-label">Subscriptions (' + subs.length + ')</div>' + subBody +
        '</div></div>';
      return html;
    }
  });

  initSimpleTable({
    tbodyId: 'sub-tbody', pagerId: 'sub-pager', colspan: 3,
    rows: toArr((d.structure || {}).Subscriptions),
    emptyText: 'No subscriptions found.',
    renderCells: function (r) {
      return [monoCell(r.Id), esc(r.Name || '—'), esc(r.ManagementGroup || '—')];
    },
    detail: function (r) {
      return '<div class="res-detail"><div class="res-detail-section">' +
        '<div class="res-detail-label">Contents</div><div class="pill-row">' +
          '<span class="pill pill-blue">📁 ' + fmt(r.ResourceGroupCount || 0) + ' resource groups</span>' +
          '<span class="pill pill-cyan">◈ ' + fmt(r.ResourceCount || 0) + ' resources</span>' +
        '</div></div></div>';
    }
  });

  /* ── Management group hierarchy diagram (inline SVG org-chart) ── */
  (function renderMgTree() {
    var wrap = document.getElementById('mg-tree-wrap');
    if (!wrap) return;
    var ctrls = ['mg-zoom-in', 'mg-zoom-out', 'mg-zoom-reset', 'mg-export-png', 'mg-export-svg'];
    function setControls(on) {
      ctrls.forEach(function (id) { var b = document.getElementById(id); if (b) b.disabled = !on; });
    }

    var mgList = toArr((d.structure || {}).ManagementGroups);
    if (!mgList.length) {
      wrap.innerHTML = '<div class="empty-state">No management group hierarchy available.</div>';
      setControls(false);
      return;
    }

    var byName = {};
    mgList.forEach(function (m) { byName[m.Name] = m; });
    var childNames = {};
    mgList.forEach(function (m) { toArr(m.ChildGroups).forEach(function (c) { childNames[c] = true; }); });
    var roots = mgList.filter(function (m) { return !childNames[m.Name]; });
    if (!roots.length) roots = [mgList[0]];

    /* Build an in-memory node tree (mg → child mgs → subscriptions) */
    var seen = {};
    function build(mg, type) {
      if (seen[mg.Name]) return null;
      seen[mg.Name] = true;
      var n = { label: mg.Name, type: type, children: [] };
      toArr(mg.ChildGroups).forEach(function (cn) {
        var cm = byName[cn] || { Name: cn, ChildGroups: [], Subscriptions: [] };
        var c = build(cm, 'mg');
        if (c) n.children.push(c);
      });
      toArr(mg.Subscriptions).forEach(function (s) {
        n.children.push({ label: s, type: 'sub', children: [] });
      });
      return n;
    }
    var forest = roots.map(function (r) { return build(r, 'root'); }).filter(Boolean);
    var treeRoot = forest.length === 1
      ? forest[0]
      : { label: tenant || 'Tenant Root', type: 'root', children: forest };

    /* Tidy-tree layout: leaves get sequential slots, parents centre over kids */
    var NODE_W = 178, NODE_H = 48, H_GAP = 24, V_GAP = 58, PAD = 22;
    var nextX = 0;
    (function layout(n, depth) {
      n.y = PAD + depth * (NODE_H + V_GAP);
      if (!n.children.length) { n.x = PAD + nextX * (NODE_W + H_GAP); nextX++; }
      else {
        n.children.forEach(function (c) { layout(c, depth + 1); });
        n.x = (n.children[0].x + n.children[n.children.length - 1].x) / 2;
      }
    })(treeRoot, 0);

    var maxX = 0, maxY = 0;
    (function bounds(n) {
      maxX = Math.max(maxX, n.x + NODE_W); maxY = Math.max(maxY, n.y + NODE_H);
      n.children.forEach(bounds);
    })(treeRoot);
    var W = Math.round(maxX + PAD), H = Math.round(maxY + PAD);

    /* Inline-styled SVG so the raster/vector export matches without external CSS */
    var palette = {
      root: { fill: '#0c2c3f', stroke: '#0ea5e9', text: '#7dd3fc', icon: '🏛' },
      mg:   { fill: '#241d3d', stroke: '#a78bfa', text: '#c4b5fd', icon: '🏛' },
      sub:  { fill: '#33280f', stroke: '#f59e0b', text: '#fbbf24', icon: '☁' }
    };
    /* Wrap a label into up to maxLines lines of ~maxChars, ellipsis if it overflows */
    function wrapLabel(text, maxChars, maxLines) {
      var words = String(text == null ? '' : text).split(/\s+/), lines = [], cur = '';
      words.forEach(function (w) {
        var t = cur ? cur + ' ' + w : w;
        if (!cur || t.length <= maxChars) cur = t;
        else { lines.push(cur); cur = w; }
      });
      if (cur) lines.push(cur);
      if (lines.length > maxLines) {
        lines = lines.slice(0, maxLines);
        lines[maxLines - 1] = lines[maxLines - 1].slice(0, maxChars - 1) + '…';
      }
      return lines.map(function (l) { return l.length > maxChars ? l.slice(0, maxChars - 1) + '…' : l; });
    }
    var edges = '', nodes = '';
    (function draw(n) {
      n.children.forEach(function (c) {
        var x1 = n.x + NODE_W / 2, y1 = n.y + NODE_H, x2 = c.x + NODE_W / 2, y2 = c.y, my = (y1 + y2) / 2;
        edges += '<path d="M' + x1 + ' ' + y1 + ' V' + my + ' H' + x2 + ' V' + y2 +
          '" fill="none" stroke="#3a4a63" stroke-width="1.5"/>';
        draw(c);
      });
      var s = palette[n.type] || palette.mg;
      var lines = wrapLabel(n.label, 23, 2);
      var lineH = 14;
      var cy = n.y + NODE_H / 2 - ((lines.length - 1) * lineH) / 2 + 4;
      var txt = lines.map(function (ln, li) {
        return '<text x="' + (n.x + NODE_W / 2) + '" y="' + (cy + li * lineH) +
          '" text-anchor="middle" font-family="Segoe UI, system-ui, sans-serif" font-size="12.5" ' +
          'font-weight="600" fill="' + s.text + '">' + esc(li === 0 ? s.icon + '  ' + ln : ln) + '</text>';
      }).join('');
      nodes += '<g>' +
        '<rect x="' + n.x + '" y="' + n.y + '" width="' + NODE_W + '" height="' + NODE_H +
          '" rx="10" fill="' + s.fill + '" stroke="' + s.stroke + '" stroke-width="1.5"/>' +
        txt +
        '<title>' + esc(n.label) + '</title>' +
      '</g>';
    })(treeRoot);

    wrap.innerHTML = '<svg id="mg-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + ' ' + H +
      '" width="' + W + '" height="' + H + '">' + edges + nodes + '</svg>';

    /* ── Zoom (scales rendered size; viewBox fixed) ── */
    var svgEl = document.getElementById('mg-svg');
    var scale = 1;
    function applyZoom() {
      svgEl.setAttribute('width', Math.round(W * scale));
      svgEl.setAttribute('height', Math.round(H * scale));
      var lbl = document.getElementById('mg-zoom-label');
      if (lbl) lbl.textContent = Math.round(scale * 100) + '%';
    }
    function bind(id, fn) { var b = document.getElementById(id); if (b) b.onclick = fn; }
    bind('mg-zoom-in',    function () { scale = Math.min(2.5, +(scale + 0.2).toFixed(2)); applyZoom(); });
    bind('mg-zoom-out',   function () { scale = Math.max(0.4, +(scale - 0.2).toFixed(2)); applyZoom(); });
    bind('mg-zoom-reset', function () { scale = 1; applyZoom(); });

    /* ── Export (PNG via canvas raster, or raw SVG) — fully offline ── */
    function dl(href, name) {
      var a = document.createElement('a');
      a.href = href; a.download = name;
      document.body.appendChild(a); a.click();
      setTimeout(function () { a.remove(); }, 120);
    }
    function exportTree(type) {
      var clone = svgEl.cloneNode(true);
      clone.setAttribute('width', W); clone.setAttribute('height', H);
      var xml = new XMLSerializer().serializeToString(clone);
      if (!/xmlns=/.test(xml)) xml = xml.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      if (type === 'svg') {
        dl('data:image/svg+xml;charset=utf-8,' + encodeURIComponent(xml), 'cloud-structure.svg');
        return;
      }
      var bg = (getComputedStyle(document.body).getPropertyValue('--surface') || '').trim() || '#0b1220';
      var img = new Image();
      img.onload = function () {
        var s = 2, c = document.createElement('canvas');
        c.width = W * s; c.height = H * s;
        var ctx = c.getContext('2d');
        ctx.fillStyle = bg; ctx.fillRect(0, 0, c.width, c.height);
        ctx.scale(s, s); ctx.drawImage(img, 0, 0);
        try { dl(c.toDataURL('image/png'), 'cloud-structure.png'); }
        catch (e) { alert('PNG export failed: ' + e.message); }
      };
      img.onerror = function () { alert('Could not render the diagram for export.'); };
      img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(xml)));
    }
    bind('mg-export-png', function () { exportTree('png'); });
    bind('mg-export-svg', function () { exportTree('svg'); });

    /* ── Drag-to-pan (grab / grabbing) for large diagrams ── */
    (function () {
      var down = false, sx, sy, sl, st;
      wrap.addEventListener('mousedown', function (e) {
        if (e.button !== 0) return;
        down = true; wrap.classList.add('panning');
        sx = e.clientX; sy = e.clientY; sl = wrap.scrollLeft; st = wrap.scrollTop;
        e.preventDefault();
      });
      window.addEventListener('mousemove', function (e) {
        if (!down) return;
        wrap.scrollLeft = sl - (e.clientX - sx);
        wrap.scrollTop  = st - (e.clientY - sy);
      });
      window.addEventListener('mouseup', function () {
        if (!down) return;
        down = false; wrap.classList.remove('panning');
      });
    })();

    setControls(true);
    applyZoom();
  })();

  /* ════════════════════════ SHARED CELL HELPERS ═════════════════════ */
  var subMap = inv.SubscriptionMap || {};
  function subName(id) {
    if (!id) return '—';
    return subMap[String(id).toLowerCase()] || id;
  }
  function statusPill(s) {
    if (!s) return '<span class="cell-muted">—</span>';
    var cls = '', low = s.toLowerCase();
    if (low === 'succeeded') cls = 'ok';
    else if (low === 'failed' || low === 'canceled') cls = 'bad';
    else if (low === 'updating' || low === 'creating' || low === 'deleting') cls = 'warn';
    return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + esc(s) + '</span>';
  }
  function portalLink(id) {
    if (!id) return '<span class="cell-muted">—</span>';
    var url = 'https://portal.azure.com/#@' + encodeURIComponent(tenant) + '/resource' + id + '/overview';
    return '<a class="portal-btn" href="' + url + '" target="_blank" rel="noopener">↗ Portal</a>';
  }
  function impactBadge(v) {
    if (!v) return '<span class="cell-muted">—</span>';
    var low = v.toLowerCase();
    var cls = low === 'high' ? 'high' : (low === 'medium' ? 'medium' : 'info');
    return '<span class="badge ' + cls + '">' + esc(v) + '</span>';
  }
  function monoCell(v) { return '<span class="cell-mono">' + esc(v || '—') + '</span>'; }
  function osPill(os) {
    var low = (os || '').toLowerCase();
    var color = low === 'windows' ? 'var(--accent2)' : (low === 'linux' ? 'var(--good)' : 'var(--muted)');
    return '<span class="status-pill"><span class="status-dot" style="background:' + color + '"></span>' + esc(os || 'Other') + '</span>';
  }
  function boolPill(v) {
    var on = String(v) === 'true';
    return '<span class="status-pill"><span class="status-dot ' + (on ? 'ok' : 'bad') + '"></span>' + (on ? 'true' : 'false') + '</span>';
  }
  function healthPill(s) {
    if (!s) return '<span class="cell-muted">—</span>';
    var low = String(s).toLowerCase(), cls = '';
    if (low.indexOf('online') !== -1 || low.indexOf('healthy') !== -1) cls = 'ok';
    else if (low.indexOf('degraded') !== -1) cls = 'warn';
    else if (low.indexOf('inactive') !== -1 || low.indexOf('stopped') !== -1 || low.indexOf('disabled') !== -1 || low.indexOf('unhealthy') !== -1) cls = 'bad';
    return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + esc(s) + '</span>';
  }
  function powerPill(s) {
    if (!s) return '<span class="cell-muted">—</span>';
    var low = String(s).toLowerCase(), cls = '';
    if (low === 'running') cls = 'ok';
    else if (low === 'stopped') cls = 'bad';
    else if (low === 'starting' || low === 'stopping' || low === 'deallocating') cls = 'warn';
    /* 'deallocated' and anything else use the neutral grey dot */
    return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + esc(s) + '</span>';
  }
  function vmssStatus(row) {
    var nodes = row.nodes || [];
    var known = nodes.filter(function (n) { return n.PowerState; });
    if (known.length) {
      var running = known.filter(function (n) { return String(n.PowerState).toLowerCase() === 'running'; }).length;
      var cls = running === nodes.length ? 'ok' : (running === 0 ? 'bad' : 'warn');
      return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + running + '/' + nodes.length + ' running</span>';
    }
    return statusPill(row.provisioningState);
  }
  function tagsHtml(tags) {
    if (!tags || typeof tags !== 'object') return '<span class="tags-empty">No tags</span>';
    var keys = Object.keys(tags);
    if (!keys.length) return '<span class="tags-empty">No tags</span>';
    return keys.map(function (k) {
      return '<span class="tag-pill"><span class="tag-key">' + esc(k) + '</span>' +
        '<span class="tag-val">' + esc(tags[k]) + '</span></span>';
    }).join('');
  }
  function idBlock(id) {
    return id
      ? '<div class="res-detail-id"><span style="flex:1">' + esc(id) + '</span>' +
        '<button class="copy-btn" data-copy="' + esc(id) + '">Copy</button></div>'
      : '<span class="cell-muted">—</span>';
  }
  /* key/value grid for contextual row details */
  function kvGrid(pairs) {
    var items = (pairs || []).filter(function (p) { return p && p.value != null && p.value !== '' && p.value !== '—'; });
    if (!items.length) return '';
    return '<div class="kv-grid">' + items.map(function (p) {
      return '<div class="kv"><span class="kv-k">' + esc(p.label) + '</span><span class="kv-v">' + esc(p.value) + '</span></div>';
    }).join('') + '</div>';
  }
  /* Rasterize an <svg> element to a PNG download — fully offline. W/H are the
     intrinsic (unscaled) diagram dimensions; the current SVG content is exported
     as-is, so any active filters are reflected. */
  function aerDownloadPng(svgEl, W, H, name) {
    if (!svgEl) return;
    var clone = svgEl.cloneNode(true);
    clone.setAttribute('width', W); clone.setAttribute('height', H);
    var xml = new XMLSerializer().serializeToString(clone);
    if (!/xmlns=/.test(xml)) xml = xml.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
    var bg = (getComputedStyle(document.body).getPropertyValue('--surface') || '').trim() || '#0b1220';
    var img = new Image();
    img.onload = function () {
      var s = 2, c = document.createElement('canvas');
      c.width = W * s; c.height = H * s;
      var ctx = c.getContext('2d');
      ctx.fillStyle = bg; ctx.fillRect(0, 0, c.width, c.height);
      ctx.scale(s, s); ctx.drawImage(img, 0, 0);
      try {
        var a = document.createElement('a');
        a.href = c.toDataURL('image/png'); a.download = name;
        document.body.appendChild(a); a.click();
        setTimeout(function () { a.remove(); }, 120);
      } catch (e) { alert('PNG export failed: ' + e.message); }
    };
    img.onerror = function () { alert('Could not render the diagram for export.'); };
    img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(xml)));
  }

  /* ════════════════════════ GENERIC DATA TABLE ══════════════════════ */
  function initDataTable(cfg) {
    var thead    = document.getElementById(cfg.ids.thead);
    var tbody    = document.getElementById(cfg.ids.tbody);
    var colgroup = document.getElementById(cfg.ids.colgroup);
    var pager    = document.getElementById(cfg.ids.pager);
    var tagsEl   = document.getElementById(cfg.ids.tags);
    var globalSearch = document.getElementById(cfg.ids.search);
    if (!thead || !tbody) return;

    var COLS = cfg.columns;
    var DATA = cfg.data;
    var PAGE_SIZE = cfg.pageSize || 15;
    var searchKeys = COLS.filter(function (c) { return !c.noFilter; }).map(function (c) { return c.key; });
    var clearAllId = cfg.ids.tags + '-clear-all';

    var filters = {}, gQuery = '', page = 0, currentSlice = [];

    // distinct values per filterable column
    var distinct = {};
    COLS.forEach(function (c) {
      if (c.noFilter) return;
      var counts = {};
      DATA.forEach(function (row) {
        var v = row[c.key] == null || row[c.key] === '' ? '—' : row[c.key];
        counts[v] = (counts[v] || 0) + 1;
      });
      distinct[c.key] = Object.keys(counts).sort().map(function (v) {
        return { value: v, count: counts[v] };
      });
    });

    colgroup.innerHTML = COLS.map(function (c) { return '<col data-col="' + c.key + '" style="width:' + c.width + 'px">'; }).join('');

    thead.innerHTML = '<tr>' + COLS.map(function (c) {
      var filterBtn = c.noFilter ? '' :
        '<button class="th-filter-btn" data-col="' + c.key + '" title="Filter">&#9662;</button>';
      return '<th data-col="' + c.key + '"><div class="th-inner">' +
        '<span class="th-label">' + esc(c.label) + '</span>' + filterBtn + '</div>' +
        '<span class="col-resizer" data-col="' + c.key + '"></span></th>';
    }).join('') + '</tr>';

    function passesFilters(row) {
      for (var key in filters) {
        if (filters[key] && filters[key].size > 0) {
          var v = row[key] == null || row[key] === '' ? '—' : row[key];
          if (!filters[key].has(v)) return false;
        }
      }
      if (gQuery) {
        var hay = searchKeys.map(function (k) { return row[k]; }).join(' ').toLowerCase();
        if (hay.indexOf(gQuery) === -1) return false;
      }
      return true;
    }

    function render() {
      var rows = DATA.filter(passesFilters);
      var totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
      if (page >= totalPages) page = totalPages - 1;
      if (page < 0) page = 0;
      currentSlice = rows.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

      if (!currentSlice.length) {
        tbody.innerHTML = '<tr><td colspan="' + COLS.length + '"><div class="empty-state">' +
          (cfg.emptyText || 'No items match the current filters.') + '</div></td></tr>';
      } else {
        tbody.innerHTML = currentSlice.map(function (row, idx) {
          return '<tr class="data-row" data-idx="' + idx + '">' + COLS.map(function (c, ci) {
            var inner = c.render ? c.render(row) : esc(row[c.key] == null || row[c.key] === '' ? '—' : row[c.key]);
            var chevron = (ci === 0 && cfg.detail) ? '<span class="row-chevron">&#9656;</span>' : '';
            var titleAttr = c.render ? '' : ' title="' + esc(row[c.key]) + '"';
            return '<td data-col="' + c.key + '"' + titleAttr + '>' + chevron + inner + '</td>';
          }).join('') + '</tr>';
        }).join('');
      }
      renderPager(pager, page, totalPages, rows.length, PAGE_SIZE, function (p) { page = p; render(); });
      renderTags();
      COLS.forEach(function (c) {
        if (c.noFilter) return;
        var b = thead.querySelector('.th-filter-btn[data-col="' + c.key + '"]');
        if (b) b.classList.toggle('has-filter', !!(filters[c.key] && filters[c.key].size > 0));
      });
    }

    function renderTags() {
      if (!tagsEl) return;
      var keys = Object.keys(filters).filter(function (k) { return filters[k] && filters[k].size > 0; });
      if (!keys.length) { tagsEl.innerHTML = ''; return; }
      var html = keys.map(function (k) {
        var col = COLS.filter(function (c) { return c.key === k; })[0];
        return '<span class="filter-tag">' + esc(col.label) + ': ' + filters[k].size +
          ' selected <span class="filter-tag-x" data-clear="' + k + '">&times;</span></span>';
      }).join('');
      html += '<button class="filter-clear-all" id="' + clearAllId + '">Clear all</button>';
      tagsEl.innerHTML = html;
      tagsEl.querySelectorAll('.filter-tag-x').forEach(function (x) {
        x.addEventListener('click', function () { delete filters[x.getAttribute('data-clear')]; page = 0; render(); });
      });
      var clearAll = document.getElementById(clearAllId);
      if (clearAll) clearAll.addEventListener('click', function () { filters = {}; page = 0; render(); });
    }

    /* accordion */
    if (cfg.detail) {
      tbody.addEventListener('click', function (e) {
        if (e.target.closest('.portal-btn')) return;
        if (e.target.closest('.copy-btn')) {
          var txt = e.target.getAttribute('data-copy');
          if (navigator.clipboard) navigator.clipboard.writeText(txt);
          var orig = e.target.textContent;
          e.target.textContent = 'Copied!';
          setTimeout(function () { e.target.textContent = orig; }, 1200);
          return;
        }
        var tr = e.target.closest('tr.data-row');
        if (!tr) return;
        var idx = parseInt(tr.getAttribute('data-idx'), 10);
        var next = tr.nextElementSibling;
        if (next && next.classList.contains('detail-row')) {
          next.parentNode.removeChild(next);
          tr.classList.remove('expanded');
        } else {
          tr.classList.add('expanded');
          var dr = document.createElement('tr');
          dr.className = 'detail-row';
          dr.innerHTML = '<td colspan="' + COLS.length + '">' + cfg.detail(currentSlice[idx]) + '</td>';
          tr.parentNode.insertBefore(dr, tr.nextSibling);
        }
      });
    }

    /* filter dropdown (multi-select + search) */
    var dropdown = el('div', 'filter-dropdown');
    document.body.appendChild(dropdown);
    var activeCol = null;

    function openDropdown(colKey, anchor) {
      activeCol = colKey;
      var values = distinct[colKey] || [];
      var selected = filters[colKey] || new Set();
      dropdown.innerHTML =
        '<div class="filter-dd-search"><input type="text" placeholder="Search values..." id="dd-search"/></div>' +
        '<div class="filter-dd-actions"><button class="filter-dd-action" id="dd-all">Select all</button>' +
        '<button class="filter-dd-action" id="dd-clear">Clear</button></div>' +
        '<div class="filter-dd-list" id="dd-list"></div>';
      var list = dropdown.querySelector('#dd-list');
      function paintList(q) {
        q = (q || '').toLowerCase();
        var shown = values.filter(function (v) { return String(v.value).toLowerCase().indexOf(q) !== -1; });
        if (!shown.length) { list.innerHTML = '<div class="filter-dd-empty">No matches</div>'; return; }
        list.innerHTML = shown.map(function (v) {
          return '<label class="filter-dd-item">' +
            '<input type="checkbox" value="' + esc(v.value) + '" ' + (selected.has(v.value) ? 'checked' : '') + '/>' +
            '<span class="filter-dd-item-label" title="' + esc(v.value) + '">' + esc(v.value) + '</span>' +
            '<span class="filter-dd-item-count">' + v.count + '</span></label>';
        }).join('');
        list.querySelectorAll('input[type=checkbox]').forEach(function (cb) {
          cb.addEventListener('change', function () {
            if (cb.checked) selected.add(cb.value); else selected.delete(cb.value);
            if (selected.size > 0) filters[colKey] = selected; else delete filters[colKey];
            page = 0; render();
          });
        });
      }
      paintList('');
      dropdown.querySelector('#dd-search').addEventListener('input', function (e) { paintList(e.target.value); });
      dropdown.querySelector('#dd-all').addEventListener('click', function () {
        values.forEach(function (v) { selected.add(v.value); });
        filters[colKey] = selected; page = 0; render();
        paintList(dropdown.querySelector('#dd-search').value);
      });
      dropdown.querySelector('#dd-clear').addEventListener('click', function () {
        selected.clear(); delete filters[colKey]; page = 0; render();
        paintList(dropdown.querySelector('#dd-search').value);
      });
      var r = anchor.getBoundingClientRect();
      dropdown.style.top = (r.bottom + window.scrollY + 4) + 'px';
      var left = r.left + window.scrollX;
      if (left + 240 > window.innerWidth) left = window.innerWidth - 250;
      dropdown.style.left = Math.max(8, left) + 'px';
      dropdown.classList.add('open');
      var srch = dropdown.querySelector('#dd-search');
      if (srch) srch.focus();
    }
    function closeDropdown() { dropdown.classList.remove('open'); activeCol = null; }

    thead.querySelectorAll('.th-filter-btn').forEach(function (b) {
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        var colKey = b.getAttribute('data-col');
        if (activeCol === colKey && dropdown.classList.contains('open')) { closeDropdown(); return; }
        openDropdown(colKey, b);
      });
    });
    document.addEventListener('click', function (e) {
      if (dropdown.classList.contains('open') && !dropdown.contains(e.target) &&
          !e.target.classList.contains('th-filter-btn')) closeDropdown();
    });

    /* column resize */
    var cols = colgroup.querySelectorAll('col');
    thead.querySelectorAll('.col-resizer').forEach(function (rz, idx) {
      rz.addEventListener('mousedown', function (e) {
        e.preventDefault(); e.stopPropagation();
        var startX = e.pageX, startW = cols[idx].offsetWidth;
        rz.classList.add('resizing');
        function onMove(ev) { cols[idx].style.width = Math.max(60, startW + (ev.pageX - startX)) + 'px'; }
        function onUp() {
          rz.classList.remove('resizing');
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
        }
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
      });
    });

    /* ── Column show/hide (generic for every initDataTable) ── */
    var tableEl  = thead.closest('table');
    var tableSel = tableEl && tableEl.id ? '#' + tableEl.id : '';
    var colStyle = document.createElement('style');
    document.head.appendChild(colStyle);
    var hiddenCols = new Set();
    (function () {
      var saved = lsGet('aer-cols-' + cfg.ids.tbody);
      if (saved) { try { JSON.parse(saved).forEach(function (k) { hiddenCols.add(k); }); } catch (e) {} }
      else { COLS.forEach(function (c) { if (c.hidden) hiddenCols.add(c.key); }); }  /* per-column default-hidden */
    })();
    function applyColVis() {
      colStyle.textContent = (tableSel ? Array.from(hiddenCols).map(function (k) {
        return tableSel + ' [data-col="' + k + '"]{display:none}';
      }).join('') : '');
    }
    applyColVis();
    var colsCard = thead.closest('.card');
    var colsToolbar = colsCard ? colsCard.querySelector('.table-toolbar') : null;
    if (colsToolbar) {
      var colsBtn = el('button', 'table-cols-btn', '&#8862; Columns');
      colsBtn.type = 'button';
      colsToolbar.appendChild(colsBtn);
      var colsDd = el('div', 'filter-dropdown');
      document.body.appendChild(colsDd);
      var paintCols = function () {
        colsDd.innerHTML =
          '<div class="filter-dd-actions"><button class="filter-dd-action" data-cols-act="all">Show all</button></div>' +
          '<div class="filter-dd-list">' + COLS.filter(function (c) { return c.label; }).map(function (c) {
            return '<label class="filter-dd-item">' +
              '<input type="checkbox" data-col="' + c.key + '" ' + (hiddenCols.has(c.key) ? '' : 'checked') + '/>' +
              '<span class="filter-dd-item-label">' + esc(c.label) + '</span></label>';
          }).join('') + '</div>';
        colsDd.querySelectorAll('input[data-col]').forEach(function (cb) {
          cb.addEventListener('change', function () {
            var k = cb.getAttribute('data-col');
            if (cb.checked) hiddenCols.delete(k); else hiddenCols.add(k);
            lsSet('aer-cols-' + cfg.ids.tbody, JSON.stringify(Array.from(hiddenCols)));
            applyColVis();
          });
        });
        var allBtn = colsDd.querySelector('[data-cols-act="all"]');
        if (allBtn) allBtn.addEventListener('click', function () {
          hiddenCols.clear(); lsSet('aer-cols-' + cfg.ids.tbody, '[]'); applyColVis(); paintCols();
        });
      };
      colsBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (colsDd.classList.contains('open')) { colsDd.classList.remove('open'); return; }
        paintCols();
        var r = colsBtn.getBoundingClientRect();
        colsDd.style.top = (r.bottom + window.scrollY + 4) + 'px';
        var left = r.right + window.scrollX - 240; if (left < 8) left = 8;
        colsDd.style.left = left + 'px';
        colsDd.classList.add('open');
      });
      document.addEventListener('click', function (e) {
        if (colsDd.classList.contains('open') && !colsDd.contains(e.target) && e.target !== colsBtn) colsDd.classList.remove('open');
      });
    }

    /* global search */
    if (globalSearch) {
      globalSearch.addEventListener('input', function (e) { gQuery = e.target.value.toLowerCase().trim(); page = 0; render(); });
    }

    render();
  }

  /* ── Inventory table ── */
  initDataTable({
    ids: { thead:'res-thead', tbody:'res-tbody', colgroup:'res-colgroup',
           pager:'res-pager', tags:'res-active-filters', search:'res-global-search' },
    pageSize: 15,
    emptyText: 'No resources match the current filters.',
    data: toArr(inv.ResourceList).map(function (r) {
      return {
        subscription:  subName(r.subscriptionId),
        resourceGroup: r.resourceGroup || '—',
        name:          r.name || '—',
        type:          r.type || '—',
        location:      r.location || '—',
        status:        r.provisioningState || '',
        id:            r.id || '',
        tags:          r.tags || null
      };
    }),
    columns: [
      { key:'subscription',  label:'Subscription',   width:160 },
      { key:'resourceGroup', label:'Resource Group', width:150 },
      { key:'name',          label:'Resource',       width:170 },
      { key:'type',          label:'Resource Type',  width:210, render:function (r) { return monoCell(r.type); } },
      { key:'location',      label:'Region',         width:100 },
      { key:'status',        label:'Status',         width:120, render:function (r) { return statusPill(r.status); } },
      { key:'_actions',      label:'',               width:120, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div>' +
        '<div class="res-tags">' + tagsHtml(row.tags) + '</div></div></div>';
    }
  });

  /* ── Advisor recommendations table ── */
  initDataTable({
    ids: { thead:'adv-thead', tbody:'adv-tbody', colgroup:'adv-colgroup',
           pager:'adv-pager', tags:'adv-active-filters', search:'adv-global-search' },
    pageSize: 15,
    emptyText: 'No recommendations match the current filters.',
    data: toArr(adv.Recommendations).map(function (r) {
      return {
        category:     r.Category || '—',
        impact:       r.Impact || '—',
        problem:      r.Problem || '—',
        resource:     r.Resource || '—',
        resourceType: r.ResourceType || '—',
        subscription: subName(r.SubscriptionId),
        resourceId:   r.ResourceId || '',
        solution:     r.Solution || ''
      };
    }),
    columns: [
      { key:'category',     label:'Category',       width:130 },
      { key:'impact',       label:'Impact',         width:100, render:function (r) { return impactBadge(r.impact); } },
      { key:'problem',      label:'Recommendation', width:280 },
      { key:'resource',     label:'Resource',       width:160 },
      { key:'resourceType', label:'Resource Type',  width:200, render:function (r) { return monoCell(r.resourceType); } },
      { key:'subscription', label:'Subscription',   width:160 },
      { key:'_actions',     label:'',               width:120, noFilter:true, render:function (r) { return portalLink(r.resourceId); } }
    ],
    detail: function (row) {
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Problem</div>' +
          '<div class="res-detail-text">' + esc(row.problem || '—') + '</div></div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Recommended action</div>' +
          '<div class="res-detail-text">' + esc(row.solution || '—') + '</div></div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.resourceId) + '</div></div>';
    }
  });

  /* ── Virtual machines table ── */
  initDataTable({
    ids: { thead:'vm-thead', tbody:'vm-tbody', colgroup:'vm-colgroup',
           pager:'vm-pager', tags:'vm-active-filters', search:'vm-global-search' },
    pageSize: 15,
    emptyText: 'No virtual machines match the current filters.',
    data: toArr(vm.VirtualMachines).map(function (r) {
      return {
        name:         r.Name || '—',
        subscription: r.SubscriptionName || '—',
        rg:           r.ResourceGroup || '—',
        os:           r.Os || 'Other',
        region:       r.Location || '—',
        status:       r.Status || '',
        sku:          r.Sku || '—',
        image:        r.Image || '—',
        ip:           r.PrivateIp || '—',
        publicIp:     r.PublicIp || '—',
        vnet:         r.Vnet || '',
        subnet:       r.Subnet || '',
        boot:         r.BootDiagnostics ? 'true' : 'false',
        created:      r.TimeCreated ? String(r.TimeCreated).slice(0, 10) : '—',
        id:           r.Id || '',
        tags:         r.Tags || null,
        vcores:       r.VCores || 0,
        memory:       r.MemoryGB || 0,
        disk:         r.DiskGB || 0
      };
    }),
    columns: [
      { key:'name',         label:'Name',             width:170 },
      { key:'subscription', label:'Subscription',     width:150 },
      { key:'rg',           label:'Resource Group',   width:150 },
      { key:'os',           label:'OS',               width:90,  render:function (r) { return osPill(r.os); } },
      { key:'region',       label:'Region',           width:110 },
      { key:'status',       label:'Status',           width:120, render:function (r) { return powerPill(r.status); } },
      { key:'sku',          label:'SKU',              width:150, render:function (r) { return monoCell(r.sku); } },
      { key:'image',        label:'Image',            width:210, hidden:true, render:function (r) { return monoCell(r.image); } },
      { key:'ip',           label:'IP Address',       width:120, hidden:true, render:function (r) { return monoCell(r.ip); } },
      { key:'publicIp',     label:'Public IP',        width:120, hidden:true, render:function (r) { return r.publicIp && r.publicIp !== '—' ? monoCell(r.publicIp) : '<span class="cell-muted">—</span>'; } },
      { key:'boot',         label:'Boot Diagnostics', width:130, hidden:true, render:function (r) { return boolPill(r.boot); } },
      { key:'created',      label:'Created',          width:110 },
      { key:'_actions',     label:'',                 width:110, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var net = kvGrid([
        { label:'Virtual network', value: row.vnet },
        { label:'Subnet',          value: row.subnet },
        { label:'Private IP',      value: (row.ip && row.ip !== '—') ? row.ip : '' },
        { label:'Public IP',       value: (row.publicIp && row.publicIp !== '—') ? row.publicIp : '' }
      ]) || '<span class="cell-muted">No network association found.</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Size</div><div class="pill-row">' +
          '<span class="pill pill-blue">⚙ ' + fmt(row.vcores) + ' vCores</span>' +
          '<span class="pill pill-cyan">▤ ' + fmt(row.memory) + ' GB RAM</span>' +
          '<span class="pill pill-purple">▦ ' + fmt(row.disk) + ' GB disk</span>' +
        '</div></div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Network</div>' + net + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div>' +
          '<div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* ════════════════════════ VM SCALE SETS ═══════════════════════════ */
  setHeader('vmss-header', '🧩', 'Virtual Machine Scale Sets',
    'Scale set inventory across all scanned subscriptions',
    '<span class="chip blue">' + fmt(vmss.TotalVMSS || 0) + ' scale sets</span>');

  var vmssTiles = document.getElementById('vmss-tiles');
  if (vmssTiles) {
    [
      { icon: '🧩', label: 'Total VMSS',      value: fmt(vmss.TotalVMSS || 0) },
      { icon: '🐧', label: 'Linux',           value: fmt(vmss.LinuxVMSS || 0) },
      { icon: '🪟', label: 'Windows',         value: fmt(vmss.WindowsVMSS || 0) },
      { icon: '🔁', label: 'Uniform',         value: fmt(vmss.UniformVMSS || 0) },
      { icon: '🔀', label: 'Flexible',        value: fmt(vmss.FlexibleVMSS || 0) },
      { icon: '🖥️', label: 'Total Instances', value: fmt(vmss.TotalInstances || 0) }
    ].forEach(function (t) {
      vmssTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + (t.unit ? '<span class="stat-tile-unit">' + t.unit + '</span>' : '') + '</div>'));
    });
  }

  /* ── Virtual machine scale sets table ── */
  initDataTable({
    ids: { thead:'vmss-thead', tbody:'vmss-tbody', colgroup:'vmss-colgroup',
           pager:'vmss-pager', tags:'vmss-active-filters', search:'vmss-global-search' },
    pageSize: 15,
    emptyText: 'No scale sets match the current filters.',
    data: toArr(vmss.ScaleSets).map(function (r) {
      return {
        name:          r.Name || '—',
        subscription:  r.SubscriptionName || '—',
        rg:            r.ResourceGroup || '—',
        os:            r.Os || 'Other',
        region:        r.Location || '—',
        sku:           r.Sku || '—',
        orchestration: r.OrchestrationMode || '—',
        capacity:      (r.Capacity != null ? r.Capacity : 0),
        image:         r.Image || '—',
        vnet:          r.Vnet || '',
        subnet:        r.Subnet || '',
        created:       r.TimeCreated ? String(r.TimeCreated).slice(0, 10) : '—',
        id:            r.Id || '',
        tags:          r.Tags || null,
        nodes:         toArr(r.Nodes),
        provisioningState: r.ProvisioningState || '—'
      };
    }),
    columns: [
      { key:'name',          label:'Name',           width:170 },
      { key:'subscription',  label:'Subscription',   width:140 },
      { key:'rg',            label:'Resource Group', width:140 },
      { key:'os',            label:'OS',             width:85,  render:function (r) { return osPill(r.os); } },
      { key:'region',        label:'Region',         width:100 },
      { key:'sku',           label:'VM Size',        width:140, render:function (r) { return monoCell(r.sku); } },
      { key:'orchestration', label:'Orchestration',  width:115 },
      { key:'capacity',      label:'Instances',      width:90 },
      { key:'status',        label:'Status',         width:130, noFilter:true, render:function (r) { return vmssStatus(r); } },
      { key:'image',         label:'Image',          width:200, hidden:true, render:function (r) { return monoCell(r.image); } },
      { key:'created',       label:'Created',        width:110, hidden:true },
      { key:'_actions',      label:'',               width:100, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var nodes = row.nodes || [];
      var nodesHtml = nodes.length
        ? '<div class="table-scroll"><table class="aer-table simple node-table">' +
            '<thead><tr><th>Instance</th><th>Computer name</th><th>Size</th><th>Power state</th></tr></thead><tbody>' +
            nodes.map(function (n) {
              return '<tr><td>' + esc(n.Name || '—') + '</td><td>' + esc(n.ComputerName || '—') + '</td><td>' +
                monoCell(n.Size) + '</td><td>' + powerPill(n.PowerState) + '</td></tr>';
            }).join('') + '</tbody></table></div>'
        : '<span class="tags-empty">No instance data available</span>';
      var net = kvGrid([
        { label:'Virtual network', value: row.vnet },
        { label:'Subnet',          value: row.subnet }
      ]) || '<span class="cell-muted">No network association found.</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Network</div>' + net + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Instances (' + nodes.length + ')</div>' + nodesHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div>' +
          '<div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* ════════════════════════════ DATABASES ═══════════════════════════ */
  setHeader('db-header', '🛢️', 'Database Services',
    'Managed database, cache and analytics services across all scanned subscriptions',
    '<span class="chip blue">' + fmt(db.TotalServices || 0) + ' services</span>' +
    '<span class="chip good">' + fmt(db.DistinctTypes || 0) + ' service types</span>');

  var dbTiles = document.getElementById('db-tiles');
  if (dbTiles) {
    [
      { icon: '🛢️', label: 'Total Services', value: fmt(db.TotalServices || 0) },
      { icon: '🗄️', label: 'Relational',     value: fmt(db.Relational || 0) },
      { icon: '🌐', label: 'NoSQL',          value: fmt(db.NoSQL || 0) },
      { icon: '⚡', label: 'Cache',          value: fmt(db.Cache || 0) },
      { icon: '📈', label: 'Analytics',      value: fmt(db.Analytics || 0) },
      { icon: '🧱', label: 'Table Storage',  value: fmt(db.TableStorage || 0) }
    ].forEach(function (t) {
      dbTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>'));
    });
  }

  var dbCatColors = { Relational: '#0ea5e9', NoSQL: '#a78bfa', Cache: '#f59e0b', Analytics: '#22d3ee' };
  renderDonut('db-chart-category', toArr(db.ByCategory).map(function (c) {
    return { name: c.Category, count: c.Count || 0, color: dbCatColors[c.Category] };
  }));
  renderBars('db-chart-type',   toArr(db.ByType),         'Label',  'Count');
  renderBars('db-chart-region', toArr(db.ByLocation),     'Region', 'Count');
  renderBars('db-chart-cosmos', toArr(db.CosmosFamilies), 'Api',    'Count');
  renderBars('db-chart-redis',  toArr(db.RedisFamilies),  'Tier',   'Count');

  /* ════════════════════════ RELATIONAL DATABASES ════════════════════ */
  setHeader('rel-header', '🗄️', 'Relational Databases',
    'Relational database services across all scanned subscriptions',
    '<span class="chip blue">' + fmt(rel.TotalRelational || 0) + ' resources</span>');

  var relCounts = rel.Counts || {};
  var relTiles = document.getElementById('rel-tiles');
  if (relTiles) {
    [
      { icon: '🗃️', label: 'SQL Database',          value: fmt(relCounts.SqlDatabase || 0) },
      { icon: '🛡️', label: 'SQL Managed Instance',  value: fmt(relCounts.SqlManagedInstance || 0) },
      { icon: '🖥️', label: 'SQL on VM',             value: fmt(relCounts.SqlOnVm || 0) },
      { icon: '🐘', label: 'PostgreSQL Flexible',   value: fmt(relCounts.PostgresFlexible || 0) },
      { icon: '🐬', label: 'MySQL Flexible',        value: fmt(relCounts.MysqlFlexible || 0) },
      { icon: '🌌', label: 'Cosmos for PostgreSQL', value: fmt(relCounts.CosmosPostgres || 0) }
    ].forEach(function (t) {
      relTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>'));
    });
  }

  initDataTable({
    ids: { thead:'rel-thead', tbody:'rel-tbody', colgroup:'rel-colgroup',
           pager:'rel-pager', tags:'rel-active-filters', search:'rel-global-search' },
    pageSize: 15,
    emptyText: 'No relational resources match the current filters.',
    data: toArr(rel.Services).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—',
        rg:           r.ResourceGroup || '—',
        name:         r.Name || '—',
        type:         r.Type || '—',
        id:           r.Id || '',
        status:       r.Status || '',
        pricingTier:  r.PricingTier || '',
        maxStorageGB: r.MaxStorageGB || 0,
        storageGB:    r.StorageGB || 0,
        adminLogin:   r.AdminLogin || '',
        version:      r.Version || '',
        elasticPool:  r.ElasticPool || '',
        server:       r.Server || '',
        vcores:       r.VCores || 0,
        databaseCount: (r.DatabaseCount != null ? r.DatabaseCount : null),
        databases:    toArr(r.Databases),
        haMode:       r.HaMode || '',
        backupRetentionDays: (r.BackupRetentionDays != null ? r.BackupRetentionDays : null),
        nodeCount:    (r.NodeCount != null ? r.NodeCount : null),
        image:        r.Image || '',
        os:           r.Os || '',
        vmSize:       r.VmSize || '',
        sqlEdition:   r.SqlEdition || '',
        licenseType:  r.LicenseType || '',
        managementMode: r.ManagementMode || '',
        vnetIntegration: r.VnetIntegration || '',
        tags:         r.Tags || null
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:200 },
      { key:'rg',           label:'Resource Group', width:180 },
      { key:'name',         label:'Resource',       width:210 },
      { key:'type',         label:'Type',           width:210 },
      { key:'_actions',     label:'',               width:110, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var t = row.type || '', pairs;
      if (t.indexOf('Managed Instance') !== -1) {
        pairs = [
          { label: 'Status',       value: row.status },
          { label: 'Pricing tier', value: row.pricingTier },
          { label: 'vCores',       value: row.vcores ? fmt(row.vcores) : '' },
          { label: 'Databases',    value: (row.databaseCount != null ? fmt(row.databaseCount) : '') },
          { label: 'Max storage',  value: row.maxStorageGB ? fmt(row.maxStorageGB) + ' GB' : '' },
          { label: 'MI admin',     value: row.adminLogin }
        ];
      } else if (t.indexOf('on Azure VM') !== -1) {
        pairs = [
          { label: 'Status (power)', value: row.status },
          { label: 'OS',             value: row.os },
          { label: 'VM size',        value: row.vmSize },
          { label: 'SQL edition',    value: row.sqlEdition },
          { label: 'License',        value: row.licenseType },
          { label: 'Management',     value: row.managementMode },
          { label: 'Image',          value: row.image }
        ];
      } else if (t.indexOf('SQL Database') !== -1) {
        pairs = [
          { label: 'Status',       value: row.status },
          { label: 'Pricing tier', value: row.pricingTier },
          { label: 'Elastic pool', value: row.elasticPool },
          { label: 'Server',       value: row.server },
          { label: 'Max storage',  value: row.maxStorageGB ? fmt(row.maxStorageGB) + ' GB' : '' }
        ];
      } else if (t.indexOf('PostgreSQL Flexible') !== -1) {
        pairs = [
          { label: 'Status',            value: row.status },
          { label: 'Version',           value: row.version },
          { label: 'Pricing tier',      value: row.pricingTier },
          { label: 'Storage',           value: row.storageGB ? fmt(row.storageGB) + ' GB' : '' },
          { label: 'Admin',             value: row.adminLogin },
          { label: 'High availability', value: row.haMode },
          { label: 'Backup retention',  value: (row.backupRetentionDays != null ? row.backupRetentionDays + ' days' : '') }
        ];
      } else if (t.indexOf('MySQL Flexible') !== -1) {
        pairs = [
          { label: 'Status',       value: row.status },
          { label: 'Version',      value: row.version },
          { label: 'Pricing tier', value: row.pricingTier },
          { label: 'Storage',      value: row.storageGB ? fmt(row.storageGB) + ' GB' : '' },
          { label: 'Admin',        value: row.adminLogin }
        ];
      } else {  /* Cosmos DB for PostgreSQL */
        pairs = [
          { label: 'Status',  value: row.status },
          { label: 'Version', value: row.version },
          { label: 'Nodes',   value: (row.nodeCount != null ? fmt(row.nodeCount) : '') }
        ];
      }
      if (row.vnetIntegration) pairs.push({ label: 'VNet integration', value: row.vnetIntegration });
      var html = '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Details</div>' +
          (kvGrid(pairs) || '<span class="tags-empty">No details available</span>') + '</div>';
      if (t.indexOf('Managed Instance') !== -1) {
        var dbs = toArr(row.databases);
        var body = dbs.length
          ? '<div class="pill-row">' + dbs.map(function (dn) { return '<span class="pill pill-blue">🗄 ' + esc(dn) + '</span>'; }).join('') + '</div>'
          : '<span class="tags-empty">No databases</span>';
        html += '<div class="res-detail-section"><div class="res-detail-label">Databases (' + dbs.length + ')</div>' + body + '</div>';
      }
      html += '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
      return html;
    }
  });

  /* ════════════════ NoSQL / CACHE / ANALYTICS / TABLE STORAGE ════════ */
  var ds = d.dataServices || {};
  function renderServicePage(cfg) {
    var data = cfg.data || {};
    setHeader(cfg.prefix + '-header', cfg.icon, cfg.title, cfg.subtitle,
      '<span class="chip blue">' + fmt(data.Total || 0) + ' resources</span>');
    var tilesEl = document.getElementById(cfg.prefix + '-tiles');
    if (tilesEl) {
      (cfg.tiles || []).forEach(function (t) {
        tilesEl.appendChild(el('div', 'stat-tile',
          '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
          '<div class="stat-tile-value">' + fmt(t.value || 0) + '</div>'));
      });
    }
    initDataTable({
      ids: { thead: cfg.prefix + '-thead', tbody: cfg.prefix + '-tbody', colgroup: cfg.prefix + '-colgroup',
             pager: cfg.prefix + '-pager', tags: cfg.prefix + '-active-filters', search: cfg.prefix + '-global-search' },
      pageSize: 15,
      emptyText: 'No resources match the current filters.',
      data: toArr(data.Services).map(function (r) {
        return {
          subscription: r.SubscriptionName || '—',
          rg:           r.ResourceGroup || '—',
          name:         r.Name || '—',
          type:         r.Type || '—',
          id:           r.Id || '',
          details:      toArr(r.Details),
          tags:         r.Tags || null
        };
      }),
      columns: [
        { key:'subscription', label:'Subscription',   width:200 },
        { key:'rg',           label:'Resource Group', width:180 },
        { key:'name',         label:'Resource',       width:210 },
        { key:'type',         label:'Type',           width:210 },
        { key:'_actions',     label:'',               width:110, noFilter:true, render:function (r) { return portalLink(r.id); } }
      ],
      detail: function (row) {
        return '<div class="res-detail">' +
          '<div class="res-detail-section"><div class="res-detail-label">Details</div>' +
            (kvGrid(toArr(row.details)) || '<span class="tags-empty">No details available</span>') + '</div>' +
          '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
          '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
        '</div>';
      }
    });
  }

  var nosqlC = (ds.NoSQL || {}).Counts || {};
  renderServicePage({ prefix: 'nosql', icon: '🌐', title: 'NoSQL Databases',
    subtitle: 'NoSQL database services across all scanned subscriptions', data: ds.NoSQL,
    tiles: [
      { icon: '🪐', label: 'Cosmos DB',   value: nosqlC.CosmosDb || 0 },
      { icon: '🌐', label: 'Total NoSQL', value: (ds.NoSQL || {}).Total || 0 }
    ] });

  var cacheC = (ds.Cache || {}).Counts || {};
  renderServicePage({ prefix: 'cache', icon: '⚡', title: 'Cache',
    subtitle: 'In-memory cache services across all scanned subscriptions', data: ds.Cache,
    tiles: [
      { icon: '⚡', label: 'Cache for Redis',            value: cacheC.Redis || 0 },
      { icon: '🚀', label: 'Managed Redis (Enterprise)', value: cacheC.RedisEnterprise || 0 },
      { icon: '⚡', label: 'Total Cache',                value: (ds.Cache || {}).Total || 0 }
    ] });

  var anC = (ds.Analytics || {}).Counts || {};
  renderServicePage({ prefix: 'analytics', icon: '📈', title: 'Analytics',
    subtitle: 'Analytics and big-data services across all scanned subscriptions', data: ds.Analytics,
    tiles: [
      { icon: '🛰️', label: 'Synapse',           value: anC.Synapse || 0 },
      { icon: '🔬', label: 'Data Explorer',     value: anC.DataExplorer || 0 },
      { icon: '🧮', label: 'Databricks',        value: anC.Databricks || 0 },
      { icon: '📊', label: 'Analysis Services', value: anC.AnalysisServices || 0 },
      { icon: '🐘', label: 'HDInsight',         value: anC.HDInsight || 0 },
      { icon: '📈', label: 'Total Analytics',   value: (ds.Analytics || {}).Total || 0 }
    ] });

  renderServicePage({ prefix: 'table', icon: '🧱', title: 'Table Storage',
    subtitle: 'Table-capable storage accounts across all scanned subscriptions', data: ds.TableStorage,
    tiles: [
      { icon: '🧱', label: 'Table Storage accounts', value: (ds.TableStorage || {}).Total || 0 }
    ] });

  /* ════════════════════════════ APPLICATIONS ════════════════════════ */
  var app = d.applications || {};
  setHeader('app-header', '🚀', 'Application Services',
    'Application, container and integration services across all scanned subscriptions',
    '<span class="chip blue">' + fmt(app.TotalServices || 0) + ' services</span>' +
    '<span class="chip good">' + fmt(app.DistinctTypes || 0) + ' service types</span>');

  var appTiles = document.getElementById('app-tiles');
  if (appTiles) {
    [
      { icon: '🚀', label: 'Total Services',    value: fmt(app.TotalServices || 0) },
      { icon: '🌐', label: 'Web / App Service', value: fmt(app.Web || 0) },
      { icon: '⚙️', label: 'Functions & Logic', value: fmt(app.Functions || 0) },
      { icon: '📦', label: 'Containers',        value: fmt(app.Containers || 0) },
      { icon: '🔌', label: 'API & Integration', value: fmt(app.Integration || 0) },
      { icon: '☸',  label: 'AKS clusters',      value: fmt(app.Aks || 0) }
    ].forEach(function (t) {
      appTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>'));
    });
  }

  var appCatColors = { 'Web / App Service': '#0ea5e9', 'Functions & Logic': '#a78bfa', 'Containers': '#22d3ee', 'API & Integration': '#f59e0b' };
  renderDonut('app-chart-category', toArr(app.ByCategory).map(function (c) {
    return { name: c.Category, count: c.Count || 0, color: appCatColors[c.Category] };
  }));
  renderBars('app-chart-type',   toArr(app.ByType),       'Label',   'Count');
  renderBars('app-chart-region', toArr(app.ByLocation),   'Region',  'Count');
  renderBars('app-chart-aks',    toArr(app.AksByVersion), 'Version', 'Count');
  renderBars('app-chart-plans',  toArr(app.PlansByTier),  'Tier',    'Count');

  /* ════════════════ APPLICATION SERVICES — per-category pages ════════ */
  var apps = d.applicationServices || {};
  var wC = (apps.Web || {}).Counts || {};
  renderServicePage({ prefix: 'webapps', icon: '🌐', title: 'Web / App Services',
    subtitle: 'Web apps, plans and hosting across all scanned subscriptions', data: apps.Web,
    tiles: [
      { icon: '🌐', label: 'Web App',                value: wC.WebApp || 0 },
      { icon: '🐳', label: 'Web App for Containers',  value: wC.WebAppContainers || 0 },
      { icon: '📋', label: 'App Service Plan',        value: wC.AppServicePlan || 0 },
      { icon: '🏛️', label: 'App Service Env',         value: wC.Ase || 0 },
      { icon: '📄', label: 'Static Web App',          value: wC.StaticWebApp || 0 },
      { icon: '🌐', label: 'Total',                   value: (apps.Web || {}).Total || 0 }
    ] });

  var fC = (apps.Functions || {}).Counts || {};
  renderServicePage({ prefix: 'functions', icon: '⚙️', title: 'Functions & Logic Apps',
    subtitle: 'Function apps and logic apps across all scanned subscriptions', data: apps.Functions,
    tiles: [
      { icon: '⚡', label: 'Function App',            value: fC.FunctionApp || 0 },
      { icon: '🔁', label: 'Logic App (Standard)',    value: fC.LogicStandard || 0 },
      { icon: '🔂', label: 'Logic App (Consumption)', value: fC.LogicConsumption || 0 },
      { icon: '⚙️', label: 'Total',                   value: (apps.Functions || {}).Total || 0 }
    ] });

  var cC = (apps.Containers || {}).Counts || {};
  renderServicePage({ prefix: 'containers', icon: '📦', title: 'Containers',
    subtitle: 'Container services (excluding AKS) across all scanned subscriptions', data: apps.Containers,
    tiles: [
      { icon: '📦', label: 'Container Apps',        value: cC.ContainerApps || 0 },
      { icon: '🌐', label: 'Container Apps Env',    value: cC.ContainerAppsEnv || 0 },
      { icon: '📥', label: 'Container Instances',   value: cC.ContainerInstances || 0 },
      { icon: '🗃️', label: 'Container Registry',    value: cC.ContainerRegistry || 0 },
      { icon: '🧬', label: 'Service Fabric',        value: cC.ServiceFabric || 0 },
      { icon: '📦', label: 'Total',                 value: (apps.Containers || {}).Total || 0 }
    ] });

  var iC = (apps.Integration || {}).Counts || {};
  renderServicePage({ prefix: 'integration', icon: '🔌', title: 'API & Integration',
    subtitle: 'API and integration services across all scanned subscriptions', data: apps.Integration,
    tiles: [
      { icon: '🔌', label: 'API Management', value: iC.ApiManagement || 0 },
      { icon: '🔌', label: 'Total',          value: (apps.Integration || {}).Total || 0 }
    ] });

  renderServicePage({ prefix: 'aks', icon: '☸', title: 'AKS Clusters',
    subtitle: 'Azure Kubernetes Service clusters across all scanned subscriptions', data: apps.Aks,
    tiles: [
      { icon: '☸', label: 'AKS clusters', value: (apps.Aks || {}).Total || 0 }
    ] });

  /* ════════ NETWORK / OBSERVABILITY / GOVERNANCE / SECURITY overviews ═ */
  function renderOverviewPage(cfg) {
    var data = cfg.data || {};
    var cats = toArr(data.Categories);
    setHeader(cfg.prefix + '-header', cfg.icon, cfg.title, cfg.subtitle,
      '<span class="chip blue">' + fmt(data.Total || 0) + ' resources</span>' +
      '<span class="chip good">' + fmt(data.DistinctTypes || 0) + ' types</span>');
    var tilesEl = document.getElementById(cfg.prefix + '-tiles');
    if (tilesEl) {
      tilesEl.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + cfg.icon + ' Total</div><div class="stat-tile-value">' + fmt(data.Total || 0) + '</div>'));
      cats.forEach(function (c) {
        var ic = (cfg.icons && cfg.icons[c.Category]) || '•';
        tilesEl.appendChild(el('div', 'stat-tile',
          '<div class="stat-tile-label">' + ic + ' ' + esc(c.Category) + '</div><div class="stat-tile-value">' + fmt(c.Count || 0) + '</div>'));
      });
    }
    renderDonut(cfg.prefix + '-chart-category', cats.map(function (c) {
      return { name: c.Category, count: c.Count || 0, color: (cfg.colors && cfg.colors[c.Category]) };
    }));
    renderBars(cfg.prefix + '-chart-type',   toArr(data.ByType),     'Label',  'Count');
    renderBars(cfg.prefix + '-chart-region', toArr(data.ByLocation), 'Region', 'Count');
  }

  /* Network — custom overview (counts + IP usage + DNS + balancers) */
  var net = d.network || {};
  var nc = net.Counts || {};
  setHeader('network-header', '🔗', 'Network',
    'Networking resources across all scanned subscriptions',
    '<span class="chip blue">' + fmt(nc.Vnet || 0) + ' VNets</span>' +
    '<span class="chip good">' + fmt(nc.Subnets || 0) + ' subnets</span>');
  var netTilesEl = document.getElementById('network-tiles');
  if (netTilesEl) {
    [
      { icon: '🔷', label: 'VNets',               value: nc.Vnet },
      { icon: '🧩', label: 'Subnets',             value: nc.Subnets },
      { icon: '🔀', label: 'Peerings',            value: nc.Peerings },
      { icon: '🚪', label: 'Gateways',            value: nc.Gateways },
      { icon: '🛤️', label: 'ExpressRoute',        value: nc.ExpressRoute },
      { icon: '🔌', label: 'Private Endpoints',   value: nc.PrivateEndpoints },
      { icon: '🚦', label: 'Application Gateway',  value: nc.AppGateway },
      { icon: '🚪', label: 'Front Door',          value: nc.FrontDoor },
      { icon: '🗺️', label: 'Traffic Manager',     value: nc.TrafficManager },
      { icon: '⚖️', label: 'Load Balancer',       value: nc.LoadBalancer },
      { icon: '🛡️', label: 'Azure Firewall',      value: nc.AzureFirewall },
      { icon: '🔒', label: 'NSG',                 value: nc.Nsg },
      { icon: '🌐', label: 'Public IP',           value: nc.PublicIp },
      { icon: '🧭', label: 'Route Tables',        value: nc.RouteTables },
      { icon: '🛡️', label: 'DDoS Protection',     value: nc.DdosPlans }
    ].forEach(function (t) {
      netTilesEl.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + fmt(t.value || 0) + '</div>'));
    });
  }
  var ipu = net.IpUsage || {};
  renderDonut('network-chart-ip', [
    { name: 'Occupied (used + reserved)', count: ipu.Occupied || 0, color: '#f59e0b' },
    { name: 'Free', count: ipu.Free || 0, color: '#22c55e' }
  ], null, (ipu.PercentUsed != null ? ipu.PercentUsed : 0) + '%');
  var ndns = net.Dns || {};
  renderDonut('network-chart-dns', [
    { name: 'Public zones',  count: ndns.Public || 0,  color: '#0ea5e9' },
    { name: 'Private zones', count: ndns.Private || 0, color: '#a78bfa' }
  ]);
  renderBars('network-chart-balancers', toArr(net.Balancers), 'Type', 'Count');

  /* Observability — monitoring coverage dashboard (coverage sourced from d.diagnosticSettings) */
  var obs = d.observability || {};
  var oCounts = obs.Counts || {};
  var diag = d.diagnosticSettings || {};
  var dc = diag.Summary || {}, amaC = obs.AmaCoverage || {}, aiC = obs.AppInsightsCoverage || {};
  function pctTxt(v) { return (v === null || v === undefined) ? '—' : v + '%'; }
  setHeader('obs-header', '📈', 'Observability',
    'Monitoring, logging and alerting coverage across all scanned subscriptions',
    '<span class="chip blue">' + fmt(obs.Total || 0) + ' resources</span>');

  var obsKpis = document.getElementById('obs-kpis');
  if (obsKpis) {
    [
      { icon: '🛡️', label: 'Diag Settings Coverage', value: pctTxt(dc.Percent), sub: fmt(dc.Enabled || 0) + ' / ' + fmt(dc.Evaluated || 0) + ' resources' },
      { icon: '📦', label: 'Subscriptions Evaluated', value: fmt(obs.SubscriptionsEvaluated || 0), sub: 'in this report' },
      { icon: '📊', label: 'Log Analytics Workspaces', value: fmt(obs.Workspaces || 0), sub: 'log destinations' },
      { icon: '🖥️', label: 'VM / Arc with AMA', value: pctTxt(amaC.Percent), sub: fmt(amaC.WithAma || 0) + ' / ' + fmt(amaC.Machines || 0) + ' machines' },
      { icon: '🔭', label: 'App Insights Coverage', value: pctTxt(aiC.Percent), sub: fmt(aiC.Covered || 0) + ' / ' + fmt(aiC.Apps || 0) + ' apps' }
    ].forEach(function (t) {
      obsKpis.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }

  /* Coverage by subscription — custom % bars with threshold colors */
  (function () {
    var wrap = document.getElementById('obs-chart-cov-sub');
    if (!wrap) return;
    var rows = toArr(diag.CoverageBySubscription).slice(0, 8);
    if (!rows.length) { wrap.innerHTML = '<div class="empty-state">No diagnosable resources found.</div>'; return; }
    wrap.innerHTML = rows.map(function (r) {
      var p = (r.Percent === null || r.Percent === undefined) ? 0 : r.Percent;
      var color = p >= 80 ? '#22c55e' : (p >= 50 ? '#f59e0b' : '#ef4444');
      return '<div class="bar-item">' +
        '<span class="bar-label" title="' + esc(r.Subscription) + '">' + esc(r.Subscription) + '</span>' +
        '<div class="bar-track"><div class="bar-fill" style="width:' + p + '%;background:' + color + '"></div></div>' +
        '<span class="bar-count">' + p + '%</span></div>';
    }).join('');
  })();

  renderBars('obs-chart-nodiag', toArr(diag.TopTypesWithoutDiag), 'Type', 'Count');

  var obsTiles = document.getElementById('obs-tiles');
  if (obsTiles) {
    [
      { icon: '🔭', label: 'Application Insights', value: oCounts.AppInsights },
      { icon: '📥', label: 'Data Collection Rules', value: oCounts.DataCollectionRules },
      { icon: '🛰️', label: 'Data Collection Endpoints', value: oCounts.DataCollectionEndpoints },
      { icon: '🔔', label: 'Action Groups', value: oCounts.ActionGroups },
      { icon: '🚨', label: 'Alert Rules', value: oCounts.AlertRules },
      { icon: '📓', label: 'Workbooks', value: oCounts.Workbooks },
      { icon: '📺', label: 'Dashboards', value: oCounts.Dashboards },
      { icon: '📈', label: 'Managed Grafana', value: oCounts.Grafana },
      { icon: '⚙️', label: 'Automation Accounts', value: oCounts.AutomationAccounts }
    ].forEach(function (t) {
      obsTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + fmt(t.value || 0) + '</div>'));
    });
  }

  /* ════════════════════════ DIAGNOSTIC SETTINGS ═════════════════════ */
  var diagSum = diag.Summary || {};
  setHeader('diag-header', '🩺', 'Diagnostic Settings',
    'Per-resource diagnostic settings, destinations and log/metric categories',
    '<span class="chip blue">' + fmt(diagSum.Evaluated || 0) + ' evaluated</span>' +
    '<span class="chip good">' + fmt(diagSum.Enabled || 0) + ' enabled</span>');
  var diagCards = document.getElementById('diag-cards');
  if (diagCards) {
    var diagCov = (diagSum.Percent === null || diagSum.Percent === undefined) ? '—' : diagSum.Percent + '%';
    [
      { icon: '📦', label: 'Total Azure Resources',  value: fmt(diagSum.TotalResources || 0), sub: 'all resource types' },
      { icon: '🩺', label: 'Diagnosable Resources',  value: fmt(diagSum.Evaluated || 0),      sub: 'support diag settings' },
      { icon: '✅', label: 'With Diagnostic Settings', value: fmt(diagSum.Enabled || 0),       sub: 'forwarding logs/metrics' },
      { icon: '🛡️', label: 'Coverage',               value: diagCov,                          sub: fmt(diagSum.Enabled || 0) + ' / ' + fmt(diagSum.Evaluated || 0) }
    ].forEach(function (t) {
      diagCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }
  function diagPill(v) {
    var on = v === 'Enabled';
    return '<span class="status-pill"><span class="status-dot ' + (on ? 'ok' : 'bad') + '"></span>' + esc(v) + '</span>';
  }
  function catPills(arr, on) {
    arr = toArr(arr);
    if (!arr.length) return '';
    return arr.map(function (c) { return '<span class="cat-pill ' + (on ? 'on' : 'off') + '">' + esc(c) + '</span>'; }).join('');
  }
  initDataTable({
    ids: { thead:'diag-thead', tbody:'diag-tbody', colgroup:'diag-colgroup',
           pager:'diag-pager', tags:'diag-active-filters', search:'diag-global-search' },
    pageSize: 15,
    emptyText: 'No resources match the current filters.',
    data: toArr(diag.Resources).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—',
        rg:           r.ResourceGroup || '—',
        name:         r.Name || '—',
        type:         r.Type || '—',
        enabled:      r.Enabled ? 'Enabled' : 'Not configured',
        destinations: toArr(r.Destinations).join(', ') || '—',
        id:           r.Id || '',
        tags:         r.Tags || null,
        settings:     toArr(r.Settings)
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:170 },
      { key:'rg',           label:'Resource Group', width:160 },
      { key:'name',         label:'Resource',       width:190 },
      { key:'type',         label:'Type',           width:170, render:function (r) { return monoCell(r.type); } },
      { key:'enabled',      label:'Diag Settings',  width:140, render:function (r) { return diagPill(r.enabled); } },
      { key:'destinations', label:'Destinations',   width:180 },
      { key:'_actions',     label:'',               width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var settings = toArr(row.settings);
      var setHtml = settings.length
        ? settings.map(function (s) {
            var dests = [];
            if (s.LogAnalytics) dests.push('<div class="kv"><span class="kv-k">Log Analytics</span><span class="kv-v">' + esc(s.LogAnalytics) + '</span></div>');
            if (s.Storage)      dests.push('<div class="kv"><span class="kv-k">Storage</span><span class="kv-v">' + esc(s.Storage) + '</span></div>');
            if (s.EventHub)     dests.push('<div class="kv"><span class="kv-k">Event Hub</span><span class="kv-v">' + esc(s.EventHub) + '</span></div>');
            if (s.ThirdParty)   dests.push('<div class="kv"><span class="kv-k">Third-party</span><span class="kv-v">' + esc(s.ThirdParty) + '</span></div>');
            var destHtml = dests.length ? '<div class="kv-grid">' + dests.join('') + '</div>' : '<span class="cell-muted">No destination</span>';
            var logsHtml = (catPills(s.LogsEnabled, true) + catPills(s.LogsDisabled, false)) || '<span class="cell-muted">—</span>';
            var metHtml  = (catPills(s.MetricsEnabled, true) + catPills(s.MetricsDisabled, false)) || '<span class="cell-muted">—</span>';
            return '<div class="diag-setting">' +
              '<div class="diag-setting-name">&#9881; ' + esc(s.Name) + '</div>' + destHtml +
              '<div class="diag-cats"><span class="diag-cats-label">Logs</span><span>' + logsHtml + '</span></div>' +
              '<div class="diag-cats"><span class="diag-cats-label">Metrics</span><span>' + metHtml + '</span></div>' +
            '</div>';
          }).join('')
        : '<span class="tags-empty">No diagnostic settings configured for this resource.</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Diagnostic settings (' + settings.length + ')</div>' + setHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* ════════════════════ AMA & DATA COLLECTION (DCR/DCE) ══════════════ */
  var dcData = d.dataCollection || {};
  var dcCounts = dcData.Counts || {};
  setHeader('dcr-header', '🛰️', 'AMA & Data Collection',
    'Azure Monitor Agent, Data Collection Rules, associations and endpoints',
    '<span class="chip blue">' + fmt(dcCounts.Dcr || 0) + ' DCRs</span>' +
    '<span class="chip good">' + fmt(dcCounts.MachinesWithAma || 0) + ' / ' + fmt(dcCounts.Machines || 0) + ' with AMA</span>');
  var dcCards = document.getElementById('dcr-cards');
  if (dcCards) {
    [
      { icon: '📐', label: 'Data Collection Rules',     value: fmt(dcCounts.Dcr || 0),             sub: 'DCRs' },
      { icon: '🔌', label: 'Data Collection Endpoints', value: fmt(dcCounts.Dce || 0),             sub: 'DCEs' },
      { icon: '🖥️', label: 'Machines',                  value: fmt(dcCounts.Machines || 0),        sub: 'VM + Arc' },
      { icon: '🛰️', label: 'Machines with AMA',         value: fmt(dcCounts.MachinesWithAma || 0), sub: 'agent installed' },
      { icon: '🔗', label: 'DCR Associations',          value: fmt(dcCounts.Associations || 0),    sub: 'machine ↔ DCR' }
    ].forEach(function (t) {
      dcCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }

  /* VM | DCR | Destination flow diagram — filterable, zoomable, pannable */
  (function () {
    var wrap = document.getElementById('dcr-graph');
    if (!wrap) return;
    var g = dcData.Graph || {};
    var vms = toArr(g.Vms), dcrs = toArr(g.Dcrs), dests = toArr(g.Dests);
    var vmDcr = toArr(g.VmDcrEdges), dcrDest = toArr(g.DcrDestEdges);
    if (!dcrs.length) { wrap.innerHTML = '<div class="empty-state">No Data Collection Rules to display.</div>'; return; }

    var selSub = new Set(), selRg = new Set(), selMachine = new Set(), selDcr = new Set(), scale = 1;
    function distVm(key) { var s = {}; vms.forEach(function (n) { s[n[key] || '—'] = true; }); return Object.keys(s).sort(); }
    function distDcr() { var s = {}; dcrs.forEach(function (n) { s[n.name] = true; }); return Object.keys(s).sort(); }
    /* Subscription / Resource Group / Machine narrow the VM column; the DCR
       filter narrows the DCR column. DCRs are no longer filtered by VM sub/RG
       (they often live in a central monitoring RG). */
    function passVm(n) {
      if (selSub.size && !selSub.has(n.sub || '—')) return false;
      if (selRg.size && !selRg.has(n.rg || '—')) return false;
      if (selMachine.size && !selMachine.has(n.name)) return false;
      return true;
    }
    function link(x1, y1, x2, y2, color) {
      var mx = (x1 + x2) / 2;
      return '<path d="M' + x1 + ' ' + y1 + ' C' + mx + ' ' + y1 + ' ' + mx + ' ' + y2 + ' ' + x2 + ' ' + y2 + '" fill="none" stroke="' + color + '" stroke-width="1.3"/>';
    }
    function applyZoom() {
      var svg = document.getElementById('dcr-graph-svg'); if (!svg) return;
      var w = +svg.getAttribute('data-w'), h = +svg.getAttribute('data-h');
      svg.setAttribute('width', Math.round(w * scale)); svg.setAttribute('height', Math.round(h * scale));
      var lbl = document.getElementById('dcr-zoom-label'); if (lbl) lbl.textContent = Math.round(scale * 100) + '%';
    }
    function draw() {
      var anyVmFilter = selSub.size || selRg.size || selMachine.size;
      var vmCand = vms.filter(passVm);
      var vmCandSet = {}; vmCand.forEach(function (n) { vmCandSet[n.id] = true; });
      var dcrCand = selDcr.size ? dcrs.filter(function (n) { return selDcr.has(n.name); }) : dcrs;
      var dcrCandSet = {}; dcrCand.forEach(function (n) { dcrCandSet[n.id] = true; });
      var e1c = vmDcr.filter(function (e) { return vmCandSet[e.From] && dcrCandSet[e.To]; });
      var dcrConn = {}; e1c.forEach(function (e) { dcrConn[e.To] = true; });
      /* when narrowing by VM, show only DCRs tied to the chosen machines;
         otherwise show all candidate DCRs (incl. orphans, to expose DCR→Dest) */
      var dcrShown = anyVmFilter ? dcrCand.filter(function (n) { return dcrConn[n.id]; }) : dcrCand;
      var dcrIdx = {}; dcrShown.forEach(function (n) { dcrIdx[n.id] = true; });
      var e1 = e1c.filter(function (e) { return dcrIdx[e.To]; });
      var vmKeep = {}; e1.forEach(function (e) { vmKeep[e.From] = true; });
      var vmShown = vmCand.filter(function (n) { return vmKeep[n.id]; });
      var e2 = dcrDest.filter(function (e) { return dcrIdx[e.From]; });
      var destKeep = {}; e2.forEach(function (e) { destKeep[e.To] = true; });
      var destShown = dests.filter(function (n) { return destKeep[n.id]; });

      if (!dcrShown.length) { wrap.innerHTML = '<div class="empty-state">No DCRs match the current filters.</div>'; return; }

      var NODE_W = 210, NODE_H = 34, GAPY = 14, COLGAP = 130, TOP = 34;
      var col1 = 12, col2 = col1 + NODE_W + COLGAP, col3 = col2 + NODE_W + COLGAP;
      var rows = Math.max(vmShown.length, dcrShown.length, destShown.length, 1);
      var H = TOP + rows * (NODE_H + GAPY) + 12, W = col3 + NODE_W + 12;
      function colY(i) { return TOP + i * (NODE_H + GAPY); }
      var posV = {}, posD = {}, posT = {};
      vmShown.forEach(function (n, i) { n._y = colY(i); posV[n.id] = n; });
      dcrShown.forEach(function (n, i) { n._y = colY(i); posD[n.id] = n; });
      destShown.forEach(function (n, i) { n._y = colY(i); posT[n.id] = n; });

      var edgeSvg = e1.map(function (e) { var a = posV[e.From], b = posD[e.To]; return (a && b) ? link(col1 + NODE_W, a._y + NODE_H / 2, col2, b._y + NODE_H / 2, '#5b6b86') : ''; }).join('')
        + e2.filter(function (e) { return posT[e.To]; }).map(function (e) { var a = posD[e.From], b = posT[e.To]; return (a && b) ? link(col2 + NODE_W, a._y + NODE_H / 2, col3, b._y + NODE_H / 2, '#3a7a52') : ''; }).join('');
      function node(n, x, fill, stroke) {
        var nm = n.name.length > 27 ? n.name.slice(0, 26) + '…' : n.name;
        return '<g><rect x="' + x + '" y="' + n._y + '" width="' + NODE_W + '" height="' + NODE_H + '" rx="8" fill="' + fill + '" stroke="' + stroke + '" stroke-width="1.3"/>' +
          '<text x="' + (x + 12) + '" y="' + (n._y + NODE_H / 2 + 4) + '" font-family="Segoe UI,system-ui,sans-serif" font-size="11.5" fill="#e2e8f0">' + esc(nm) + '</text>' +
          '<title>' + esc(n.name) + '</title></g>';
      }
      var nodeSvg = vmShown.map(function (n) { return node(n, col1, '#0c2c3f', '#0ea5e9'); }).join('')
        + dcrShown.map(function (n) { return node(n, col2, '#231a3a', '#a78bfa'); }).join('')
        + destShown.map(function (n) { return node(n, col3, '#0f2e1c', '#22c55e'); }).join('');
      var heads = '<text x="' + col1 + '" y="18" font-size="11" font-weight="700" fill="#0ea5e9">VM / Machine</text>' +
        '<text x="' + col2 + '" y="18" font-size="11" font-weight="700" fill="#a78bfa">Data Collection Rule</text>' +
        '<text x="' + col3 + '" y="18" font-size="11" font-weight="700" fill="#22c55e">Destination</text>';
      wrap.innerHTML = '<svg id="dcr-graph-svg" data-w="' + W + '" data-h="' + H + '" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + ' ' + H + '" width="' + W + '" height="' + H + '">' + heads + edgeSvg + nodeSvg + '</svg>';
      applyZoom();
    }
    function bind(id, fn) { var b = document.getElementById(id); if (b) b.onclick = fn; }
    bind('dcr-zoom-in', function () { scale = Math.min(3, +(scale + 0.2).toFixed(2)); applyZoom(); });
    bind('dcr-zoom-out', function () { scale = Math.max(0.3, +(scale - 0.2).toFixed(2)); applyZoom(); });
    bind('dcr-zoom-reset', function () { scale = 1; applyZoom(); });
    bind('dcr-download', function () { var svg = document.getElementById('dcr-graph-svg'); if (svg) aerDownloadPng(svg, +svg.getAttribute('data-w'), +svg.getAttribute('data-h'), 'ama-dcr-diagram.png'); });

    (function () {
      var down = false, sx, sy, sl, st;
      wrap.addEventListener('mousedown', function (e) { if (e.button !== 0) return; down = true; wrap.classList.add('panning'); sx = e.clientX; sy = e.clientY; sl = wrap.scrollLeft; st = wrap.scrollTop; e.preventDefault(); });
      window.addEventListener('mousemove', function (e) { if (!down) return; wrap.scrollLeft = sl - (e.clientX - sx); wrap.scrollTop = st - (e.clientY - sy); });
      window.addEventListener('mouseup', function () { if (down) { down = false; wrap.classList.remove('panning'); } });
    })();

    function renderTags() {
      var tagsEl = document.getElementById('dcr-filter-tags'); if (!tagsEl) return;
      var parts = [];
      if (selSub.size) parts.push('Sub: ' + selSub.size);
      if (selRg.size) parts.push('RG: ' + selRg.size);
      if (selMachine.size) parts.push('Machine: ' + selMachine.size);
      if (selDcr.size) parts.push('DCR: ' + selDcr.size);
      tagsEl.innerHTML = parts.length
        ? parts.map(function (p) { return '<span class="filter-tag">' + esc(p) + '</span>'; }).join('') + '<button class="filter-clear-all" id="dcr-clear-all">Clear all</button>'
        : '';
      var c = document.getElementById('dcr-clear-all');
      if (c) c.addEventListener('click', function () {
        selSub.clear(); selRg.clear(); selMachine.clear(); selDcr.clear();
        ['dcr-f-sub', 'dcr-f-rg', 'dcr-f-machine', 'dcr-f-dcr'].forEach(function (id) { var b = document.getElementById(id); if (b) b.classList.remove('active'); });
        renderTags(); draw();
      });
    }
    function setupFilter(btnId, values, sel) {
      var btn = document.getElementById(btnId); if (!btn) return;
      var dd = el('div', 'filter-dropdown'); document.body.appendChild(dd);
      /* Build the shell ONCE; only the list is repainted on input so the search
         box keeps focus (rebuilding innerHTML on each keystroke dropped focus). */
      dd.innerHTML = '<div class="filter-dd-search"><input type="text" placeholder="Search..." class="gq"/></div>' +
        '<div class="filter-dd-actions"><button class="filter-dd-action" data-a="all">Select all</button><button class="filter-dd-action" data-a="clear">Clear</button></div>' +
        '<div class="filter-dd-list"></div>';
      var listEl = dd.querySelector('.filter-dd-list');
      var sq = dd.querySelector('.gq');
      function paintList() {
        var q = (sq.value || '').toLowerCase();
        var shown = values.filter(function (v) { return v.toLowerCase().indexOf(q) !== -1; });
        listEl.innerHTML = shown.length ? shown.map(function (v) {
          return '<label class="filter-dd-item"><input type="checkbox" value="' + esc(v) + '" ' + (sel.has(v) ? 'checked' : '') + '/>' +
            '<span class="filter-dd-item-label" title="' + esc(v) + '">' + esc(v) + '</span></label>';
        }).join('') : '<div class="filter-dd-empty">No matches</div>';
        listEl.querySelectorAll('input[type=checkbox]').forEach(function (cb) {
          cb.addEventListener('change', function () { if (cb.checked) sel.add(cb.value); else sel.delete(cb.value); btn.classList.toggle('active', sel.size > 0); renderTags(); draw(); });
        });
      }
      sq.addEventListener('input', paintList);
      dd.querySelector('[data-a=all]').addEventListener('click', function () {
        var q = (sq.value || '').toLowerCase();
        values.filter(function (v) { return v.toLowerCase().indexOf(q) !== -1; }).forEach(function (v) { sel.add(v); });
        btn.classList.toggle('active', sel.size > 0); renderTags(); draw(); paintList();
      });
      dd.querySelector('[data-a=clear]').addEventListener('click', function () { sel.clear(); btn.classList.remove('active'); renderTags(); draw(); paintList(); });
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (dd.classList.contains('open')) { dd.classList.remove('open'); return; }
        paintList();
        var r = btn.getBoundingClientRect();
        dd.style.top = (r.bottom + window.scrollY + 4) + 'px'; dd.style.left = (r.left + window.scrollX) + 'px';
        dd.classList.add('open'); sq.focus();
      });
      document.addEventListener('click', function (e) { if (dd.classList.contains('open') && !dd.contains(e.target) && e.target !== btn) dd.classList.remove('open'); });
    }
    setupFilter('dcr-f-sub', distVm('sub'), selSub);
    setupFilter('dcr-f-rg', distVm('rg'), selRg);
    setupFilter('dcr-f-machine', distVm('name'), selMachine);
    setupFilter('dcr-f-dcr', distDcr(), selDcr);
    draw();
  })();

  /* DCR table */
  function destPills(arr) {
    arr = toArr(arr);
    if (!arr.length) return '<span class="cell-muted">—</span>';
    return arr.map(function (dst) { return '<span class="cat-pill on">' + esc(dst.Type) + ': ' + esc(dst.Name) + '</span>'; }).join('');
  }
  initDataTable({
    ids: { thead:'dcrtab-thead', tbody:'dcrtab-tbody', colgroup:'dcrtab-colgroup', pager:'dcrtab-pager', tags:'dcrtab-active-filters', search:'dcrtab-global-search' },
    pageSize: 15, emptyText: 'No Data Collection Rules match the current filters.',
    data: toArr(dcData.Dcrs).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—', rg: r.ResourceGroup || '—', name: r.Name || '—',
        kind: r.Kind || '—', region: r.Location || '—',
        destinations: toArr(r.Destinations).map(function (x) { return x.Type; }).filter(function (v, i, a) { return a.indexOf(v) === i; }).join(', ') || '—',
        machines: (r.MachineCount != null ? r.MachineCount : 0),
        id: r.Id || '', tags: r.Tags || null,
        destObjs: toArr(r.Destinations), streams: toArr(r.Streams), dsKinds: toArr(r.DataSourceKinds)
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:170 },
      { key:'rg',           label:'Resource Group', width:160 },
      { key:'name',         label:'Resource',       width:200 },
      { key:'kind',         label:'Kind',           width:90 },
      { key:'destinations', label:'Destinations',   width:170 },
      { key:'machines',     label:'Machines',       width:90, render:function (r) { return fmt(r.machines); } },
      { key:'_actions',     label:'',               width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var streams = toArr(row.streams), dsk = toArr(row.dsKinds);
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Destinations</div>' + destPills(row.destObjs) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Data sources</div>' + (dsk.length ? dsk.map(function (k) { return '<span class="cat-pill off">' + esc(k) + '</span>'; }).join('') : '<span class="cell-muted">—</span>') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Streams</div>' + (streams.length ? streams.map(function (s) { return '<span class="cat-pill off">' + esc(s) + '</span>'; }).join('') : '<span class="cell-muted">—</span>') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* Machines & AMA table */
  function amaPill(installed, ver) {
    return '<span class="status-pill"><span class="status-dot ' + (installed ? 'ok' : 'bad') + '"></span>' + (installed ? ('Installed' + (ver ? ' ' + esc(ver) : '')) : 'Not installed') + '</span>';
  }
  initDataTable({
    ids: { thead:'ama-thead', tbody:'ama-tbody', colgroup:'ama-colgroup', pager:'ama-pager', tags:'ama-active-filters', search:'ama-global-search' },
    pageSize: 15, emptyText: 'No machines match the current filters.',
    data: toArr(dcData.Machines).map(function (r) {
      return {
        name: r.Name || '—', kind: r.Kind || '—', subscription: r.SubscriptionName || '—', rg: r.ResourceGroup || '—',
        region: r.Location || '—', ama: r.AmaInstalled ? 'Installed' : 'Not installed', amaVer: r.AmaVersion || '',
        dcrs: toArr(r.Dcrs).join(', ') || '—', dces: toArr(r.Dces).join(', ') || '—',
        id: r.Id || '', dcrList: toArr(r.Dcrs), dceList: toArr(r.Dces), amaInstalled: !!r.AmaInstalled
      };
    }),
    columns: [
      { key:'name',         label:'Machine',        width:180 },
      { key:'kind',         label:'Type',           width:80 },
      { key:'subscription', label:'Subscription',   width:160 },
      { key:'rg',           label:'Resource Group', width:150 },
      { key:'region',       label:'Region',         width:100, hidden:true },
      { key:'ama',          label:'AMA',            width:150, render:function (r) { return amaPill(r.amaInstalled, r.amaVer); } },
      { key:'dcrs',         label:'DCRs',           width:180 },
      { key:'_actions',     label:'',               width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var dcrs = toArr(row.dcrList), dces = toArr(row.dceList);
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Associated DCRs (' + dcrs.length + ')</div>' + (dcrs.length ? dcrs.map(function (n) { return '<span class="cat-pill on">' + esc(n) + '</span>'; }).join('') : '<span class="cell-muted">None</span>') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Associated DCEs (' + dces.length + ')</div>' + (dces.length ? dces.map(function (n) { return '<span class="cat-pill off">' + esc(n) + '</span>'; }).join('') : '<span class="cell-muted">None</span>') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Azure Monitor Agent</div>' + amaPill(row.amaInstalled, row.amaVer) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
      '</div>';
    }
  });

  /* DCE table */
  initDataTable({
    ids: { thead:'dce-thead', tbody:'dce-tbody', colgroup:'dce-colgroup', pager:'dce-pager', tags:'dce-active-filters', search:'dce-global-search' },
    pageSize: 10, emptyText: 'No Data Collection Endpoints found.',
    data: toArr(dcData.Dces).map(function (r) {
      return { subscription: r.SubscriptionName || '—', rg: r.ResourceGroup || '—', name: r.Name || '—', region: r.Location || '—', id: r.Id || '', tags: r.Tags || null };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:200 },
      { key:'rg',           label:'Resource Group', width:180 },
      { key:'name',         label:'Resource',       width:220 },
      { key:'region',       label:'Region',         width:120 },
      { key:'_actions',     label:'',               width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* ════════════════════ OBSERVABILITY INVENTORY ═════════════════════ */
  var obsInv = d.obsInventory || {};
  var obsInvC = obsInv.Counts || {};
  setHeader('obsinv-header', '🗂️', 'Observability Inventory',
    'Log Analytics workspaces and Application Insights across all scanned subscriptions',
    '<span class="chip blue">' + fmt(obsInvC.AppInsights || 0) + ' App Insights</span>' +
    '<span class="chip good">' + fmt(obsInvC.Workspaces || 0) + ' Log Analytics workspaces</span>');
  function ynPill(v) {
    return '<span class="status-pill"><span class="status-dot ' + (v ? 'ok' : '') + '"></span>' + (v ? 'Yes' : 'No') + '</span>';
  }
  initDataTable({
    ids: { thead:'obsinv-thead', tbody:'obsinv-tbody', colgroup:'obsinv-colgroup', pager:'obsinv-pager', tags:'obsinv-active-filters', search:'obsinv-global-search' },
    pageSize: 15, emptyText: 'No Log Analytics workspaces match the current filters.',
    data: toArr(obsInv.Workspaces).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—', rg: r.ResourceGroup || '—', name: r.Name || '—',
        usedByAi: r.UsedByAppInsights ? 'Yes' : 'No', retention: (r.Retention != null ? r.Retention : 0),
        sku: r.Sku || '—', quota: (r.DailyQuotaGb != null ? r.DailyQuotaGb : null),
        exportStorage: r.ExportToStorage ? 'Yes' : 'No', region: r.Location || '—',
        ingestion: r.IngestionAccess || '', id: r.Id || '', tags: r.Tags || null,
        usedByAiB: !!r.UsedByAppInsights, exportB: !!r.ExportToStorage
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',      width:170 },
      { key:'rg',           label:'Resource Group',    width:160 },
      { key:'name',         label:'Workspace',         width:190 },
      { key:'usedByAi',     label:'Used by App Insights', width:150, render:function (r) { return ynPill(r.usedByAiB); } },
      { key:'retention',    label:'Retention',         width:110, render:function (r) { return r.retention ? fmt(r.retention) + ' days' : '<span class="cell-muted">—</span>'; } },
      { key:'exportStorage',label:'Export to Storage', width:140, render:function (r) { return ynPill(r.exportB); } },
      { key:'sku',          label:'SKU',               width:130, hidden:true, render:function (r) { return monoCell(r.sku); } },
      { key:'quota',        label:'Daily quota',       width:120, hidden:true, render:function (r) { return r.quota != null ? fmt(r.quota) + ' GB' : 'Unlimited'; } },
      { key:'_actions',     label:'',                  width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var pairs = [
        { label:'SKU',                value: row.sku },
        { label:'Retention',          value: row.retention ? row.retention + ' days' : '' },
        { label:'Daily quota',        value: (row.quota != null ? row.quota + ' GB' : 'Unlimited') },
        { label:'Used by App Insights', value: row.usedByAi },
        { label:'Export to storage',  value: row.exportStorage },
        { label:'Ingestion access',   value: row.ingestion },
        { label:'Region',             value: row.region }
      ];
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Details</div>' + (kvGrid(pairs) || '<span class="tags-empty">No details</span>') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* ════════════════════════════ POLICY ══════════════════════════════ */
  var pol = d.policy || {};
  var polC = pol.Compliance || {}, polA = pol.Assignments || {};
  var polPct = (polC.OverallPercent == null) ? '—' : polC.OverallPercent + '%';
  setHeader('policy-header', '⚖️', 'Policy',
    'Azure Policy compliance and assignments across all scanned subscriptions',
    '<span class="chip blue">' + fmt(polA.Total || 0) + ' assignments</span>' +
    '<span class="chip ' + ((polC.OverallPercent != null && polC.OverallPercent >= 80) ? 'good' : 'warn') + '">' + polPct + ' compliant</span>');
  var polCards = document.getElementById('policy-cards');
  if (polCards) {
    [
      { icon: '🛡️', label: 'Overall Compliance',     value: polPct,                           sub: fmt(polC.Compliant || 0) + ' / ' + fmt(polC.Evaluated || 0) + ' evaluated' },
      { icon: '✅', label: 'Compliant',              value: fmt(polC.Compliant || 0),         sub: 'policy states' },
      { icon: '⛔', label: 'Non-compliant',          value: fmt(polC.NonCompliant || 0),      sub: 'policy states' },
      { icon: '🧩', label: 'Initiative Assignments', value: fmt(polA.Initiative || 0),        sub: 'policy sets' },
      { icon: '📋', label: 'Policy Assignments',     value: fmt(polA.Policy || 0),            sub: 'single policies' },
      { icon: '🔧', label: 'Pending Remediation',    value: fmt(pol.PendingRemediation || 0), sub: 'DINE / Modify' }
    ].forEach(function (t) {
      polCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }
  renderDonut('policy-chart-compliance', [
    { name: 'Compliant',     count: polC.Compliant || 0,    color: '#22c55e' },
    { name: 'Non-compliant', count: polC.NonCompliant || 0, color: '#ef4444' },
    { name: 'Conflict',      count: polC.Conflict || 0,     color: '#f59e0b' }
  ], null, (polC.OverallPercent == null ? '' : polC.OverallPercent + '%'));
  renderBars('policy-chart-effect', toArr(pol.EffectsByType), 'Effect', 'Count');

  function policyCompliancePill(row) {
    if (!row.evaluated) return '<span class="status-pill"><span class="status-dot"></span>Not evaluated</span>';
    var on = row.compliant;
    return '<span class="status-pill"><span class="status-dot ' + (on ? 'ok' : 'bad') + '"></span>' + (on ? 'Compliant' : 'Non-compliant') + '</span>';
  }
  initDataTable({
    ids: { thead:'policy-thead', tbody:'policy-tbody', colgroup:'policy-colgroup', pager:'policy-pager', tags:'policy-active-filters', search:'policy-global-search' },
    pageSize: 15, emptyText: 'No policy assignments match the current filters.',
    data: toArr(pol.Items).map(function (r) {
      return {
        name:        r.Name || '—',
        type:        r.Type || '—',
        scope:       r.Scope || '—',
        compliance:  !r.Evaluated ? 'Not evaluated' : (r.Compliant ? 'Compliant' : 'Non-compliant'),
        percent:     (r.CompliancePercent == null ? null : r.CompliancePercent),
        id:          r.Id || '',
        compliant:   !!r.Compliant, evaluated: !!r.Evaluated,
        definition:  r.Definition || '', enforcement: r.EnforcementMode || '', identity: r.IdentityType || '',
        members:     toArr(r.Members), params: toArr(r.Parameters),
        compliantCount: r.CompliantCount || 0, nonCompliantCount: r.NonCompliantCount || 0
      };
    }),
    columns: [
      { key:'name',       label:'Name',         width:280 },
      { key:'type',       label:'Type',         width:110 },
      { key:'scope',      label:'Assignment Scope', width:230 },
      { key:'compliance', label:'Compliance',   width:150, render:function (r) { return policyCompliancePill(r); } },
      { key:'percent',    label:'% Compliant',  width:120, render:function (r) { return r.percent == null ? '<span class="cell-muted">—</span>' : r.percent + '%'; } },
      { key:'_actions',   label:'',             width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var pairs = [
        { label:'Definition',          value: row.definition },
        { label:'Enforcement mode',    value: row.enforcement },
        { label:'Remediation identity', value: row.identity ? row.identity : 'None' },
        { label:'Compliant resources', value: fmt(row.compliantCount) },
        { label:'Non-compliant resources', value: fmt(row.nonCompliantCount) }
      ];
      var members = toArr(row.members);
      var memberHtml = (row.type === 'Initiative')
        ? (members.length
            ? '<div class="pill-row">' + members.map(function (m) { return '<span class="pill pill-purple">📋 ' + esc(m) + '</span>'; }).join('') + '</div>'
            : '<span class="tags-empty">No member policies found</span>')
        : '';
      var params = toArr(row.params);
      var paramHtml = params.length
        ? kvGrid(params.map(function (p) { return { label: p.Name, value: p.Value }; }))
        : '<span class="cell-muted">No parameters set</span>';
      var html = '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Details</div>' + (kvGrid(pairs) || '') + '</div>';
      if (row.type === 'Initiative') {
        html += '<div class="res-detail-section"><div class="res-detail-label">Policies in initiative (' + members.length + ')</div>' + memberHtml + '</div>';
      }
      html += '<div class="res-detail-section"><div class="res-detail-label">Parameters</div>' + paramHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
      '</div>';
      return html;
    }
  });

  /* ════════════════════════ POLICY EXEMPTIONS ═══════════════════════ */
  var exempts = toArr(pol.Exemptions);
  setHeader('exempt-header', '🪪', 'Policy Exemptions',
    'Policy and initiative exemptions across all scanned subscriptions',
    '<span class="chip blue">' + fmt(exempts.length) + ' exemptions</span>');
  function expiryCell(r) {
    if (!r.expiresOn) return '<span class="cell-muted">Never</span>';
    return r.expired
      ? '<span class="status-pill"><span class="status-dot bad"></span>' + esc(r.expiresOn) + '</span>'
      : esc(r.expiresOn);
  }
  function catPill(c) {
    if (!c) return '<span class="cell-muted">—</span>';
    return '<span class="cat-pill ' + (c === 'Waiver' ? 'off' : 'on') + '">' + esc(c) + '</span>';
  }
  initDataTable({
    ids: { thead:'exempt-thead', tbody:'exempt-tbody', colgroup:'exempt-colgroup', pager:'exempt-pager', tags:'exempt-active-filters', search:'exempt-global-search' },
    pageSize: 15, emptyText: 'No policy exemptions match the current filters.',
    data: exempts.map(function (r) {
      return {
        name:       r.Name || '—',
        assignment: r.Assignment || '—',
        scope:      r.Scope || '—',
        category:   r.Category || '—',
        createdBy:  r.CreatedBy || '—',
        expiresOn:  r.ExpiresOn || '',
        expired:    !!r.Expired,
        id:         r.Id || '',
        description: r.Description || '',
        createdByType: r.CreatedByType || '',
        refIds:     toArr(r.ReferenceIds), appliesTo: toArr(r.AppliesTo), selectors: toArr(r.ResourceSelectors)
      };
    }),
    columns: [
      { key:'name',       label:'Name',            width:240 },
      { key:'assignment', label:'Assignment',      width:220 },
      { key:'scope',      label:'Scope',           width:220 },
      { key:'category',   label:'Category',        width:120, render:function (r) { return catPill(r.category === '—' ? '' : r.category); } },
      { key:'createdBy',  label:'Created By',      width:200, render:function (r) { return monoCell(r.createdBy); } },
      { key:'expiresOn',  label:'Expiration',      width:140, render:function (r) { return expiryCell(r); } },
      { key:'_actions',   label:'',                width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var sels = toArr(row.selectors);
      var selHtml = sels.length
        ? '<div class="pill-row">' + sels.map(function (s) { return '<span class="pill pill-cyan">' + esc(s) + '</span>'; }).join('') + '</div>'
        : '<span class="cell-muted">None (applies to the entire assignment scope)</span>';
      var refs = toArr(row.refIds);
      var refHtml = refs.length
        ? '<div class="pill-row">' + refs.map(function (s) { return '<span class="pill pill-blue">' + esc(s) + '</span>'; }).join('') + '</div>'
        : '<span class="cell-muted">All policies in the assignment</span>';
      var applies = toArr(row.appliesTo);
      var appliesHtml = applies.length
        ? '<div class="pill-row">' + applies.map(function (s) { return '<span class="pill pill-purple">📋 ' + esc(s) + '</span>'; }).join('') + '</div>'
        : '<span class="cell-muted">—</span>';
      var meta = kvGrid([
        { label:'Created by',      value: row.createdBy },
        { label:'Created by type', value: row.createdByType },
        { label:'Description',     value: row.description }
      ]);
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource selectors</div>' + selHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Exemption policies (reference IDs)</div>' + refHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Applies to policies</div>' + appliesHtml + '</div>' +
        (meta ? '<div class="res-detail-section"><div class="res-detail-label">Details</div>' + meta + '</div>' : '') +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
      '</div>';
    }
  });

  /* ════════════════════════ POLICY REMEDIATION ══════════════════════ */
  var rem = pol.Remediation || {};
  setHeader('rem-header', '🔧', 'Policy Remediation',
    'Resources awaiting remediation (DeployIfNotExists / Modify) and recent remediation tasks',
    '<span class="chip warn">' + fmt(rem.ResourcesToRemediate || 0) + ' resources</span>');
  var remCards = document.getElementById('rem-cards');
  if (remCards) {
    [
      { icon: '📜', label: 'Policies to Remediate',  value: fmt(rem.PoliciesToRemediate || 0),  sub: 'DINE / Modify policies' },
      { icon: '🧱', label: 'Resources to Remediate', value: fmt(rem.ResourcesToRemediate || 0), sub: 'non-compliant resources' }
    ].forEach(function (t) {
      remCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }
  initDataTable({
    ids: { thead:'rem-thead', tbody:'rem-tbody', colgroup:'rem-colgroup', pager:'rem-pager', tags:'rem-active-filters', search:'rem-global-search' },
    pageSize: 15, emptyText: 'No resources awaiting remediation.',
    data: toArr(rem.Items).map(function (r) {
      return {
        policy:     r.Policy || '—',
        assignment: r.Assignment || '—',
        scope:      r.Scope || '—',
        count:      (r.ResourceCount != null ? r.ResourceCount : 0),
        resources:  toArr(r.Resources)
      };
    }),
    columns: [
      { key:'policy',     label:'Policy',           width:280 },
      { key:'assignment', label:'Assignment',       width:200 },
      { key:'scope',      label:'Scope',            width:230 },
      { key:'count',      label:'Resources to Remediate', width:180, render:function (r) { return fmt(r.count); } }
    ],
    detail: function (row) {
      var res = toArr(row.resources);
      var body = res.length
        ? '<div class="pill-row">' + res.map(function (x) { return '<span class="pill pill-orange">🧱 ' + esc(x) + '</span>'; }).join('') + '</div>'
          + (row.count > res.length ? '<div class="cell-muted" style="margin-top:6px">+' + (row.count - res.length) + ' more</div>' : '')
        : '<span class="tags-empty">No resources</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Resources to remediate (' + row.count + ')</div>' + body + '</div>' +
      '</div>';
    }
  });
  function remStatePill(s) {
    if (!s) return '<span class="cell-muted">—</span>';
    var low = String(s).toLowerCase(), cls = '';
    if (low === 'succeeded' || low === 'complete') cls = 'ok';
    else if (low === 'failed' || low === 'canceled') cls = 'bad';
    else if (low === 'evaluating' || low === 'accepted' || low.indexOf('progress') !== -1) cls = 'warn';
    return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + esc(s) + '</span>';
  }
  initDataTable({
    ids: { thead:'remtask-thead', tbody:'remtask-tbody', colgroup:'remtask-colgroup', pager:'remtask-pager', tags:'remtask-active-filters', search:'remtask-global-search' },
    pageSize: 10, emptyText: 'No remediation tasks found.',
    data: toArr(rem.Tasks).map(function (r) {
      return {
        name:       r.Name || '—',
        assignment: r.Assignment || '—',
        scope:      r.Scope || '—',
        state:      r.State || '',
        deployments: fmt(r.Succeeded || 0) + ' / ' + fmt(r.Total || 0) + (r.Failed ? ' (' + fmt(r.Failed) + ' failed)' : ''),
        created:    r.CreatedOn || '—'
      };
    }),
    columns: [
      { key:'name',        label:'Task',           width:220 },
      { key:'assignment',  label:'Assignment',     width:200 },
      { key:'scope',       label:'Scope',          width:210 },
      { key:'state',       label:'State',          width:140, render:function (r) { return remStatePill(r.state); } },
      { key:'deployments', label:'Deployments',    width:160, noFilter:true },
      { key:'created',     label:'Created',        width:150 }
    ]
  });

  /* ════════════════ SECURITY — DEFENDER FOR CLOUD OVERVIEW ═══════════ */
  var def = d.defender || {};
  var defS = def.Summary || {};
  setHeader('def-header', '🔐', 'Security',
    'Microsoft Defender for Cloud posture and plan coverage across all scanned subscriptions',
    '<span class="chip bad">' + fmt(defS.Unhealthy || 0) + ' unhealthy</span>' +
    '<span class="chip good">' + fmt(defS.Healthy || 0) + ' healthy</span>');
  var defCards = document.getElementById('def-cards');
  if (defCards) {
    [
      { icon: '📋', label: 'Total Assessments', value: fmt(defS.Total || 0),        sub: 'security controls' },
      { icon: '⛔', label: 'Unhealthy',         value: fmt(defS.Unhealthy || 0),    sub: 'need attention' },
      { icon: '✅', label: 'Healthy',           value: fmt(defS.Healthy || 0),      sub: 'passing' },
      { icon: '➖', label: 'Not Applicable',    value: fmt(defS.NotApplicable || 0), sub: 'N/A' }
    ].forEach(function (t) {
      defCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }
  function planTierPill(p) {
    if (p.Active) return '<span class="status-pill"><span class="status-dot ' + (p.Partial ? 'warn' : 'ok') + '"></span>' + (p.Partial ? 'Standard (partial)' : 'Standard') + '</span>';
    return '<span class="status-pill"><span class="status-dot"></span>Free</span>';
  }
  initDataTable({
    ids: { thead:'def-thead', tbody:'def-tbody', colgroup:'def-colgroup', pager:'def-pager', tags:'def-active-filters', search:'def-global-search' },
    pageSize: 15, emptyText: 'No subscriptions found.',
    data: toArr(def.Subscriptions).map(function (r) {
      return {
        subscription: r.Subscription || '—',
        standard: (r.StandardCount != null ? r.StandardCount : 0),
        free: (r.FreeCount != null ? r.FreeCount : 0),
        total: (r.Total != null ? r.Total : 0),
        plans: toArr(r.Plans)
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',     width:300 },
      { key:'standard',     label:'Standard Plans',   width:160, render:function (r) { return fmt(r.standard); } },
      { key:'free',         label:'Free Plans',       width:140, render:function (r) { return fmt(r.free); } },
      { key:'total',        label:'Total Plans',      width:140, render:function (r) { return fmt(r.total); } }
    ],
    detail: function (row) {
      var plans = toArr(row.plans);
      if (!plans.length) return '<div class="res-detail"><span class="tags-empty">No Defender plans found.</span></div>';
      var body = plans.map(function (p) {
        var exts = toArr(p.Extensions);
        var extHtml = exts.length
          ? exts.map(function (e) { return '<span class="cat-pill ' + (e.Enabled ? 'on' : 'off') + '">' + esc(e.Name) + '</span>'; }).join('')
          : '<span class="cell-muted">—</span>';
        return '<tr><td>' + esc(p.Name) + (p.SubPlan ? ' <span class="cell-muted">(' + esc(p.SubPlan) + ')</span>' : '') + '</td><td>' + planTierPill(p) + '</td><td style="white-space:normal">' + extHtml + '</td></tr>';
      }).join('');
      return '<div class="res-detail"><div class="res-detail-section"><div class="res-detail-label">Defender plans &amp; sub-configurations</div>' +
        '<div class="table-scroll"><table class="aer-table simple"><thead><tr><th>Plan</th><th>Status</th><th>Sub-configurations (green = active, grey = inactive)</th></tr></thead><tbody>' +
        body + '</tbody></table></div></div></div>';
    }
  });

  /* ════════════════════ SECURITY RECOMMENDATIONS ════════════════════ */
  var defR = (def.Recommendations) || [];
  var sevC = def.SeverityCounts || {};
  setHeader('secrec-header', '🛡️', 'Security Recommendations',
    'Microsoft Defender for Cloud recommendations across all scanned subscriptions',
    '<span class="chip blue">' + fmt(toArr(defR).length) + ' recommendations</span>');
  var secrecCards = document.getElementById('secrec-cards');
  if (secrecCards) {
    [
      { icon: '🔴', label: 'Critical', value: fmt(sevC.Critical || 0), sub: 'unhealthy' },
      { icon: '🟠', label: 'High',     value: fmt(sevC.High || 0),     sub: 'unhealthy' },
      { icon: '🟡', label: 'Medium',   value: fmt(sevC.Medium || 0),   sub: 'unhealthy' },
      { icon: '🔵', label: 'Low',      value: fmt(sevC.Low || 0),      sub: 'unhealthy' }
    ].forEach(function (t) {
      secrecCards.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + t.value + '</div>' +
        '<div class="stat-tile-sub">' + t.sub + '</div>'));
    });
  }
  function riskPill(r) {
    var low = String(r || '').toLowerCase(), color = '#64748b';
    if (low === 'critical') color = '#ef4444';
    else if (low === 'high') color = '#f97316';
    else if (low === 'medium') color = '#f59e0b';
    else if (low === 'low') color = '#0ea5e9';
    return '<span class="cat-pill" style="border-color:' + color + '88;color:' + color + ';background:' + color + '1a">' + esc(r || 'Unknown') + '</span>';
  }
  function secStatusPill(s) {
    var low = String(s || '').toLowerCase(), cls = '';
    if (low === 'healthy') cls = 'ok';
    else if (low === 'unhealthy') cls = 'bad';
    return '<span class="status-pill"><span class="status-dot ' + cls + '"></span>' + esc(s || '—') + '</span>';
  }
  /* Defender remediation text is Azure-authored HTML (br/ol/li/a). Render it,
     but strip script/style blocks, inline event handlers and javascript: URLs. */
  function safeHtml(s) {
    if (!s) return '';
    return String(s)
      .replace(/<\s*(script|style)[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
      .replace(/\son\w+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
      .replace(/javascript:/gi, '');
  }
  var riskOrder = { Critical: 0, High: 1, Medium: 2, Low: 3, Unknown: 4 };
  initDataTable({
    ids: { thead:'secrec-thead', tbody:'secrec-tbody', colgroup:'secrec-colgroup', pager:'secrec-pager', tags:'secrec-active-filters', search:'secrec-global-search' },
    pageSize: 20, emptyText: 'No recommendations match the current filters.',
    data: toArr(defR).map(function (r) {
      return {
        risk:       r.RiskLevel || 'Unknown',
        title:      r.Title || '—',
        resource:   r.Resource || '—',
        status:     r.Status || '—',
        scope:      r.Scope || '—',
        lastChange: r.LastChange || '',
        remediation: r.Remediation || '',
        description: r.Description || '',
        riskFactors: toArr(r.RiskFactors),
        id:         r.ResourceId || ''
      };
    }).sort(function (a, b) { return (riskOrder[a.risk] != null ? riskOrder[a.risk] : 5) - (riskOrder[b.risk] != null ? riskOrder[b.risk] : 5); }),
    columns: [
      { key:'risk',     label:'Risk Level', width:120, render:function (r) { return riskPill(r.risk); } },
      { key:'title',    label:'Title',      width:340 },
      { key:'resource', label:'Affected Resource', width:200, render:function (r) { return monoCell(r.resource); } },
      { key:'status',   label:'Status',     width:140, render:function (r) { return secStatusPill(r.status); } },
      { key:'_actions', label:'',           width:104, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var rf = toArr(row.riskFactors);
      var rfHtml = rf.length
        ? '<div class="pill-row">' + rf.map(function (x) { return '<span class="pill pill-orange">⚠ ' + esc(x) + '</span>'; }).join('') + '</div>'
        : '<span class="cell-muted">—</span>';
      var pairs = [
        { label:'Scope',            value: row.scope },
        { label:'Last change date', value: row.lastChange },
        { label:'Status detail',    value: row.description }
      ];
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Details</div>' + (kvGrid(pairs) || '') + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Risk factors</div>' + rfHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Recommended remediation</div>' +
          '<div class="res-detail-text">' + (row.remediation ? safeHtml(row.remediation) : 'No remediation guidance available.') + '</div></div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Affected resource ID</div>' + idBlock(row.id) + '</div>' +
      '</div>';
    }
  });

  /* ════════════════════════════ VIRTUAL NETWORKS ════════════════════ */
  var vnetData = d.vnets || {};
  setHeader('vnet-header', '🔷', 'Virtual Networks',
    'Virtual networks, subnets, UDRs and peerings across all scanned subscriptions',
    '<span class="chip blue">' + fmt(toArr(vnetData.Vnets).length) + ' VNets</span>');

  initDataTable({
    ids: { thead:'vnet-thead', tbody:'vnet-tbody', colgroup:'vnet-colgroup',
           pager:'vnet-pager', tags:'vnet-active-filters', search:'vnet-global-search' },
    pageSize: 15,
    emptyText: 'No virtual networks match the current filters.',
    data: toArr(vnetData.Vnets).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—',
        rg:           r.ResourceGroup || '—',
        name:         r.Name || '—',
        address:      r.AddressSpace || '—',
        dns:          r.DnsServers || '',
        id:           r.Id || '',
        subnets:      toArr(r.Subnets),
        peerings:     toArr(r.Peerings),
        tags:         r.Tags || null
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:180 },
      { key:'rg',           label:'Resource Group', width:170 },
      { key:'name',         label:'Resource',       width:190 },
      { key:'address',      label:'Address Space',  width:200, render:function (r) { return monoCell(r.address); } },
      { key:'_actions',     label:'',               width:110, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var subnets = toArr(row.subnets);
      var subHtml = subnets.length
        ? '<div class="table-scroll"><table class="aer-table simple"><thead><tr><th>Subnet</th><th>Prefix</th><th>Route table (UDR)</th><th>Routes</th></tr></thead><tbody>' +
          subnets.map(function (s) {
            var routes = toArr(s.Routes);
            var rsum = routes.length
              ? routes.slice(0, 6).map(function (rt) { return esc(rt.Prefix) + ' &rarr; ' + esc(rt.NextHop); }).join('<br>') + (routes.length > 6 ? '<br><span class="cell-muted">+' + (routes.length - 6) + ' more</span>' : '')
              : '<span class="cell-muted">&mdash;</span>';
            return '<tr><td>' + esc(s.SubnetName || '—') + '</td><td>' + monoCell(s.Prefix) + '</td><td>' + esc(s.RouteTable || '—') + '</td><td style="white-space:normal">' + rsum + '</td></tr>';
          }).join('') + '</tbody></table></div>'
        : '<span class="tags-empty">No subnets</span>';
      var peers = toArr(row.peerings);
      var peerHtml = peers.length
        ? '<div class="table-scroll"><table class="aer-table simple"><thead><tr><th>Peering</th><th>Remote VNet</th><th>State</th><th>Gateway transit</th><th>Use remote GW</th><th>Forwarded traffic</th></tr></thead><tbody>' +
          peers.map(function (p) {
            return '<tr><td>' + esc(p.PeerName || '—') + '</td><td>' + esc(p.RemoteVnet || '—') + '</td><td>' + esc(p.State || '—') + '</td><td>' + (p.AllowGatewayTransit ? 'Yes' : 'No') + '</td><td>' + (p.UseRemoteGateways ? 'Yes' : 'No') + '</td><td>' + (p.AllowForwardedTraffic ? 'Yes' : 'No') + '</td></tr>';
          }).join('') + '</tbody></table></div>'
        : '<span class="tags-empty">No peerings</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">DNS servers</div>' +
          '<div class="res-detail-text">' + (row.dns ? esc(row.dns) : 'Azure-provided (default)') + '</div></div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Subnets (' + subnets.length + ')</div>' + subHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Peerings (' + peers.length + ')</div>' + peerHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });

  /* VNet peering diagram — filterable (sub/RG/VNet), zoomable, pannable */
  (function () {
    var wrap = document.getElementById('vnet-peering-graph');
    if (!wrap) return;
    var graph = vnetData.Graph || {};
    var allNodes = toArr(graph.Nodes), allEdges = toArr(graph.Edges);
    if (!allNodes.length) { wrap.innerHTML = '<div class="empty-state">No virtual networks to display.</div>'; return; }

    var selSub = new Set(), selRg = new Set(), selVnet = new Set(), scale = 1;
    function gDistinct(key) { var s = {}; allNodes.forEach(function (n) { s[n[key] || '—'] = true; }); return Object.keys(s).sort(); }
    function visible() {
      return allNodes.filter(function (n) {
        if (selSub.size && !selSub.has(n.sub || '—')) return false;
        if (selRg.size && !selRg.has(n.rg || '—')) return false;
        if (selVnet.size && !selVnet.has(n.name)) return false;
        return true;
      });
    }
    function applyZoom() {
      var svg = document.getElementById('vnet-graph-svg');
      if (!svg) return;
      var base = +svg.getAttribute('data-size');
      svg.setAttribute('width', Math.round(base * scale));
      svg.setAttribute('height', Math.round(base * scale));
      var lbl = document.getElementById('vnet-zoom-label'); if (lbl) lbl.textContent = Math.round(scale * 100) + '%';
    }
    function draw() {
      var nodes = visible();
      if (!nodes.length) { wrap.innerHTML = '<div class="empty-state">No VNets match the current filters.</div>'; return; }
      var idx = {}; nodes.forEach(function (n, i) { idx[n.id] = i; });
      var edges = allEdges.filter(function (e) { return idx[e.From] != null && idx[e.To] != null; });
      var N = nodes.length;
      var size = Math.max(380, Math.min(1500, 240 + N * 24));
      var cx = size / 2, cy = size / 2, r = size / 2 - 95;
      function pos(i) { var a = -Math.PI / 2 + 2 * Math.PI * i / N; return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) }; }
      var edgeSvg = edges.map(function (e) {
        var pa = pos(idx[e.From]), pb = pos(idx[e.To]);
        var gw = e.GatewayTransit || e.UseRemoteGateways;
        var title = nodes[idx[e.From]].name + '  <->  ' + nodes[idx[e.To]].name + (gw ? ' · gateway transit' : '') + (e.State ? ' · ' + e.State : '');
        return '<line x1="' + pa.x + '" y1="' + pa.y + '" x2="' + pb.x + '" y2="' + pb.y + '" stroke="' + (gw ? '#f59e0b' : '#3a4a63') + '" stroke-width="' + (gw ? 2 : 1.1) + '"><title>' + esc(title) + '</title></line>';
      }).join('');
      var nodeSvg = nodes.map(function (n, i) {
        var p = pos(i);
        var nm = n.name.length > 20 ? n.name.slice(0, 19) + '…' : n.name;
        var ty = p.y < cy ? p.y - 11 : p.y + 18;
        return '<g><circle cx="' + p.x + '" cy="' + p.y + '" r="6" fill="#0c2c3f" stroke="#0ea5e9" stroke-width="1.5"/>' +
          '<text x="' + p.x + '" y="' + ty + '" text-anchor="middle" font-family="Segoe UI, system-ui, sans-serif" font-size="11" fill="#cbd5e1">' + esc(nm) + '</text>' +
          '<title>' + esc(n.name + (n.sub ? ' · ' + n.sub : '')) + '</title></g>';
      }).join('');
      wrap.innerHTML = '<svg id="vnet-graph-svg" data-size="' + size + '" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + size + ' ' + size + '" width="' + size + '" height="' + size + '">' + edgeSvg + nodeSvg + '</svg>';
      applyZoom();
    }
    function bind(id, fn) { var b = document.getElementById(id); if (b) b.onclick = fn; }
    bind('vnet-zoom-in', function () { scale = Math.min(3, +(scale + 0.2).toFixed(2)); applyZoom(); });
    bind('vnet-zoom-out', function () { scale = Math.max(0.3, +(scale - 0.2).toFixed(2)); applyZoom(); });
    bind('vnet-zoom-reset', function () { scale = 1; applyZoom(); });
    bind('vnet-download', function () { var svg = document.getElementById('vnet-graph-svg'); if (svg) { var sz = +svg.getAttribute('data-size'); aerDownloadPng(svg, sz, sz, 'vnet-peering-diagram.png'); } });

    /* drag-to-pan */
    (function () {
      var down = false, sx, sy, sl, st;
      wrap.addEventListener('mousedown', function (e) {
        if (e.button !== 0) return;
        down = true; wrap.classList.add('panning');
        sx = e.clientX; sy = e.clientY; sl = wrap.scrollLeft; st = wrap.scrollTop; e.preventDefault();
      });
      window.addEventListener('mousemove', function (e) {
        if (!down) return;
        wrap.scrollLeft = sl - (e.clientX - sx); wrap.scrollTop = st - (e.clientY - sy);
      });
      window.addEventListener('mouseup', function () { if (down) { down = false; wrap.classList.remove('panning'); } });
    })();

    function renderTags() {
      var tagsEl = document.getElementById('vnet-filter-tags');
      if (!tagsEl) return;
      var parts = [];
      if (selSub.size) parts.push('Sub: ' + selSub.size);
      if (selRg.size) parts.push('RG: ' + selRg.size);
      if (selVnet.size) parts.push('VNet: ' + selVnet.size);
      tagsEl.innerHTML = parts.length
        ? parts.map(function (p) { return '<span class="filter-tag">' + esc(p) + '</span>'; }).join('') + '<button class="filter-clear-all" id="vnet-clear-all">Clear all</button>'
        : '';
      var c = document.getElementById('vnet-clear-all');
      if (c) c.addEventListener('click', function () {
        selSub.clear(); selRg.clear(); selVnet.clear();
        ['vnet-f-sub', 'vnet-f-rg', 'vnet-f-vnet'].forEach(function (id) { var b = document.getElementById(id); if (b) b.classList.remove('active'); });
        renderTags(); draw();
      });
    }
    function setupFilter(btnId, key, sel) {
      var btn = document.getElementById(btnId);
      if (!btn) return;
      var values = gDistinct(key);
      var dd = el('div', 'filter-dropdown'); document.body.appendChild(dd);
      function refreshBtn() { btn.classList.toggle('active', sel.size > 0); }
      /* Build shell once; repaint only the list on input so the search box keeps focus. */
      dd.innerHTML = '<div class="filter-dd-search"><input type="text" placeholder="Search..." class="gq"/></div>' +
        '<div class="filter-dd-actions"><button class="filter-dd-action" data-a="all">Select all</button><button class="filter-dd-action" data-a="clear">Clear</button></div>' +
        '<div class="filter-dd-list"></div>';
      var listEl = dd.querySelector('.filter-dd-list');
      var sq = dd.querySelector('.gq');
      function paintList() {
        var q = (sq.value || '').toLowerCase();
        var shown = values.filter(function (v) { return v.toLowerCase().indexOf(q) !== -1; });
        listEl.innerHTML = shown.length ? shown.map(function (v) {
          return '<label class="filter-dd-item"><input type="checkbox" value="' + esc(v) + '" ' + (sel.has(v) ? 'checked' : '') + '/><span class="filter-dd-item-label" title="' + esc(v) + '">' + esc(v) + '</span></label>';
        }).join('') : '<div class="filter-dd-empty">No matches</div>';
        listEl.querySelectorAll('input[type=checkbox]').forEach(function (cb) {
          cb.addEventListener('change', function () { if (cb.checked) sel.add(cb.value); else sel.delete(cb.value); refreshBtn(); renderTags(); draw(); });
        });
      }
      sq.addEventListener('input', paintList);
      dd.querySelector('[data-a="all"]').addEventListener('click', function () {
        var q = (sq.value || '').toLowerCase();
        values.filter(function (v) { return v.toLowerCase().indexOf(q) !== -1; }).forEach(function (v) { sel.add(v); });
        refreshBtn(); renderTags(); draw(); paintList();
      });
      dd.querySelector('[data-a="clear"]').addEventListener('click', function () { sel.clear(); refreshBtn(); renderTags(); draw(); paintList(); });
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (dd.classList.contains('open')) { dd.classList.remove('open'); return; }
        paintList();
        var rr = btn.getBoundingClientRect();
        dd.style.top = (rr.bottom + window.scrollY + 4) + 'px';
        var left = rr.left + window.scrollX; if (left + 240 > window.innerWidth) left = window.innerWidth - 250;
        dd.style.left = Math.max(8, left) + 'px';
        dd.classList.add('open'); sq.focus();
      });
      document.addEventListener('click', function (e) { if (dd.classList.contains('open') && !dd.contains(e.target) && e.target !== btn) dd.classList.remove('open'); });
    }
    setupFilter('vnet-f-sub', 'sub', selSub);
    setupFilter('vnet-f-rg', 'rg', selRg);
    setupFilter('vnet-f-vnet', 'name', selVnet);
    renderTags();
    draw();
  })();

  /* ════════════════════════════ LOAD BALANCERS ══════════════════════ */
  var lb = d.loadBalancers || {};
  var lbc = lb.Counts || {};
  setHeader('lb-header', '⚖️', 'Load Balancers',
    'Load balancing resources and the applications behind them, across all scanned subscriptions',
    '<span class="chip blue">' + fmt(lb.Total || 0) + ' balancers</span>');
  var lbTiles = document.getElementById('lb-tiles');
  if (lbTiles) {
    [
      { icon: '⚖️', label: 'Load Balancer (ALB)', value: lbc.LoadBalancer || 0 },
      { icon: '🚦', label: 'App Gateway (AGW)',    value: lbc.AppGateway || 0 },
      { icon: '🚪', label: 'Front Door (AFD)',     value: lbc.FrontDoor || 0 },
      { icon: '🗺️', label: 'Traffic Manager',      value: lbc.TrafficManager || 0 },
      { icon: '⚖️', label: 'Total',                value: lb.Total || 0 }
    ].forEach(function (t) {
      lbTiles.appendChild(el('div', 'stat-tile',
        '<div class="stat-tile-label">' + t.icon + ' ' + t.label + '</div>' +
        '<div class="stat-tile-value">' + fmt(t.value) + '</div>'));
    });
  }

  initDataTable({
    ids: { thead:'lb-thead', tbody:'lb-tbody', colgroup:'lb-colgroup',
           pager:'lb-pager', tags:'lb-active-filters', search:'lb-global-search' },
    pageSize: 15,
    emptyText: 'No load balancers match the current filters.',
    data: toArr(lb.Balancers).map(function (r) {
      return {
        subscription: r.SubscriptionName || '—',
        rg:           r.ResourceGroup || '—',
        name:         r.Name || '—',
        type:         r.Type || '—',
        id:           r.Id || '',
        endpoints:    toArr(r.Endpoints),
        tags:         r.Tags || null
      };
    }),
    columns: [
      { key:'subscription', label:'Subscription',   width:180 },
      { key:'rg',           label:'Resource Group', width:170 },
      { key:'name',         label:'Resource',       width:190 },
      { key:'type',         label:'Type',           width:210 },
      { key:'_actions',     label:'',               width:110, noFilter:true, render:function (r) { return portalLink(r.id); } }
    ],
    detail: function (row) {
      var eps = toArr(row.endpoints);
      var epHtml = eps.length
        ? '<div class="table-scroll"><table class="aer-table simple"><thead><tr><th>Endpoint</th><th>Group / origin</th><th>Protocol</th><th>Frontend port</th><th>Backend port</th><th>Health</th><th>Servers / origins</th></tr></thead><tbody>' +
          eps.map(function (e) {
            var servers = toArr(e.Servers);
            var sv = servers.length ? servers.map(function (s) { return esc(s); }).join('<br>') : '<span class="cell-muted">—</span>';
            return '<tr><td>' + esc(e.Name || '—') + '</td><td>' + esc(e.Group || '—') + '</td><td>' + esc(e.Protocol || '—') + '</td><td>' + esc(e.FrontendPort || '—') + '</td><td>' + esc(e.BackendPort || '—') + '</td><td>' + healthPill(e.Health) + '</td><td style="white-space:normal">' + sv + '</td></tr>';
          }).join('') + '</tbody></table></div>'
        : '<span class="tags-empty">No endpoints / backends found</span>';
      return '<div class="res-detail">' +
        '<div class="res-detail-section"><div class="res-detail-label">Endpoints &amp; backends (' + eps.length + ')</div>' + epHtml + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Resource ID</div>' + idBlock(row.id) + '</div>' +
        '<div class="res-detail-section"><div class="res-detail-label">Tags</div><div class="res-tags">' + tagsHtml(row.tags) + '</div></div>' +
      '</div>';
    }
  });
})();
'@
}
