// Application State - Medias Familly
const state = {
  activeTab: 'thematics', // 'thematics' | 'years'
  nodes: [],
  nodesById: {},
  childrenByParent: {},
  expandedFolders: new Set(),
  years: [],
  selectedNode: null, // current active thematic folder or album
  breadcrumbTrail: [], // array of node objects
  selectedYear: null,
  selectedDate: null,
  searchQuery: '',
  page: 1,
  limit: 60,
  totalPages: 1,
  totalPhotos: 0,
  photos: [],
  lightboxIndex: -1,
  gdriveBaseUrl: 'https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO'
};

// DOM Elements
const searchInput = document.getElementById('searchInput');
const clearSearchBtn = document.getElementById('clearSearchBtn');
const tabThematicsBtn = document.getElementById('tabThematicsBtn');
const tabYearsBtn = document.getElementById('tabYearsBtn');
const sidebarList = document.getElementById('sidebarList');
const breadcrumbBar = document.getElementById('breadcrumbBar');
const galleryTitle = document.getElementById('galleryTitle');
const galleryCount = document.getElementById('galleryCount');
const activeFilterBadge = document.getElementById('activeFilterBadge');
const filterLabel = document.getElementById('filterLabel');
const removeFilterBtn = document.getElementById('removeFilterBtn');
const photosGrid = document.getElementById('photosGrid');
const emptyState = document.getElementById('emptyState');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const pageIndicator = document.getElementById('pageIndicator');
const headerTotalPhotos = document.getElementById('headerTotalPhotos');

// Lightbox Elements
const lightboxModal = document.getElementById('lightboxModal');
const closeLightboxBtn = document.getElementById('closeLightboxBtn');
const lightboxImg = document.getElementById('lightboxImg');
const lightboxCaption = document.getElementById('lightboxCaption');
const lightboxPrevBtn = document.getElementById('lightboxPrevBtn');
const lightboxNextBtn = document.getElementById('lightboxNextBtn');
const lightboxDriveBtn = document.getElementById('lightboxDriveBtn');
const metaFilename = document.getElementById('metaFilename');
const metaDate = document.getElementById('metaDate');
const metaDimSize = document.getElementById('metaDimSize');
const metaDriveStatus = document.getElementById('metaDriveStatus');
const metaPath = document.getElementById('metaPath');
const metaAlbums = document.getElementById('metaAlbums');

// Initialize
async function init() {
  lucide.createIcons();
  setupEventListeners();
  await loadThematics();
  await loadYears();
  updateBreadcrumbs();
  await loadPhotos();
}

function setupEventListeners() {
  tabThematicsBtn.addEventListener('click', () => switchTab('thematics'));
  tabYearsBtn.addEventListener('click', () => switchTab('years'));

  let searchTimeout = null;
  searchInput.addEventListener('input', (e) => {
    const val = e.target.value.trim();
    clearSearchBtn.classList.toggle('hidden', !val);
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      state.searchQuery = val;
      state.page = 1;
      updateFilterUI();
      loadPhotos();
    }, 300);
  });

  clearSearchBtn.addEventListener('click', () => {
    searchInput.value = '';
    clearSearchBtn.classList.add('hidden');
    state.searchQuery = '';
    state.page = 1;
    updateFilterUI();
    loadPhotos();
  });

  removeFilterBtn.addEventListener('click', () => {
    resetFilters();
    loadPhotos();
  });

  prevPageBtn.addEventListener('click', () => {
    if (state.page > 1) {
      state.page--;
      loadPhotos();
      document.getElementById('galleryContainer').scrollTo({ top: 0, behavior: 'smooth' });
    }
  });

  nextPageBtn.addEventListener('click', () => {
    if (state.page < state.totalPages) {
      state.page++;
      loadPhotos();
      document.getElementById('galleryContainer').scrollTo({ top: 0, behavior: 'smooth' });
    }
  });

  closeLightboxBtn.addEventListener('click', closeLightbox);
  lightboxPrevBtn.addEventListener('click', () => navigateLightbox(-1));
  lightboxNextBtn.addEventListener('click', () => navigateLightbox(1));

  window.addEventListener('keydown', (e) => {
    if (state.lightboxIndex >= 0) {
      if (e.key === 'Escape') closeLightbox();
      if (e.key === 'ArrowLeft') navigateLightbox(-1);
      if (e.key === 'ArrowRight') navigateLightbox(1);
    }
  });
}

