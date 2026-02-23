# DCC Party Tracker

Displays your Dungeon Crawl Classics RPG party. Character data syncs automatically from Fantasy Grounds during a session.

- **fg-characters**: Written by the sync script on the GM's PC. Contains character stats from Fantasy Grounds
- **player-data**: Written by players through the browser. Contains journals, graveyard, quests, notes, etc.
- These two keys can never overwrite each other

## What You Need

- **Windows OS** for GM's PC — the sync script is a PowerShell script that runs on Windows
- **GitHub account** (free) — this stores the website code
- **Cloudflare account** (free) — this hosts the website so everyone can access it

## Project Files

```
dcc-party-tracker/
├── index.html                  ← Web app
├── functions/
│   └── api/
│       ├── fg-characters.js    ← API: character data from Fantasy Grounds
│       └── player-data.js      ← API: player-editable data (journals, etc.)
├── scripts/
│   ├── fg-sync.ps1             ← Watches db.xml and pushes changes
│   └── install-fg-sync.ps1     ← Registers the sync as a background task
├── setup.ps1                   ← Interactive setup wizard (run this first!)
└── README.md
```

---

## Setup Guide

### Part 1: GitHub

#### Step 1: Create/login to your GitHub Account

#### Step 2: Fork This Repository

1. Make sure you are logged in to GitHub
2. At the top of this page, click the **Fork** button
3. On the "Create a new fork" page:
   - **Owner**: should already show your GitHub username
   - **Repository name**: leave as `dcc-party-tracker` (or rename it if you like)
   - Uncheck "Copy the `main` branch only" if it appears
4. Click **Create fork**

---

### Part 2: Deploy the Website to Cloudflare Pages

Cloudflare Pages provides hosting with a URL like `https://dcc-party-tracker.pages.dev`. It also provides a serverless database (KV) where character data is stored.

#### Step 1: Create a Cloudflare Account

#### Step 2: Create a Pages Project
1. After logging in, you should see the Cloudflare dashboard
2. In the left sidebar, click **Workers & Pages**
3. Click the **Create Application** button and click **Looking to deploy Pages? Get started**
4. Click the **Get Started** button within Import an existing Git repository
4. Click **Pages** → **Connect to Git**
5. Cloudflare will ask to connect to your GitHub account:
   - Click **Connect GitHub**
   - A GitHub popup will appear — click **Authorize Cloudflare**
   - If asked which repositories to grant access to, select your `dcc-party-tracker` fork
6. Back in Cloudflare, you should see your `dcc-party-tracker` repository listed. Click **Select** next to it.

#### Step 3: Configure the Build Settings
1. You'll see a configuration page with several fields:
   - **Project name**: `dcc-party-tracker` (this becomes your website URL, so pick something you like)
   - **Production branch**: `main` (should be auto-selected)
   - **Framework preset**: None
   - **Build command**: **leave this completely blank**
   - **Build output directory**: **leave this completely blank** (or type `/`)
2. Click **Save and Deploy**
3. Wait for the deployment — it usually takes under a minute
4. When it says "Success", your site is live!
5. Click the URL shown (something like `https://dcc-party-tracker.pages.dev`) to see your site

> **Bookmark this URL** — this is what you'll share with your players.

#### Step 4: Create a KV Namespace

KV (Key-Value) is a small serverless database from Cloudflare.

1. In the Cloudflare dashboard left sidebar, click **Workers & Pages**
2. In the left sidebar under Workers & Pages, click **KV**
3. Click **Create a namespace**
4. For the name, type: `FG_DATA`
5. Click **Add**

#### Step 5: Connect KV to Your Website

Now you need to tell your website where to find the database. This is called a "binding."

