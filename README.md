# 📸 Lightroom Gallery & Google Drive Explorer

Une application web moderne, ultra-légère et rapide pour explorer, filtrer et rechercher dans votre bibliothèque de **25 221 photos**, en conservant tous vos **527 albums Lightroom**, votre classement par dates/années et la liaison directe vers vos fichiers HD sur **Google Drive**.

---

## 🚀 Fonctionnalités clés

* **Poids plume pour Git (< 5 Mo)** : Le code source est complètement séparé des 150 Go de photos HD et des vignettes (grâce au `.gitignore`).
* **527 Albums Lightroom reconstitués** : Récupération automatique de tous vos albums d'origine (Voyages, Vacances, Best Of, Événements de famille...).
* **Classement par Années & Dates** : Exploration chronologique de 2005 à 2026.
* **Moteur de recherche instantané** : Recherche ultra-rapide par mot-clé, nom d'album, date ou appareil photo via SQLite FTS5 (< 2 ms).
* **Smart Previews (Vignettes WebP)** : Affichage instantané en grille avec des vignettes générées à la volée ou en tâche de fond.
* **Intégration Google Drive HD** : Accès direct en un clic au dossier Google Drive partagé pour voir ou télécharger l'original en pleine résolution.

---

## 📁 Architecture du projet

```text
d:\LRforIA\
├── backend/
│   ├── database.py         # Schéma SQLite, migrations et index FTS5
│   ├── indexer.py          # Extraction Lightroom et indexation des photos
│   ├── thumbnails.py       # Génération parallèle des vignettes WebP
│   └── main.py             # API REST FastAPI et serveur statique
├── frontend/
│   ├── index.html          # Interface utilisateur moderne (Dark mode)
│   ├── app.js              # Logique interactive, grille, recherche et lightbox
│   └── placeholder.svg     # Vignette par défaut (vidéos / chargement)
├── data/
│   ├── photos.db           # Base SQLite contenant les métadonnées (~15 Mo)
│   └── thumbnails/         # Cache des aperçus WebP (Smart Previews)
├── scripts/
│   └── start_server.bat    # Lanceur 1-clic du serveur web
└── .gitignore              # Ignore les 150 Go de photos, la base et le cache
```

---

## ⚡ Démarrage rapide

### 1. Lancer l'application
Double-cliquez sur `scripts/start_server.bat` ou lancez dans le terminal :
```bash
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```
Ouvrez votre navigateur sur : **[http://localhost:8000](http://localhost:8000)**

### 2. Mettre sur GitHub / Git
Le fichier `.gitignore` est déjà configuré pour ne garder que le code source :
```bash
git init
git add .
git commit -m "Initial commit: Lightroom Gallery & Drive Explorer"
git remote add origin https://github.com/VOTRE_COMPTE/VOTRE_DEPOT.git
git push -u origin main
```
Le dépôt fera **moins de 5 Mo**.
