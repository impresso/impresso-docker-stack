# Impresso app stack

Running Impresso app stack in docker compose:

```shell
docker-compose -p impresso up
```

Running in production (detached mode):

```shell
docker-compose -p impresso up -d
```

Reading logs in production:
```shell
docker-compose -p impresso logs -f
```

# Configuration

Docker compose expects several files located in `config` directory in this folder:

 * `impresso-middle-layer.json` - middle layer API configuration
 * `impresso-user-admin.env` - admin dashboard and celery tasks app configuration
 * `nginx.conf` - nginx configuration
 * `ssh/config` - ssh tunnel configuration (plus key files in `ssh` folder if needed)
 * `recsys_config.py` - collections recommender system configuration

We provide a sample set of files in `config_example`. Fields that need to be replaced (mostly hostnames, usernames and passwords) are marked with `[!!!REPLACE]` string.

A special note about the database. Our setup assumes the database is accessed via an SSH tunnel to the database host. If the database port is accessible directly, you can simplify the configuration by setting the db hostname, port and credentials in the relevant config files, commenting out the `mysql-tunnel` section in `docker-compose.yml`. In this case you also do not need the files in the `config/ssh` folder, those are used for the DB tunnel only.

# Apps versions

Tags of `impresso` docker images are read from the `.env` file. The default file with all tags set to `latest` is provided in this repository.

## Docker specific configuration notes for components

### Middle Layer API

Make sure the following parameters are set to internal docker hostnames:

 * `redis.host` to `redis`
 * `celery.CELERY_BROKER_URL` hostname to `redis`
 * `celery.CELERY_RESULT_BACKEND` hostname to `redis`
 * `sequelize.host` to `mysql-tunnel`
 * `sequelize.port` to `3306`


### User Admin Dashboard / Celery

Make sure the following parameters are set to internal docker hostnames:

 * `IMPRESSO_DB_HOST` to `mysql-tunnel`
 * `IMPRESSO_DB_PORT` to `3306`
 * `REDIS_HOST` to `redis`
 * `STATIC_URL` to `/admin/static/` (assuming in `nginx` configuration the base URL of the dashboard is `/admin/`)
 * `ALLOWED_HOSTS` to `*` (dashboard is behind nginx reverse proxy which manages this)

### Frontend Web App

When building docker container for the app make sure:

 * webpack compiles the app with `PUBLIC_PATH` environmental variable set to `/app/` (assuming that the app base URL in `nginx` configuration is `/app`).
 * `BASE_URL` in `prod.env.js` is set to `'"/app"'` (assuming that the app base URL in `nginx` configuration is `/app`).
 * `MIDDLELAYER_API` in `prod.env.js` is set to `'""'`
 * `MIDDLELAYER_API_PATH` in `prod.env.js` is set to `'"/api"'` (assuming that middle layer API base URL in `nginx` configuration is `/api`)
 * `MIDDLELAYER_API_SOCKET_PATH` in `prod.env.js` is set to `'"/api/socket.io/"'` (assuming that middle layer API base URL in `nginx` configuration is `/api`)
 * `MIDDLELAYER_MEDIA_PATH`  in `prod.env.js` is set to `'"/api/media"'` (assuming that the api base URL in `nginx` configuration is `/api`)
 
