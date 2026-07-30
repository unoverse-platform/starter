---
sidebarTitle: "Run the platform"
title: "Run the Platform"
---

Run a universe yourself: the whole platform, on your machine or a server.

You need this to run Agents, use **Canvas**, and serve interfaces to real clients. If you are
building assets to publish to somebody else's universe, you want [Studio](./00a-studio.md)
instead, which needs Node and nothing else.

## How it works

[`starter`](https://github.com/unoverse-platform/starter) is a **template repository**. You create your own copy on GitHub, and everything you build lives in that copy: your nodes, your components, your Agent skills. The platform itself runs as Docker images that you pull, not source you compile.

<Warning>
**A license is required.** The starter repository is the scaffold, not the platform. The platform ships as licensed Docker images, and your registry token is what authorizes downloading them. Without a license, nothing runs.
</Warning>

## Before you begin

| Tool | Version | Install |
| --- | --- | --- |
| **Docker** | 24+ | https://docs.docker.com/get-docker/ |
| **Node.js** | 20+ | https://nodejs.org/ or `nvm install 20` |
| **Git** | 2.x | https://git-scm.com/ |

**Before you start, you need a PostgreSQL database and a Redis instance.** Both can be managed services, such as DigitalOcean, Supabase, or AWS RDS, or run locally for development. The platform does not bundle either one: your databases stay under your own management, backups, and policies. PostgreSQL needs the pgvector extension, which managed providers include by default. Local setups are covered in Troubleshooting below.

Setup asks for four credentials. One comes from unoverse; the rest are yours.

<CardGroup cols={2}>
<Card title="unoverse provides" icon="key">
Your registry token, issued with your license. It authorizes downloading the platform images and activates your installation.
</Card>
<Card title="You provide" icon="database">
Your PostgreSQL connection string, your Redis credentials, and your auth provider's issuer, client ID, and audience. Any OIDC-compatible provider works: Auth0, Okta, Microsoft Entra ID.
</Card>
</CardGroup>

<Note>
Apple Silicon Macs run everything natively. The platform images are multi-arch (amd64 + arm64); no Rosetta needed.
</Note>

## Set up your editor

Everything you author is validated against a schema **as you type**. A typo, a missing field, or an unknown primitive is underlined in the editor rather than surfacing later as a build error or a component that renders wrong.

This works out of the box for `.json` files. YAML files need one extension:

| Extension | ID | Gives you |
| --- | --- | --- |
| **YAML** | `redhat.vscode-yaml` | Schema validation for node manifests and design definitions |

Install it from your editor's extensions panel by searching for `redhat.vscode-yaml`.

<Warning>
Without the extension, YAML files get **no validation at all**. Nothing warns you: they simply stop being checked, and mistakes surface later instead.
</Warning>

You'll confirm it's working the first time you author a node ([Create Your First Node](./03-create-your-first-node.md)): delete a required field such as `type` from its `node.yaml` and a red underline appears within a second. Undo, and it clears.

## Set up the platform

<Steps>
<Step title="Create your repository">

On [`unoverse-platform/starter`](https://github.com/unoverse-platform/starter), click **Use this template → Create a new repository**. This gives you a clean, independent copy. Then clone it:

```bash Clone your copy
git clone https://github.com/YOUR_USERNAME/starter.git ~/unoverse
cd ~/unoverse
```

<Tip>
Clone before opening the folder in your editor. Opening it first can create a `.claude/` directory that blocks the clone.
</Tip>

</Step>
<Step title="Run the setup wizard">

```bash Setup wizard
./unoverse init
```

The wizard asks for your DOCR token, database URL, Redis, and auth credentials. It writes your `.env` file, logs into the registry, and pulls all platform images.

Use `./unoverse` (with the `./`) the first time. After init completes, the CLI installs itself to your PATH and `unoverse` works from anywhere.

</Step>
<Step title="Start the dev environment">

```bash Start everything
unoverse dev
```

One command: starts all containers, installs workspace dependencies, and builds your node packages so the platform loads them.

</Step>
<Step title="Set up the database">

```bash Database setup
unoverse db-setup
```

Runs all migrations and seeds the database. Safe to re-run at any time; migrations are tracked and only applied once.

</Step>
<Step title="Verify">

```bash Health check
unoverse check
```

Every line should be green: services up, health endpoints responding, packages built, nodes loaded, **Canvas** reachable. If anything fails, run `unoverse doctor` for a diagnosis.

</Step>
<Step title="Open Canvas">

| Service | URL | What it is |
| --- | --- | --- |
| **Canvas** | http://localhost:3001 | Build, manage, and observe Agents |
| **API** | http://localhost:4105 | The unoverse engine's public surface |

**Studio** is separate. It is a tool you install, not a service the platform serves, and it
runs on :4108 whether or not a platform is up. See [Studio](./00a-studio.md).

</Step>
</Steps>

## How you'll work

Development is local first. The whole platform runs on your machine in Docker, and it is the same platform that runs in production. The loop:

1. **Build your assets in Studio**: components, templates, custom nodes, services, and skills.
2. **Manage content and availability in Spatial**: ingest your content and control which assets your Agents can find.
3. **Wire them into Agents in Canvas.**
4. **Run and test locally**: step through nodes, preview components, talk to your Agent.
5. **Deploy when you're happy.** `unoverse deploy` runs the [Runbooks](../runbooks/overview.md) against your server.

Production only enters at step 5. That is also the only point where the second environment file matters.

## The two `.env` files

Your project has two environment files, both at the root and both gitignored:

| File | Purpose | Used by |
| --- | --- | --- |
| `.env` | Local development | `docker compose` on your machine |
| Production configuration | Machine-managed | Rendered by your Terraform ground; `unoverse deploy` places it on your server |

Each file has a template in the repo: copy it and fill in your values. The production file also names the server to deploy to. At deploy time, `unoverse deploy` reads it and runs the platform's Ansible playbooks against that server, following the [Runbooks](../runbooks/overview.md).

<Warning>
Don't mix them up. `.env` is local development on your laptop; production configuration comes from your Terraform ground and is never written by hand.
</Warning>

## Where your code lives

**Not in this repo.** This repo operates the universe; everything you author lives in a **Studio project** — Studio scaffolds it (`rx/`, `prompts/`, `nodes/` in the project folder), validates it as you work, and publishes it to your universe over the API.

| You build | In | Guide |
| --- | --- | --- |
| **Logic**: custom workflow nodes (YAML manifests) | Studio project `nodes/` | [Create Your First Node](./03-create-your-first-node.md) |
| **Design**: components, templates, styles | Studio project `rx/` | [Components and Templates](./05-components-and-templates.md) |
| **Behavior**: Agent skills and prompt blocks | Studio project `prompts/` | [Create Your First Agent](./02-create-your-first-agent.md) |

You don't have to build everything yourself. The **marketplace** offers the design system and ready-made nodes and services to install into your universe, per item.

## Daily workflow

```bash Daily workflow
unoverse dev                                 # start your day
# edit nodes/, rx/, or prompts/
unoverse build                               # build all + restart
unoverse build @unoverse-platform/my-node    # or build one package
unoverse stop                                # end your day
```

Every command is documented in the [CLI reference](./00c-cli.md).

## Troubleshooting

<AccordionGroup>
<Accordion title="unauthorized when pulling images">

Log in to the registry again with your DOCR token:

```bash Registry login
echo "YOUR_DOCR_TOKEN" | docker login registry.digitalocean.com -u YOUR_DOCR_TOKEN --password-stdin
```

</Accordion>
<Accordion title="Services not starting">

Check the logs for the failing service:

```bash Service logs
unoverse logs unoverse
unoverse logs canvas
```

</Accordion>
<Accordion title="Can't reach database server at 127.0.0.1">

Inside a Docker container, `localhost` refers to the container itself, not your machine. If you run a local Postgres, use Docker's host alias in your `DATABASE_URL`:

```bash .env
DATABASE_URL=postgresql://postgres:password@host.docker.internal:5432/gravity
```

Not needed for managed databases (DigitalOcean, Supabase, and similar).

</Accordion>
<Accordion title="extension vector is not available during db-setup">

Your local Postgres needs the pgvector extension. Managed databases ship with it pre-installed.

```bash Install pgvector
brew install pgvector                      # Mac
sudo apt install postgresql-16-pgvector    # Ubuntu/Debian (match your PG version)
```

If you run Postgres in Docker, use the `pgvector/pgvector:pg16` image instead of plain `postgres`. Restart Postgres and re-run `unoverse db-setup`.

</Accordion>
<Accordion title="Redis connection refused">

For local development, start Redis with Docker:

```bash Local Redis
docker run -d --name unoverse-redis -p 6379:6379 redis:7-alpine
```

</Accordion>
<Accordion title="Still stuck">

```bash Diagnose
unoverse doctor
```

It checks the whole stack and tells you what's wrong.

</Accordion>
</AccordionGroup>

## Next steps

<Card title="Build your first Agent" icon="bot" href="./02-create-your-first-agent.md" horizontal>
Wire a trigger, a model, and a response together in **Canvas**, and talk to it.
</Card>

<Card title="Explore the CLI" icon="terminal" href="./00c-cli.md" horizontal>
Every command for setup, development, design, and deployment.
</Card>

<Card title="Create a component" icon="palette" href="./05-components-and-templates.md" horizontal>
Design a component in **Studio** and see it render live.
</Card>