1. In the left sidebar, click **Workers & Pages**
2. Click on your `dcc-party-tracker` project name
3. Click the **Settings** tab at the top
4. Scroll down to **Bindings** (or click **Bindings** in the left sidebar)
5. Click **Add**
6. Select **KV namespace**
7. Fill in:
   - **Variable name**: `FG_DATA` (type this exactly — it's case sensitive)
   - **KV namespace**: select `FG_DATA` from the dropdown
8. Click **Save**

#### Step 6: Redeploy (Important!)

The binding only takes effect after a new deployment. You need to trigger one:

1. Click the **Deployments** tab at the top
2. Find the most recent deployment in the list
3. Click the **three dots (⋯)** menu on the right side of that deployment
4. Click **Retry deployment**
5. Wait for it to finish

#### Step 7: Verify Everything Works

Open your browser and test both of these URLs (replace `dcc-party-tracker` with whatever project name you chose):

1. `https://dcc-party-tracker.pages.dev` — you should see the party viewer web app
2. `https://dcc-party-tracker.pages.dev/api/fg-characters` — you should see: `{"error":"No character data uploaded yet"}`

If both work, the website is ready! If the second URL gives a different error, double-check that the KV binding is set up correctly (Step 5) and that you redeployed (Step 6).

---

### Part 3: Set Up the Sync Script (GM's Windows PC)

This part runs on whichever PC hosts the Fantasy Grounds campaign — that's the GM's computer. The script watches for changes to the campaign file and automatically pushes character data to the website.

#### Step 1: Download the Scripts

You need three files from this repository on your PC:

1. Go to your fork on GitHub (`github.com/YOUR-USERNAME/dcc-party-tracker`)
2. Click the green **Code** button → **Download ZIP**
3. Open the downloaded ZIP and extract it somewhere on your PC
4. Copy these files to a permanent location (they need to stay here):

```
C:\Users\YourName\Documents\fg-sync\
├── setup.ps1                   ← from the project root
├── scripts\
│   ├── fg-sync.ps1             ← from the scripts folder
│   └── install-fg-sync.ps1     ← from the scripts folder
```

> You don't need `index.html` or the `functions/` folder on your PC — those only matter on GitHub/Cloudflare. You just need `setup.ps1` and the `scripts/` folder.

#### Step 2: Allow PowerShell Scripts

Windows blocks PowerShell scripts by default. You need to allow them once:

1. Click the **Start menu** and type `PowerShell`
2. Right-click **Windows PowerShell** and choose **Run as administrator**
3. A blue window will open. Type this command exactly and press Enter:
   ```
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
   ```
4. If it asks "Do you want to change the execution policy?", type `Y` and press Enter
5. Close this PowerShell window

#### Step 3: Run the Setup Wizard

1. Open File Explorer and navigate to where you saved the files (e.g., `C:\Users\YourName\Documents\fg-sync\`)
2. Right-click `setup.ps1` → **Run with PowerShell**
3. The wizard will walk you through everything:
   - It finds your Fantasy Grounds campaigns automatically
   - You pick which campaign to sync (by number)
   - You paste your Cloudflare Pages URL (e.g., `https://dcc-party-tracker.pages.dev`)
   - It tests the connection
   - It shows you which characters it found
   - It offers to install the automatic background task (say yes!)

> **Tip**: If right-click → Run with PowerShell doesn't work, open PowerShell manually, navigate to the folder with `cd C:\Users\YourName\Documents\fg-sync`, and type `.\setup.ps1`

#### Step 4: Test It

1. Open your campaign in Fantasy Grounds
2. Type `/save` in the FG chat window (this forces an immediate save)
3. The sync script should detect the save and push data within seconds
4. Open your site URL in a browser — characters should appear!

If you installed the background task in Step 3, the sync runs automatically whenever you log in to Windows. You don't need to start anything manually — just open Fantasy Grounds and play.

---

### Part 4: Using the Web App

#### For All Players
- Open the site URL in any browser (desktop or mobile)
- Character stats update automatically from Fantasy Grounds
- Use the tabs on each character card to see details (Stats, Combat, Spells, etc.)

#### Player-Editable Features
These are saved to the cloud and shared between all players. Anyone can edit them:
- **Journal**: Session logs and notes
- **Graveyard**: Fallen characters (RIP)
- **Quests**: Active, accomplished, and rumors
- **Player Notes**: Per-character notes
- **Companions**: NPCs traveling with the party
- **Wiki**: Party assets, house rules
- **Portraits**: Upload character images by clicking the portrait area on a character card

#### GM Features
- **Import JSON**: Load a previously saved party backup file
- **Export JSON**: Save the entire party state as a backup file
- **Import XML**: Manually import a single character from a Fantasy Grounds export file (from the `/exportchar` command)

---

## Switching Campaigns

Run `setup.ps1` again and pick a different campaign. It will update the sync script with the new campaign name and site URL.

---

## Running Multiple Campaigns

If you run more than one campaign (or different GMs in your group each run their own), create a **separate Cloudflare Pages project for each campaign**. This keeps everything isolated — different site, different KV storage, no conflicts.

For each additional campaign:

1. Fork this repository again into a new GitHub repo (or create a new repo and upload the project files)
2. Create a new Pages project in Cloudflare with a different name (e.g., `dcc-campaign-2`)
3. Create a new KV namespace (e.g., `FG_DATA_CAMPAIGN2`) and bind it with variable name `FG_DATA`
4. Redeploy the new project
5. Run `setup.ps1` again on the GM's PC and pick the new campaign + new site URL

Each sync script instance watches a different campaign folder and pushes to a different site. They can run simultaneously with no issues.

> **Do not** try to share a single Pages site and KV namespace across multiple campaigns. The storage keys and browser data would collide, causing campaigns to overwrite each other's data.

---

## Technical Notes

- **Cost**: Everything used here is free. Cloudflare's free tier allows 100K reads/day and 1K writes/day — more than enough for a party of 4-6 players.
- **Autosave**: Fantasy Grounds writes db.xml every ~5 minutes during a session, and on session close. The GM can also type `/save` in FG chat for an immediate save.
- **File Safety**: The sync script never writes to db.xml — it only reads. It cannot corrupt your campaign data.
- **Merge Logic**: Player data (journals, quests, graveyard) uses union-merge, so multiple players can edit at the same time without overwriting each other's changes.