function switchTab(tab) {
  state.activeTab = tab;
  if (tab === 'thematics') {
    tabThematicsBtn.className = "flex-1 py-1.5 text-xs font-semibold rounded-md transition text-brand-400 bg-slate-800 flex items-center justify-center gap-1.5";
    tabYearsBtn.className = "flex-1 py-1.5 text-xs font-medium rounded-md transition text-slate-400 hover:text-slate-200 flex items-center justify-center gap-1.5";
    renderThematicsTree();
  } else {
    tabYearsBtn.className = "flex-1 py-1.5 text-xs font-semibold rounded-md transition text-brand-400 bg-slate-800 flex items-center justify-center gap-1.5";
    tabThematicsBtn.className = "flex-1 py-1.5 text-xs font-medium rounded-md transition text-slate-400 hover:text-slate-200 flex items-center justify-center gap-1.5";
    renderYearsList();
  }
}

async function loadThematics() {
  try {
    const res = await fetch('/api/thematics');
    const data = await res.json();
    state.nodes = data.nodes;
    state.totalPhotos = data.total_photos;
    headerTotalPhotos.textContent = data.total_photos.toLocaleString('fr-FR');
    
    state.nodesById = {};
    state.childrenByParent = {};
    data.nodes.forEach(n => {
      state.nodesById[n.id] = n;
      const pid = n.parent_id || null;
      if (!state.childrenByParent[pid]) state.childrenByParent[pid] = [];
      state.childrenByParent[pid].push(n);
    });

    // Auto-expand main root folders initially
    const roots = state.childrenByParent[null] || [];
    roots.forEach(r => state.expandedFolders.add(r.id));

    renderThematicsTree();
  } catch (err) {
    console.error('Failed to load thematics', err);
  }
}

async function loadYears() {
  try {
    const res = await fetch('/api/years');
    const data = await res.json();
    state.years = data.years;
  } catch (err) {
    console.error('Failed to load years', err);
  }
}

// Hierarchical Tree Renderer
function renderThematicsTree() {
  sidebarList.innerHTML = '';

  // All Photos item
  const allItem = createSidebarRow({
    id: null,
    name: 'Toutes les photos',
    count: state.totalPhotos,
    isFolder: false,
    level: 0,
    hasChildren: false,
    isExpanded: false,
    isSelected: !state.selectedNode && !state.selectedYear,
    onSelect: () => {
      resetFilters();
      loadPhotos();
    }
  });
  sidebarList.appendChild(allItem);

  const roots = state.childrenByParent[null] || [];
  roots.forEach(root => renderNodeAndChildren(root, 0));

  lucide.createIcons();
}

function renderNodeAndChildren(node, level) {
  const children = state.childrenByParent[node.id] || [];
  const hasChildren = children.length > 0;
  const isExpanded = state.expandedFolders.has(node.id);
  const isSelected = state.selectedNode && state.selectedNode.id === node.id;

  const row = createSidebarRow({
    id: node.id,
    name: node.name,
    count: node.total_count || node.direct_count,
    isFolder: Boolean(node.is_folder),
    level: level,
    hasChildren: hasChildren,
    isExpanded: isExpanded,
    isSelected: isSelected,
    onToggleExpand: () => {
      if (isExpanded) state.expandedFolders.delete(node.id);
      else state.expandedFolders.add(node.id);
      renderThematicsTree();
    },
    onSelect: () => {
      selectThematicNode(node);
    }
  });
  sidebarList.appendChild(row);

  if (hasChildren && isExpanded) {
    children.forEach(child => renderNodeAndChildren(child, level + 1));
  }
}

