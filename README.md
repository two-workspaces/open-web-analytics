# Deploy and Host Open Web Analytics on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/open-web-analytics?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=open-web-analytics)

[Open Web Analytics](https://www.openwebanalytics.com/) (OWA) is open-source web analytics in the Google Analytics mould: visitors, sessions, pageviews, traffic sources, search terms, campaigns, entry and exit pages, countries, browsers, ecommerce transactions and goals, plus click heatmaps and "domstream" session replays. It has users and per-site permissions, and a WordPress plugin. This template runs the current release on PHP 8.3 with MariaDB, installed for you, with the web installer locked away.

## About Hosting Open Web Analytics

Two services: Open Web Analytics (Apache + PHP) and a private MariaDB with its own volume.

- **Installed from the first second.** The database and the `admin` account are created on first boot, with the password from `OWA_ADMIN_PASSWORD`. The web installer is blocked, so a fresh deployment can't be claimed by a stranger.
- **Only the public endpoints are public.** Everything except the dashboard, the tracker script and the logging endpoint is denied.
- **Real visitor addresses.** The visitor's IP comes from the header Railway's edge sets; `X-Forwarded-For` sent by a browser is ignored, so visitors can't fake their country.
- **Upgrades apply themselves.** Each start runs OWA's schema updates, and OWA's scheduler (report rollups, partition rotation) ticks every minute inside the service.

## Common Use Cases

- Self-hosted, Google Analytics-style reports for websites and WordPress
- Click heatmaps and session replays without a SaaS
- Ecommerce and goal tracking on data you own

## Dependencies for Open Web Analytics Hosting

- MariaDB 11.8 (included, private network only)

### Deployment Dependencies

- [Open Web Analytics wiki](https://github.com/Open-Web-Analytics/Open-Web-Analytics/wiki)
- [Template source on GitHub](https://github.com/two-workspaces/open-web-analytics)

### Implementation Details

**Sign in** at the service's domain as `admin` with the `OWA_ADMIN_PASSWORD` value from the Variables tab. Change it afterwards under your account; the variable is only read on first boot.

**Your first site** is created from `OWA_SITE_URL` (set it before deploying, or edit the site afterwards). Add more under Administration → Sites. Each site's tracking code page in the admin gives you the snippet for your pages' `<head>`; the WordPress plugin needs only the OWA address.

**Custom domain.** Add it in Settings → Networking, then set `OWA_URL` to `https://your.domain`.

**Memory.** About 0.1 GB for OWA and 0.2 GB for MariaDB at rest. `OWA_APACHE_WORKERS` (default 20) caps Apache processes.

**Keys.** OWA's nonce and auth keys are derived from `OWA_SECRET`. Keep it; changing it signs everyone out.

## Why Deploy Open Web Analytics on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Open Web Analytics on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
