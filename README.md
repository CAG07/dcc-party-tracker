# DCC Party Viewer

A shared web app for tracking your Dungeon Crawl Classics RPG party — characters, marching order, quests, journals, and more. Built on Cloudflare Pages with near real-time sync between players.

## What You Need
A **Cloudflare account** for hosting, storage, and automated deployment

## Setup Guide

### Part 1: GitHub Fork
 
Fork this repository to create your own copy. 
 
---

### Part 2: Deploy the Website to Cloudflare Pages

Cloudflare Pages is a service for hosting a website with a URL like `https://your-project-name.pages.dev`. A Durable Object Worker provides near real-time sync and persistent storage — when one player updates the tracker, all other players see the change within seconds via WebSocket.

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

#### Step 4: Deploy the Durable Object Worker

The Durable Object (DO) Worker is what stores your party data and keeps all connected browsers in sync via WebSocket. It deploys automatically through GitHub Actions whenever you push changes to the `worker/` directory, but first you need to give GitHub permission to deploy to your Cloudflare account.

##### Step 4a: Get Your Cloudflare Account ID
1. In the Cloudflare dashboard, click **Workers & Pages** in the left sidebar
2. On the right side of the overview page, you'll see **Account ID** — copy this value

##### Step 4b: Create a Cloudflare API Token
1. Go to your Cloudflare profile: click your avatar (top right) → **My Profile**
2. Click **API Tokens** in the left sidebar
3. Click **Create Token**
4. Find the **Edit Cloudflare Workers** template and click **Use template**
5. Leave the default permissions as-is (they grant access to Workers, Durable Objects, and account settings — all required for deployment)
6. Click **Continue to summary** → **Create Token**
7. Copy the token immediately — you won't be able to see it again

##### Step 4c: Add Secrets to GitHub
1. Go to your forked repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each of the following:

| Secret Name | Value |
|---|---|
| `CLOUDFLARE_ACCOUNT_ID` | The Account ID you copied in Step 4a |
| `CLOUDFLARE_WORKERS_API_TOKEN` | The API token you created in Step 4b |

##### Step 4d: Trigger the First Deployment
The GitHub Action runs automatically when files in the `worker/` directory change. To trigger the first deployment:
1. Go to the **Actions** tab in your GitHub repository
2. Click the **Deploy DO Worker** workflow in the left sidebar
3. Click **Run workflow** → **Run workflow**
4. Wait for the job to complete with a green checkmark

After this first deployment, all future changes to `worker/` will deploy automatically on push.

#### Step 5: Connect the Durable Object to Your Pages Project

Now you need to tell your Pages project where to find the Durable Object Worker. This is called a "binding." Without this step, the website can't reach the Worker that stores your data.

1. In the Cloudflare dashboard, click **Workers & Pages** in the left sidebar
2. Click on your Pages project name (the one you chose in Step 3)
3. Click the **Settings** tab at the top
4. Scroll down to **Bindings** (or click **Bindings** in the left sidebar)
5. Click **Add**
6. Select **Durable Object namespace**
7. Fill in:
   - **Variable name**: `PARTY_STATE` (type this exactly — it must be `PARTY_STATE` every time, this is what the code looks for)
   - **Durable Object namespace**: select `dcc-party-state` from the dropdown (this is the Worker you deployed in Step 4)
8. Click **Save**

> **Why is the variable name always the same?** The Worker name (`dcc-party-state`) is what you deployed. The variable name (`PARTY_STATE`) is what the website code uses to find the Worker. Every campaign project uses the variable name `PARTY_STATE`, but each one points to a different Worker deployment.

#### Step 6: Redeploy (Important!)

The binding only takes effect after a new deployment. You need to trigger one:

1. Click the **Deployments** tab at the top
2. Find the most recent deployment in the list
3. Click the **three dots (⋯)** menu on the right side of that deployment
4. Click **Retry deployment**

---

### Multiple Campaigns

If you run more than one campaign, each campaign needs its own Pages project and its own Durable Object Worker. To set up a second campaign:

1. Create a new Pages project in Cloudflare (Step 2-3) with a different project name
2. In `worker/wrangler.toml`, change the `name` field to something unique (e.g., `dcc-campaign2`) and push the change — the GitHub Action will deploy a new Worker
3. Add a `PARTY_STATE` binding on the new Pages project pointing to the new Worker (Step 5)
4. Redeploy the new Pages project (Step 6)

Each campaign's data is completely isolated in its own Durable Object.