function createSidebarRow(opts) {
  const div = document.createElement('div');
  const indentPx = opts.level * 14;
  div.className = `flex items-center justify-between px-2.5 py-1.5 rounded-lg cursor-pointer transition select-none group ${
    opts.isSelected 
      ? 'bg-sky-500/20 text-sky-400 font-semibold border border-sky-500/30' 
      : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'
  }`;
  div.style.paddingLeft = `${Math.max(10, indentPx + 8)}px`;

  let toggleBtn = '<span class="w-4 inline-block"></span>';
  if (opts.hasChildren) {
    toggleBtn = `
      <button class="w-4 h-4 flex items-center justify-center text-slate-400 hover:text-white shrink-0 mr-1 p-0.5 rounded toggle-folder">
        <i data-lucide="${opts.isExpanded ? 'chevron-down' : 'chevron-right'}" class="w-3.5 h-3.5"></i>
      </button>
    `;
  }

  const iconName = opts.isFolder ? 'folder' : (opts.id === null ? 'images' : 'bookmark');
  const iconColor = opts.isFolder ? 'text-amber-400' : 'text-sky-400';

  div.innerHTML = `
    <div class="flex items-center gap-1.5 truncate pr-1">
      ${toggleBtn}
      <i data-lucide="${iconName}" class="w-3.5 h-3.5 shrink-0 ${iconColor}"></i>
      <span class="truncate text-xs">${opts.name}</span>
    </div>
    <span class="text-[10px] font-mono px-1.5 py-0.5 rounded shrink-0 ${opts.isSelected ? 'bg-sky-500/20 text-sky-300' : 'bg-slate-800 text-slate-400'}">${opts.count}</span>
  `;

  // Toggle arrow click
  const arrowBtn = div.querySelector('.toggle-folder');
  if (arrowBtn) {
    arrowBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      opts.onToggleExpand();
    });
  }

  // Row select
  div.addEventListener('click', opts.onSelect);
  return div;
}

function selectThematicNode(node) {
  state.selectedNode = node;
  state.selectedYear = null;
  state.selectedDate = null;
  state.page = 1;

  // Build breadcrumb trail
  const trail = [node];
  let curr = node.parent_id ? state.nodesById[node.parent_id] : null;
  while (curr) {
    trail.unshift(curr);
    curr = curr.parent_id ? state.nodesById[curr.parent_id] : null;
  }
  state.breadcrumbTrail = trail;

  // Auto-expand this node and all ancestors
  trail.forEach(n => state.expandedFolders.add(n.id));

  updateFilterUI();
  updateBreadcrumbs();
  loadPhotos();
}

function renderYearsList() {
  sidebarList.innerHTML = '';

  const allItem = createSidebarRow({
    id: null,
    name: 'Toutes les photos',
    count: state.totalPhotos,
    isFolder: false,
    level: 0,
    hasChildren: false,
    isExpanded: false,
    isSelected: !state.selectedNode && !state.selectedYear,
    onSelect: () => {
      resetFilters();
      loadPhotos();
    }
  });
  sidebarList.appendChild(allItem);

  state.years.forEach(y => {
    const isSelected = state.selectedYear === y.year && !state.selectedDate;
    const div = document.createElement('div');
    div.className = `flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer transition select-none ${
      isSelected 
        ? 'bg-sky-500/20 text-sky-400 font-semibold border border-sky-500/30' 
        : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'
    }`;
    
    div.innerHTML = `
      <div class="flex items-center gap-2 truncate pr-2">
        <i data-lucide="calendar" class="w-3.5 h-3.5 shrink-0 text-sky-400"></i>
        <span class="truncate text-xs">${y.year === 'unknown_date' ? 'Sans date' : 'Année ' + y.year}</span>
      </div>
      <span class="text-[11px] font-mono px-1.5 py-0.5 rounded ${isSelected ? 'bg-sky-500/20 text-sky-300' : 'bg-slate-800 text-slate-400'}">${y.count}</span>
    `;

    div.addEventListener('click', () => {
      state.selectedYear = y.year;
      state.selectedNode = null;
      state.selectedDate = null;
      state.page = 1;
      state.breadcrumbTrail = [{ name: `Année ${y.year}` }];
      updateFilterUI();
      updateBreadcrumbs();
      loadPhotos();
    });
    sidebarList.appendChild(div);
  });
  lucide.createIcons();
}

