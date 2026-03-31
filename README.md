# DCC Party Viewer

A web app that displays your Dungeon Crawl Classics RPG party in a shared browser view. Character data syncs automatically from Fantasy Grounds during a session.

## Architecture Overview

```
Fantasy Grounds (GM's PC)          Cloudflare (cloud)           Browser (any player)
┌─────────────────────┐           ┌──────────────┐           ┌──────────────────┐
│  db.xml auto-saves  │──push──>  │  KV Storage  │  <──read──│ Party Viewer     │
│  every ~5 minutes   │           │              │           │ shows characters │
└─────────────────────┘           │ fg-characters│           │ journals, quests │
                                  │ player-data  │──write<───│ notes, graveyard │
                                  └──────────────┘           └──────────────────┘
```

- **fg-characters**: Written by the sync script on the GM's PC. Contains character stats from Fantasy Grounds.
- **player-data**: Written by players through the browser. Contains journals, graveyard, quests, notes, etc.
- These two keys can never overwrite each other.

## What You Need

- A **Windows PC** running Fantasy Grounds Unity (the GM's computer)
- A **GitHub account** — this stores the website code
- A **Cloudflare account** — this hosts the website so everyone can access it

## Project Files

```
dcc-party-tracker/
├── index.html                  ← The web app (this is what players see)
├── functions/
│   └── api/
│       ├── fg-characters.js    ← API: character data from Fantasy Grounds
│       └── player-data.js      ← API: player-editable data (journals, etc.)
├── scripts/
│   ├── fg-sync.ps1             ← Watches db.xml and pushes changes
│   └── install-fg-sync.ps1     ← Registers the sync as a scheduled task
├── setup.ps1                   ← Interactive setup wizard (run this first!)
├── run-setup.bat               ← Double-click to run setup (bypasses execution policy)
├── run-uninstall.bat           ← Double-click to remove the scheduled task
└── README.md
```

---

## Setup Guide

### Part 1: GitHub Fork
 
Fork this repository to create your own copy. 
 
---

### Part 2: Deploy the Website to Cloudflare Pages

Cloudflare Pages is a free service that takes your code from GitHub and turns it into a live website with a URL like `https://your-project-name.pages.dev`. It also provides a small cloud database (called KV) where character data is stored.

> **Important**: The project name you choose in Step 3 below becomes your website URL. If you plan to run multiple campaigns, name each project after the campaign (e.g., `curse-of-strahd`, `tomb-of-horrors`). This keeps them separate.

#### Step 1: Create a Cloudflare Account
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Sign up** and create an account (the free plan is all you need)
3. Verify your email if prompted

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
   - **Project name**: Choose a name for your campaign (e.g., `my-dcc-campaign`, `skulls-of-chaos`). This becomes your website URL, so keep it short and simple. **Do not** use `dcc-party-tracker` — that's the repo name, not your project name.
   - **Production branch**: `fg-sync` (this is the branch that auto-syncs character data from Fantasy Grounds)
   - **Framework preset**: None
   - **Build command**: **leave this completely blank**
   - **Build output directory**: **leave this completely blank** (or type `/`)
2. Click **Save and Deploy**
3. Wait for the deployment — it usually takes under a minute
4. When it says "Success", your site is live!
5. Click the URL shown (something like `https://your-project-name.pages.dev`) to see your site

> **Bookmark this URL** — this is what you'll share with your players. Write it down, you'll need it again in Part 3.

#### Step 4: Create a KV Namespace

KV (Key-Value) is a small cloud database that Cloudflare provides for free. This is where character data gets stored so all players can see it. Each campaign needs its own KV namespace.

1. In the Cloudflare dashboard left sidebar, click **Workers & Pages**
2. In the left sidebar under Workers & Pages, click **KV**
3. Click **Create a namespace**
4. For the name, use your campaign/project name (e.g., `FG_DATA_skulls-of-chaos`). This is just a label so you can tell your namespaces apart in the dashboard — it can be anything.
5. Click **Add**

#### Step 5: Connect KV to Your Website

Now you need to tell your website where to find the database. This is called a "binding." The binding connects your KV namespace to your Pages project.

1. In the left sidebar, click **Workers & Pages**
2. Click on your project name (the one you chose in Step 3)
3. Click the **Settings** tab at the top
4. Scroll down to **Bindings** (or click **Bindings** in the left sidebar)
5. Click **Add**
6. Select **KV namespace**
7. Fill in:
   - **Variable name**: `FG_DATA` (type this exactly — it must be `FG_DATA` every time, this is what the code looks for)
   - **KV namespace**: select the namespace you created in Step 4 from the dropdown
8. Click **Save**

> **Why is the variable name always the same?** The namespace name (Step 4) is just a label for you. The variable name (Step 5) is what the website code uses to find the database. Every campaign project uses the variable name `FG_DATA`, but each one points to a different namespace.

#### Step 6: Redeploy (Important!)

The binding only takes effect after a new deployment. You need to trigger one:

1. Click the **Deployments** tab at the top
2. Find the most recent deployment in the list
3. Click the **three dots (⋯)** menu on the right side of that deployment
4. Click **Retry deployment**
5. Wait for it to finish

#### Step 7: Verify Everything Works

Open your browser and test both of these URLs (replace `your-project-name` with whatever you chose in Step 3):

1. `https://your-project-name.pages.dev` — you should see the party viewer web app
2. `https://your-project-name.pages.dev/api/fg-characters` — you should see: `{"error":"No character data uploaded yet"}`

If both work, the website is ready! If the second URL gives a different error, double-check that the KV binding is set up correctly (Step 5) and that you redeployed (Step 6).

---

### Part 3: Set Up the Sync Script (GM's Windows PC)

This part runs on the GM's computer. The script watches for changes to the campaign file and automatically pushes character data to the website.

#### Step 1: Download the Scripts

You need 5 files from this repository on your PC:

1. Go to your fork on GitHub (`github.com/YOUR-USERNAME/dcc-party-tracker`)
2. Click the green **Code** button → **Download ZIP**
3. Open the downloaded ZIP and extract it somewhere on your PC
4. Copy these files to a permanent location (they need to stay here):
```
C:\Users\YourName\Documents\fg-sync\
├── run-setup.bat               ← double-click to run setup
├── run-uninstall.bat            ← double-click to remove the sync task
├── setup.ps1                   ← from the project root
├── scripts\
│   ├── fg-sync.ps1             ← from the scripts folder
│   └── install-fg-sync.ps1     ← from the scripts folder
```

> You don't need `index.html` or the `functions/` folder on your PC — those only matter on GitHub/Cloudflare. You just need `setup.ps1` and the `scripts/` folder.

#### Step 2: Run the Setup Wizard

1. Open File Explorer and navigate to where you saved the files
2. Double-click `run-setup.bat` (this bypasses PowerShell's execution policy automatically)
3. The wizard will walk you through everything:
   - It finds your Fantasy Grounds campaigns automatically
   - You pick which campaign to sync (by number)
   - You paste your Cloudflare Pages URL (e.g., `https://your-project-name.pages.dev`)
   - It tests the connection
   - It shows you which characters it found
   - It offers to install the sync task (say yes!)

#### Step 3: Test It

1. Open your campaign in Fantasy Grounds
2. Type `/save` in the FG chat window (this forces an immediate save)
3. Start the sync task (see "Starting the Sync" below)
4. The sync script should detect the save and push data within seconds
5. Open your site URL in a browser — characters should appear!

---

### Part 4: Using the Web App

#### For All Players
- Open the site URL in any browser
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

## Starting the Sync

The sync script does **not** start automatically. Start it manually before a session using one of these methods:

### Option 1: Desktop Shortcut (Recommended)

Create a one-click shortcut to start the sync silently:

1. Right-click your Desktop → **New** → **Shortcut**
2. For the location, paste:
   ```
   schtasks /run /tn "FG-Sync-Tower of the Black Pearl"
   ```
3. Click **Next**, name it something like `Start FG Sync`, click **Finish**
4. (Optional) Right-click the shortcut → **Properties** → **Change Icon** → pick a Fantasy Grounds or dice icon

Replace `Tower of the Black Pearl` with your campaign folder name.

### Option 2: PowerShell

```powershell
Start-ScheduledTask -TaskName "FG-Sync-Tower of the Black Pearl"
```

### Option 3: Task Scheduler UI

Open Task Scheduler (search it in the Start menu), find your task, right-click → **Run**.

---

## Monitoring the Sync Script

The sync script runs in a visible console window so you can see it working. Log output also goes to a file.

**View log file:**
```powershell
Get-Content "$env:LOCALAPPDATA\fg-sync-Tower of the Black Pearl" -Tail 20
```

**Check if the task is running:**
```powershell
Get-ScheduledTask -TaskName "FG-Sync-Tower of the Black Pearl" | Select-Object State
```

**Manually start/stop:**
```powershell
Start-ScheduledTask -TaskName "FG-Sync-Tower of the Black Pearl"
Stop-ScheduledTask -TaskName "FG-Sync-Tower of the Black Pearl"
```

Replace `Tower of the Black Pearl` with your campaign folder name in all commands above. The setup wizard prints the exact commands for your campaign when it finishes.

---

## Switching Campaigns

Run `setup.ps1` again and pick a different campaign. It will update the sync script with the new campaign name and site URL.

---

## Running Multiple Campaigns

If you run more than one campaign (or different GMs in your group each run their own), create a **separate Cloudflare Pages project for each campaign**. This keeps everything isolated — different site, different KV storage, no conflicts.

For each additional campaign:

1. Create a new Pages project in Cloudflare pointing to the **same** GitHub repo, with a campaign-specific name (e.g., `tomb-of-horrors`)
2. Create a new KV namespace (e.g., `FG_DATA_tomb-of-horrors`) — follow Part 2, Step 4
3. Bind it to the new Pages project with variable name `FG_DATA` — follow Part 2, Step 5
4. Redeploy the new project — follow Part 2, Step 6
5. Run `setup.ps1` again on the GM's PC and pick the new campaign + new site URL

One GitHub repo serves all campaigns. Bug fixes auto-deploy to every campaign site. Each sync script instance watches a different campaign folder and pushes to a different site. They can run simultaneously with no issues. Cloudflare allows up to 5 Pages projects per repository on the free tier.

> **Do not** try to share a single Pages site and KV namespace across multiple campaigns. The storage keys and browser data would collide, causing campaigns to overwrite each other's data.

---

## Technical Notes

- **Cost**: Everything used here is free. Cloudflare's free tier allows 100K reads/day and 1K writes/day — more than enough for a party of 4-6 players.
- **Autosave**: Fantasy Grounds writes db.xml every ~5 minutes during a session, and on session close. The GM can also type `/save` in FG chat for an immediate save.
- **File Safety**: The sync script never writes to db.xml — it only reads. It cannot corrupt your campaign data.
- **Merge Logic**: Player data (journals, quests, graveyard) uses union-merge, so multiple players can edit at the same time without overwriting each other's changes.
- **Privacy**: Your site URL is technically public, but it's an obscure `.pages.dev` address that will typically not be found unless you share it. For additional security, Cloudflare Access (free for up to 50 users) can restrict the site to specific email addresses.
