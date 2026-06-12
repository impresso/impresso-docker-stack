# Impresso app stack

## Prepare environment

Copy the example environment file:

```shell
cp .env.example .env
```

Edit the `.env` file to set the correct secret values for your environment.

## Running in production

Link production config files and directories:

```shell
ln -s config_prod config
ln -s .env.nosecret-prod .env.nosecret
ln -s .env.prod .env
```

Production servers do not require a proxy.

```shell
docker compose  --env-file ./.env.prod --env-file ./.env.nosecret-prod up
```

or

```shell
docker compose  --env-file ./.env.prod --env-file ./.env.nosecret-prod --profile barista up -d
```

## Running in dev (staging)

Link dev config files and directories:

```shell
ln -s config_dev config
ln -s .env.nosecret-dev .env.nosecret
ln -s .env.dev .env
```

Running in staging (detached mode), with the watchtower service that updates the images every 5 minutes:

```shell
docker compose \
  --env-file ./.env \
  --env-file ./.env.nosecret \
  --profile barista \
  -f docker-compose.yml -f docker-compose.watcher.yml \
  -p impresso up -d
```

Reading logs in production:

```shell
docker compose logs -f
```

The `.env.example` contains `latest` images of the services in docker-compose and it is for development purposes.

## Running in development

Running outside of the production servers requires a proxy.

```shell
docker compose --env-file ./.env --env-file ./.env.nosecret --profile with_proxy up
```

If barista service needs to be enabled, add `--profile barista` to the command above.

```shell
docker compose --env-file ./.env --env-file ./.env.nosecret --profile with_proxy --profile barista up
```

## Configuration

Docker compose expects several files located in `config` directory.

Several directories are provided for different configurations:

- `config_prod` - production configuration
- `config_dev` - development configuration

To use the suitable configuration, create a symlink to the desired configuration directory:

```shell
ln -s config_prod config
```

### Proxy and extra nginx configuration

Proxy (ssh tunnel) configuration should be placed in `proxy_config` directory. If nginx configuration needs extra files, they should be placed in `nginx_config` directory.

A special note about the database. Our setup assumes the database is accessed via an SSH tunnel to the database host. If the database port is accessible directly, you can simplify the configuration by setting the db hostname, port and credentials in the relevant config files, commenting out the `mysql-tunnel` section in `docker-compose.yml`. In this case you also do not need the files in the `config/ssh` folder, those are used for the DB tunnel only.

## Host configuration

Increase the default limit of open files on the host server to increase the maximum allowed number of connections. See [socket.io performance tuning](https://socket.io/docs/v4/performance-tuning/#at-the-os-level).

## Apps versions

Tags of `impresso` docker images are read from the `.env` file. The default file with all tags set to `latest` is provided in this repository.

## Dragonfly (Redis replacement)

We use [Dragonfly](https://dragonflydb.io/) instead of Redis as the in-memory data store. The reasons:

- **BullMQ / Celery broker** — services use BullMQ (Node) and Celery (Python) for job queues, both of which require full Lua scripting support. Redis-compatible alternatives with disk spillover (KVRocks, Pika) have limited Lua support and do not work with BullMQ.
- **Disk spillover** — Dragonfly supports SSD tiering via `--tiered_prefix`, allowing the dataset to exceed available RAM. On Linux hosts with `io_uring` support, cold data is automatically offloaded to disk. On macOS (Docker Desktop), tiering is disabled automatically at startup since `io_uring` is not available.
- **noeviction** — the store is configured with `noeviction` so that job queue data and session tokens are never silently dropped. Writes will error if RAM is exhausted rather than losing data.

### Key configuration details

- Startup script: [`scripts/dragonfly-entrypoint.sh`](scripts/dragonfly-entrypoint.sh) — detects `io_uring` availability at runtime and enables/disables tiered storage accordingly.
- Max RAM: `2GB`. Hourly RDB snapshots are written to the `dragonfly-data` volume.
- `--default_lua_flags=allow-undeclared-keys` is required for BullMQ compatibility. Dragonfly enforces strict key declaration in Lua scripts by default; BullMQ constructs keys dynamically inside scripts, which trips this restriction. This flag disables the check at a minor performance cost to Lua calls.
- On Linux production servers, ensure `io_uring` is not disabled (`/proc/sys/kernel/io_uring_disabled` should be `0`) and the container has `seccomp=unconfined` (already set in `docker-compose.yml`) to allow the necessary syscalls.

## Docker specific configuration notes for components

### Frontend Web App

When building docker container for the app make sure:

- webpack compiles the app with `PUBLIC_PATH` environmental variable set to `/app/` (assuming that the app base URL in `nginx` configuration is `/app`).
- `BASE_URL` in `prod.env.js` is set to `'"/app"'` (assuming that the app base URL in `nginx` configuration is `/app`).
- `MIDDLELAYER_API` in `prod.env.js` is set to `'""'`
- `MIDDLELAYER_API_PATH` in `prod.env.js` is set to `'"/api"'` (assuming that middle layer API base URL in `nginx` configuration is `/api`)
- `MIDDLELAYER_API_SOCKET_PATH` in `prod.env.js` is set to `'"/api/socket.io/"'` (assuming that middle layer API base URL in `nginx` configuration is `/api`)
- `MIDDLELAYER_MEDIA_PATH` in `prod.env.js` is set to `'"/api/media"'` (assuming that the api base URL in `nginx` configuration is `/api`)
