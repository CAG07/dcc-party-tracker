# DCC Party Tracker

Displays your Dungeon Crawl Classics RPG party. Character data syncs automatically from Fantasy Grounds during a session.

- **fg-characters**: Written by the sync script on the GM's PC. Contains character stats from Fantasy Grounds
- **player-data**: Written by players through the browser. Contains journals, graveyard, quests, notes, etc.
- These two keys can never overwrite each other

## What You Need

- **Windows OS** for GM's PC — the sync script is a PowerShell script that runs on Windows
- **GitHub account** (free) — site repo
- **Cloudflare account** (free) — hosting

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
├── run-setup.bat               ← Double-click this to run the setup wizard **Run this first!**
├── run-uninstall.bat           ← Double-click to remove background task
├── setup.ps1                   ← Setup wizard (called by run-setup.bat)
└── README.md
```

---

## Setup Guide

### Part 1: GitHub

#### Step 1: Log in to your GitHub Account

#### Step 2: Fork This Repository

1. Make sure you are logged in to GitHub
2. At the top of this page, click the **Fork** button
3. On the "Create a new fork" page:
   - **Owner**: should already show your GitHub username
   - **Repository name**: leave as `dcc-party-tracker` (or rename it if you like)
4. Click **Create fork**

---

### Part 2: Deploy the Website to Cloudflare Pages

Cloudflare Pages provides hosting with a URL like `https://<your-project-name>.pages.dev`. It also provides a serverless database (KV) where character data is stored.

#### Step 1: Log in to your Cloudflare Account

#### Step 2: Create a Pages Project
1. After logging in, you should see the Cloudflare dashboard
2. In the left sidebar, click **Workers & Pages**
3. Click the **Create Application** button and click **Looking to deploy Pages? Get started**
4. Click the **Get Started** button within Import an existing Git repository
5. Connect to your GitHub account:
   - Click **Connect GitHub**
   - A GitHub popup will appear — click **Authorize Cloudflare**
   - If asked which repositories to grant access to, select **Only Select Repositories** and then select your `dcc-party-tracker` fork
   - Click the **Install & Authorize** button
6. You should see your `dcc-party-tracker` repository listed. Click **Select a repository** and click the **Begin Setup** button. 

#### Step 3: Configure the Build Settings
1. You'll see a configuration page with several fields:
   - **Project name**: `<your-project-name>` (this becomes your website URL, so pick something unique to the campaign, such as the campaign name ex. `my-awesome-campaign`)
     - This must be all lowercase and can include hyphens, but no spaces or special characters
   - **Production branch**: `main` (should be auto-selected)
   - **Framework preset**: None
   - **Build command**: **leave this blank**
   - **Build output directory**: **leave this blank**)
2. Click **Save and Deploy**
3. Wait for the deployment — it usually takes under a minute
4. When it says "Success", your site is live!
5. Click the URL shown (something like `https://<your-project-name>.pages.dev`) to see your site and click the **Continue to project**.

> **Bookmark this URL** — this is what you'll share with your players.

#### Step 4: Create a KV Namespace

KV is a serverless database from Cloudflare.

1. In the Cloudflare dashboard left sidebar, click **Storage & databases** --> **Workers KV**
2. Click **Create instance**
3. For the Namespace name, enter: `<your-project-name>-data` (or something similar that matches your project name)
4. Click **Create**

#### Step 5: Connect KV to Your Website