function updateBreadcrumbs() {
  breadcrumbBar.innerHTML = '';

  const rootBtn = document.createElement('button');
  rootBtn.className = "flex items-center gap-1 text-slate-400 hover:text-sky-400 font-medium transition";
  rootBtn.innerHTML = `<i data-lucide="home" class="w-3 h-3"></i><span>Medias Familly</span>`;
  rootBtn.addEventListener('click', () => {
    resetFilters();
    loadPhotos();
  });
  breadcrumbBar.appendChild(rootBtn);

  if (state.breadcrumbTrail && state.breadcrumbTrail.length > 0) {
    state.breadcrumbTrail.forEach((crumb, idx) => {
      const sep = document.createElement('span');
      sep.className = "text-slate-600";
      sep.textContent = "/";
      breadcrumbBar.appendChild(sep);

      const isLast = idx === state.breadcrumbTrail.length - 1;
      const crumbBtn = document.createElement('button');
      crumbBtn.className = `truncate max-w-[200px] ${isLast ? 'text-sky-400 font-bold' : 'text-slate-400 hover:text-slate-200'}`;
      crumbBtn.textContent = crumb.name;
      if (!isLast && crumb.id) {
        crumbBtn.addEventListener('click', () => selectThematicNode(crumb));
      }
      breadcrumbBar.appendChild(crumbBtn);
    });
  }
  lucide.createIcons();
}

function updateFilterUI() {
  let title = 'Toutes les photos';
  let badgeText = '';

  if (state.searchQuery) {
    title = `Recherche : "${state.searchQuery}"`;
    badgeText = `Recherche: ${state.searchQuery}`;
  } else if (state.selectedNode) {
    title = state.selectedNode.name;
    badgeText = state.selectedNode.name;
  } else if (state.selectedYear) {
    title = state.selectedYear === 'unknown_date' ? 'Photos sans date' : `Année ${state.selectedYear}`;
    badgeText = `Année: ${state.selectedYear}`;
  }

  galleryTitle.textContent = title;

  if (badgeText) {
    filterLabel.textContent = badgeText;
    activeFilterBadge.classList.remove('hidden');
  } else {
    activeFilterBadge.classList.add('hidden');
  }

  if (state.activeTab === 'thematics') renderThematicsTree();
  else renderYearsList();
}

function resetFilters() {
  state.selectedNode = null;
  state.selectedYear = null;
  state.selectedDate = null;
  state.breadcrumbTrail = [];
  state.searchQuery = '';
  searchInput.value = '';
  clearSearchBtn.classList.add('hidden');
  state.page = 1;
  updateFilterUI();
  updateBreadcrumbs();
}

async function loadPhotos() {
  photosGrid.innerHTML = `
    <div class="col-span-full py-16 flex flex-col items-center justify-center text-slate-400">
      <div class="w-8 h-8 border-2 border-sky-500 border-t-transparent rounded-full animate-spin mb-3"></div>
      <p class="text-xs">Chargement des photos...</p>
    </div>
  `;

  const params = new URLSearchParams({
    page: state.page,
    limit: state.limit
  });

  if (state.searchQuery) params.append('q', state.searchQuery);
  if (state.selectedNode) params.append('album_id', state.selectedNode.id);
  if (state.selectedYear) params.append('year', state.selectedYear);
  if (state.selectedDate) params.append('date_folder', state.selectedDate);

  try {
    const res = await fetch(`/api/photos?${params.toString()}`);
    const data = await res.json();
    
    state.photos = data.items;
    state.totalPages = data.pages;
    galleryCount.textContent = `${data.total.toLocaleString('fr-FR')} photos`;

    pageIndicator.textContent = `Page ${state.page} / ${data.pages || 1}`;
    prevPageBtn.disabled = state.page <= 1;
    nextPageBtn.disabled = state.page >= data.pages;

    renderPhotosGrid();
  } catch (err) {
    console.error('Failed to load photos', err);
    photosGrid.innerHTML = `<div class="col-span-full text-center py-12 text-red-400 text-sm">Erreur lors du chargement des photos.</div>`;
  }
}

