# DCC Party Viewer

A web app that displays your Dungeon Crawl Classics RPG party in a shared browser view.

## What You Need
**Cloudflare account**
Hosting provider

## Project Files

```
dcc-party-tracker/
├── index.html     
├── functions/
│   └── api/
│         └── player-data.js      ← API: player-editable data (journals, etc.)
└── README.md
```

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
   - **Project name**: Choose a name for your campaign (e.g., `my-dcc-campaign`, `skulls-of-chaos`). This becomes your website URL, so keep it short and simple.
   - **Production branch**: `main` (this is the default, leave it as is or change to a different branch if you want to deploy another version or different campaign)
   - **Framework preset**: None
   - **Build command**: **leave this blank**
   - **Build output directory**: **leave this blank**
2. Click **Save and Deploy**
3. Wait for the deployment — it usually takes under a minute
4. When it says "Success", your site is live!
5. Click the URL shown (something like `https://your-project-name.pages.dev`) to see your site

#### Step 4: Create a KV Namespace

KV (Key-Value) is a small cloud database that Cloudflare provides for free. This is where character data gets stored so all players can see it. Each campaign needs its own KV namespace.

1. In the Cloudflare dashboard left sidebar, click **Workers & Pages**
2. In the left sidebar under Workers & Pages, click **KV**
3. Click **Create a namespace**
4. For the name, use your campaign/project name (e.g., `skulls-of-chaos-data`). This is just a label so you can tell your namespaces apart in the dashboard — it can be anything.
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
