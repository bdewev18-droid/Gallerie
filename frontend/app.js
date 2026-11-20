// Application State
const state = {
  activeTab: 'albums', // 'albums' | 'years'
  albums: [],
  years: [],
  selectedAlbum: null,
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
const tabAlbumsBtn = document.getElementById('tabAlbumsBtn');
const tabYearsBtn = document.getElementById('tabYearsBtn');
const sidebarList = document.getElementById('sidebarList');
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
const metaCamera = document.getElementById('metaCamera');
const metaDimSize = document.getElementById('metaDimSize');
const metaPath = document.getElementById('metaPath');
const metaAlbums = document.getElementById('metaAlbums');

// Initialize
async function init() {
  lucide.createIcons();
  setupEventListeners();
  await loadNavigation();
  await loadPhotos();
}

// Event Listeners
function setupEventListeners() {
  tabAlbumsBtn.addEventListener('click', () => switchTab('albums'));
  tabYearsBtn.addEventListener('click', () => switchTab('years'));

  // Debounced search
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

  // Lightbox
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
  if (tab === 'albums') {
    tabAlbumsBtn.className = "flex-1 py-1.5 text-xs font-semibold rounded-md transition text-brand-400 bg-slate-800 flex items-center justify-center gap-1.5";
    tabYearsBtn.className = "flex-1 py-1.5 text-xs font-medium rounded-md transition text-slate-400 hover:text-slate-200 flex items-center justify-center gap-1.5";
    renderAlbumsList();
  } else {
    tabYearsBtn.className = "flex-1 py-1.5 text-xs font-semibold rounded-md transition text-brand-400 bg-slate-800 flex items-center justify-center gap-1.5";
    tabAlbumsBtn.className = "flex-1 py-1.5 text-xs font-medium rounded-md transition text-slate-400 hover:text-slate-200 flex items-center justify-center gap-1.5";
    renderYearsList();
  }
}

async function loadNavigation() {
  try {
    const res = await fetch('/api/navigation');
    const data = await res.json();
    state.albums = data.albums;
    state.years = data.years;
    state.totalPhotos = data.total_photos;
    headerTotalPhotos.textContent = data.total_photos.toLocaleString('fr-FR');
    renderAlbumsList();
  } catch (err) {
    console.error('Failed to load navigation', err);
  }
}

function renderAlbumsList() {
  sidebarList.innerHTML = '';
  
  // All Photos item
  const allItem = createSidebarItem('Toutes les photos', state.totalPhotos, !state.selectedAlbum && !state.selectedYear, () => {
    resetFilters();
    loadPhotos();
  }, 'images');
  sidebarList.appendChild(allItem);

  // Albums
  state.albums.forEach(alb => {
    const isActive = state.selectedAlbum && state.selectedAlbum.id === alb.id;
    const item = createSidebarItem(alb.name, alb.count, isActive, () => {
      state.selectedAlbum = alb;
      state.selectedYear = null;
      state.selectedDate = null;
      state.page = 1;
      updateFilterUI();
      loadPhotos();
    }, 'bookmark');
    sidebarList.appendChild(item);
  });
  lucide.createIcons();
}

function renderYearsList() {
  sidebarList.innerHTML = '';

  const allItem = createSidebarItem('Toutes les photos', state.totalPhotos, !state.selectedAlbum && !state.selectedYear, () => {
    resetFilters();
    loadPhotos();
  }, 'images');
  sidebarList.appendChild(allItem);

  state.years.forEach(y => {
    const isActive = state.selectedYear === y.year && !state.selectedDate;
    const item = createSidebarItem(y.year === 'unknown_date' ? 'Sans date' : y.year, y.count, isActive, () => {
      state.selectedYear = y.year;
      state.selectedAlbum = null;
      state.selectedDate = null;
      state.page = 1;
      updateFilterUI();
      loadPhotos();
    }, 'calendar');
    sidebarList.appendChild(item);
  });
  lucide.createIcons();
}

function createSidebarItem(label, count, isActive, onClick, iconName) {
  const div = document.createElement('div');
  div.className = `flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer transition select-none group ${
    isActive 
      ? 'bg-brand-500/15 text-brand-400 font-semibold border border-brand-500/20' 
      : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'
  }`;
  
  div.innerHTML = `
    <div class="flex items-center gap-2 truncate pr-2">
      <i data-lucide="${iconName}" class="w-3.5 h-3.5 shrink-0 opacity-70"></i>
      <span class="truncate text-xs">${label}</span>
    </div>
    <span class="text-[11px] font-mono px-1.5 py-0.5 rounded ${isActive ? 'bg-brand-500/20 text-brand-300' : 'bg-slate-800 text-slate-400'}">${count}</span>
  `;

  div.addEventListener('click', onClick);
  return div;
}

function updateFilterUI() {
  let title = 'Toutes les photos';
  let badgeText = '';

  if (state.searchQuery) {
    title = `Recherche : "${state.searchQuery}"`;
    badgeText = `Recherche: ${state.searchQuery}`;
  } else if (state.selectedAlbum) {
    title = state.selectedAlbum.name;
    badgeText = `Album: ${state.selectedAlbum.name}`;
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

  // Refresh active sidebar highlighting
  if (state.activeTab === 'albums') renderAlbumsList();
  else renderYearsList();
}

function resetFilters() {
  state.selectedAlbum = null;
  state.selectedYear = null;
  state.selectedDate = null;
  state.searchQuery = '';
  searchInput.value = '';
  clearSearchBtn.classList.add('hidden');
  state.page = 1;
  updateFilterUI();
}

async function loadPhotos() {
  photosGrid.innerHTML = `
    <div class="col-span-full py-16 flex flex-col items-center justify-center text-slate-400">
      <div class="w-8 h-8 border-2 border-brand-500 border-t-transparent rounded-full animate-spin mb-3"></div>
      <p class="text-xs">Chargement des photos...</p>
    </div>
  `;

  const params = new URLSearchParams({
    page: state.page,
    limit: state.limit
  });

  if (state.searchQuery) params.append('q', state.searchQuery);
  if (state.selectedAlbum) params.append('album_id', state.selectedAlbum.id);
  if (state.selectedYear) params.append('year', state.selectedYear);
  if (state.selectedDate) params.append('date_folder', state.selectedDate);

  try {
    const res = await fetch(`/api/photos?${params.toString()}`);
    const data = await res.json();
    
    state.photos = data.items;
    state.totalPages = data.pages;
    galleryCount.textContent = `${data.total.toLocaleString('fr-FR')} photos`;

    // Pagination
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
    
    card.innerHTML = `
      <img src="${photo.thumbnail_url}" alt="${photo.filename}" loading="lazy"
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
  lightboxDriveBtn.href = state.gdriveBaseUrl;

  lightboxModal.classList.remove('hidden');

  // Load detailed metadata
  try {
    const res = await fetch(`/api/photos/${photo.id}`);
    const details = await res.json();
    
    metaFilename.textContent = details.filename;
    metaDate.textContent = details.capture_date || 'Non renseignée';
    metaCamera.textContent = details.camera_model ? `${details.camera_make || ''} ${details.camera_model}` : 'Non renseigné';
    metaDimSize.textContent = `${details.width || '?'} × ${details.height || '?'} px (${formatBytes(details.file_size)})`;
    metaPath.textContent = details.rel_path;

    metaAlbums.innerHTML = '';
    if (details.albums && details.albums.length > 0) {
      details.albums.forEach(alb => {
        const badge = document.createElement('span');
        badge.className = "px-2 py-0.5 rounded bg-brand-500/20 text-brand-300 border border-brand-500/30 text-[10px] font-medium";
        badge.textContent = alb.name;
        metaAlbums.appendChild(badge);
      });
    } else {
      metaAlbums.innerHTML = `<span class="text-slate-500 italic">Aucun album spécifique</span>`;
    }
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

// Run
document.addEventListener('DOMContentLoaded', init);