function renderPhotosGrid() {
  photosGrid.innerHTML = '';
  emptyState.classList.toggle('hidden', state.photos.length > 0);

  state.photos.forEach((photo, idx) => {
    const card = document.createElement('div');
    card.className = "photo-card group relative aspect-square bg-slate-900 border border-slate-800/80 rounded-lg overflow-hidden cursor-pointer shadow";
    
    // Use drive thumbnail or local thumbnail
    const thumbSrc = photo.thumbnail_url;

    card.innerHTML = `
      <img src="${thumbSrc}" alt="${photo.filename}" loading="lazy"
        class="w-full h-full object-cover transition duration-300 group-hover:scale-105"
        onerror="this.src='/static/placeholder.svg'" />
      
      <!-- Overlay Gradient -->
      <div class="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition duration-200 p-2.5 flex flex-col justify-end">
        <p class="text-[11px] font-mono text-white truncate drop-shadow">${photo.filename}</p>
        <p class="text-[10px] text-slate-300 font-mono drop-shadow">${formatDate(photo.capture_date)}</p>
      </div>
    `;

    card.addEventListener('click', () => openLightbox(idx));
    photosGrid.appendChild(card);
  });
}

function formatDate(isoStr) {
  if (!isoStr) return '';
  try {
    const d = new Date(isoStr);
    return isNaN(d.getTime()) ? isoStr.split('T')[0] : d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } catch {
    return isoStr;
  }
}

function formatBytes(bytes) {
  if (!bytes) return '0 o';
  const k = 1024;
  const sizes = ['o', 'Ko', 'Mo', 'Go'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
}

// Lightbox Logic
async function openLightbox(index) {
  state.lightboxIndex = index;
  const photo = state.photos[index];
  if (!photo) return;

  lightboxImg.src = photo.thumbnail_url;
  lightboxCaption.textContent = `${photo.filename} (${index + 1} / ${state.photos.length})`;
  lightboxDriveBtn.href = photo.gdrive_url || state.gdriveBaseUrl;

  lightboxModal.classList.remove('hidden');

  try {
    const res = await fetch(`/api/photos/${photo.id}`);
    const details = await res.json();
    
    metaFilename.textContent = details.filename;
    metaDate.textContent = details.capture_date || 'Non renseignée';
    metaDimSize.textContent = `${details.width || '?'} × ${details.height || '?'} px (${formatBytes(details.file_size)})`;
    metaPath.textContent = details.rel_path;

    if (details.drive_id) {
      metaDriveStatus.innerHTML = `<span class="text-emerald-400 font-semibold flex items-center gap-1"><i data-lucide="check-circle-2" class="w-3.5 h-3.5"></i> Synchronisé sur Drive HD</span>`;
    } else {
      metaDriveStatus.innerHTML = `<span class="text-amber-400 font-semibold flex items-center gap-1"><i data-lucide="clock" class="w-3.5 h-3.5"></i> En cours d'envoi</span>`;
    }

    metaAlbums.innerHTML = '';
    if (details.albums && details.albums.length > 0) {
      details.albums.forEach(alb => {
        const badge = document.createElement('span');
        badge.className = `px-2 py-0.5 rounded text-[10px] font-medium border ${
          alb.is_folder 
            ? 'bg-amber-500/15 text-amber-300 border-amber-500/30' 
            : 'bg-sky-500/15 text-sky-300 border-sky-500/30'
        }`;
        badge.innerHTML = `<i data-lucide="${alb.is_folder ? 'folder' : 'bookmark'}" class="w-2.5 h-2.5 inline mr-1"></i>${alb.name}`;
        metaAlbums.appendChild(badge);
      });
    } else {
      metaAlbums.innerHTML = `<span class="text-slate-500 italic">Aucune thématique</span>`;
    }
    lucide.createIcons();
  } catch (err) {
    console.error('Failed to load photo details', err);
  }
}

function navigateLightbox(step) {
  const newIndex = state.lightboxIndex + step;
  if (newIndex >= 0 && newIndex < state.photos.length) {
    openLightbox(newIndex);
  }
}

function closeLightbox() {
  state.lightboxIndex = -1;
  lightboxModal.classList.add('hidden');
}

document.addEventListener('DOMContentLoaded', init);