1. In the left sidebar, click **Workers & Pages**
2. Click on your `<your-project-name>` project name
3. Click the **Settings** tab at the top
4. Scroll down to **Bindings** (or click **Bindings** in the left sidebar)
5. Click **Add**
6. Select **KV namespace**
7. Fill in:
   - **Variable name**: `FG_DATA` (type this exactly — it's case sensitive)
   - **KV namespace**: select your `<your-project-name>-data` namespace from the dropdown
8. Click **Save**

#### Step 6: Redeploy (Important!)

The binding only takes effect after a new deployment. You need to trigger one:

1. Click the **Deployments** tab at the top
2. Find the most recent deployment in the list
3. Click the **three dots (⋯)** menu on the right side of that deployment
4. Click **Retry deployment**
5. Wait for it to finish

#### Step 7: Verify Everything Works

Open your browser and test both of these URLs (replace `<your-project-name>` with whatever project name you chose):

1. `https://<your-project-name>.pages.dev` — you should see the party viewer web app
2. `https://<your-project-name>.pages.dev/api/fg-characters` - you should see: "error: no character data uploaded yet"

The site is ready if both work! If the second URL throws an error, double-check that the KV binding is set up correctly (Step 5) and that you redeployed (Step 6).

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
C:\Users\YourName\Documents\dcc-party-tracker\
├── run-setup.bat               ← Double-click this to run the setup wizard **Run this first!**
├── setup.ps1                   ← Setup wizard (called by run-setup.bat)
├── run-setup.bat               ← from the root of the project
├── run-uninstall.bat           ← Double-click to remove background task
├── scripts\
│   ├── fg-sync.ps1             ← from the scripts folder
│   └── install-fg-sync.ps1     ← from the scripts folder
```

> You don't need `index.html` or the `functions/` folder on your PC — those only for GitHub/Cloudflare. You just need `run-setup.bat`, `setup.ps1`, and the `scripts/` folder.

#### Step 2: Run the Setup Wizard

1. Open File Explorer and navigate to where you saved the files (e.g., `C:\Users\YourName\Documents\dcc-party-tracker\`)
2. Double click `runsetup.bat` to launch the setup wizard in CMD
3. The wizard will walk you through everything:
   - It finds your Fantasy Grounds campaigns automatically
   - You pick which campaign to sync (by number)
   - You paste your Cloudflare Pages URL (e.g., `https://<your-project-name>.pages.dev`)
   - It tests the connection
   - It shows you which characters it found 
   - Install background task? (y/n): y

#### Step 3: Test It

1. Open your campaign in Fantasy Grounds
2. Type `/save` in the FG chat window (this forces an immediate save)
3. The sync script should detect the save and push data within seconds
4. Open your site URL in a browser — characters should appear!

If you installed the background task in Step 3, the sync runs automatically whenever you log in to Windows. You don't need to start anything manually — just open Fantasy Grounds and play.

---

### Part 4: Using the Web App

#### For All Players
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

---

## Switching Campaigns

Run `run-setup.bat` again and pick a different campaign. It will create a new background task for that campaign. You can have multiple tasks running simultaneously if you switch back and forth between campaigns.

---

## Running Multiple Campaigns

If you run more than one campaign (or different GMs in your group each run their own), create a **separate Cloudflare Pages project for each campaign**. This keeps everything isolated — different site, different KV storage, no conflicts.

For each additional campaign:

1. Create a new Pages project in Cloudflare with a different name (e.g., `skulls-of-chaos`)
2. Create a new KV namespace (e.g., `fg-campaign-2`) and bind it with variable name `FG_DATA`
3. Redeploy the new project
4. Run `run-setup.bat` again on the GM's PC and pick the new campaign + enter new site URL

Each sync script instance watches a different campaign folder and pushes to a different site. They can run simultaneously with no issues.

> Do not try to share a single Pages site and KV namespace across multiple campaigns. The storage keys and browser data would collide, causing campaigns to overwrite each other's data.

---

## Technical Notes

- **Cost**: Everything used here is free. Cloudflare's free tier allows 100K reads/day and 1K writes/day
- **Autosave**: Fantasy Grounds writes db.xml every ~5 minutes during a session, and on session close. The GM can also type `/save` in FG chat for an immediate save.
- **Backups**: The fg-sync.ps1 script creates hourly backups of the player-data in your campaign backups folder. Backups older than 30 days are automatically deleted.
