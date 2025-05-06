# nagios-thruk

<!-- Add badges here -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![Build Status](https://travis-ci.org/your-org/nagios-thruk.svg?branch=main)](https://travis-ci.org/your-org/nagios-thruk) -->

This Docker image provides a ready-to-run monitoring environment featuring Nagios Core 4.2.4 as the monitoring engine and Thruk 3.22 as the modern web interface. It's built upon Debian Bookworm for compatibility with current libraries.

## Features

- **Nagios Core 4.2.4:** The powerful and widely-used monitoring engine.
- **Thruk 3.22:** A modern, multibackend monitoring web interface with advanced features.
- **MK Livestatus:** Enables efficient, real-time access to Nagios status data, used by Thruk.
- **Nginx + uWSGI:** High-performance web server and application gateway serving the Thruk interface.
- **NRDP Support (via nrdp-micro):** Includes a lightweight Go-based service to accept passive check results via NRDP.
- **Sensible Defaults:** Pre-configured with common settings and directory structures.
- **Standard Nagios Plugins:** Includes `nagios-plugins-standard` and `nagios-plugins-basic`.

## Installation & Usage

Run the container using Docker. You need to map volumes for configuration, persistent data, and logs.

```bash
docker run -d --name nagios-thruk \
  -p 8080:80 \ # Map host port 8080 to container port 80
  -v ./my-nagios-config:/opt/nagios/etc \     # Mount your Nagios config directory
  -v ./nagios-data:/opt/nagios/var \         # Mount a volume for persistent Nagios runtime data
  -v ./nagios-logs:/var/log/nagios4 \        # Mount a volume for Nagios logs
  -v ./nrdp-spool:/var/spool/nagios/nrdp \   # Mount NRDP spool directory (optional)
  ghcr.io/your-org/nagios-thruk
```

- Access Thruk UI at `http://<your-docker-host>:8080/thruk/`
- Default login: `thrukadmin` / `thrukadmin` (configured in `/etc/thruk/htpasswd` - you should change this!)

**Volume Explanations:**

- `-v ./my-nagios-config:/opt/nagios/etc`: **Crucial.** Mount your local directory containing `nagios.cfg`, `cgi.cfg`, and the `objects/` subdirectory here. The container expects your Nagios object definitions (hosts, services, commands, etc.) to reside within `/opt/nagios/etc/objects/`.
  *Note: If this volume is empty or not mounted, the entrypoint script will generate a basic default configuration monitoring `localhost` to ensure Nagios starts.*
- `-v ./nagios-data:/opt/nagios/var`: **Recommended.** Mount a persistent volume here to retain Nagios runtime data like `status.dat`, `retention.dat`, and the `rw` directory (command pipe, livestatus socket) across container restarts.
- `-v ./nagios-logs:/var/log/nagios4`: **Recommended.** Mount a persistent volume for Nagios log files (`nagios.log`, `nagios.debug`) and log archives.
- `-v ./nrdp-spool:/var/spool/nagios/nrdp`: **Optional.** If using the included `nrdp-micro` service, mount a directory here where `nrdp-micro` will look for incoming passive check result files.

## Configuration

Container configuration is primarily managed by providing your Nagios configuration files via the `/opt/nagios/etc` volume mount.

**Key Files & Directories (within the container):**

```
/opt/nagios/
├── etc/          # YOUR mounted configuration files
│   ├── nagios.cfg    # Main Nagios core configuration
│   ├── cgi.cfg       # CGI configuration (used by Thruk)
│   └── objects/      # Your Host, Service, Command, etc. definitions (*.cfg)
├── var/          # Mounted runtime data (status.dat, retention.dat, sockets)
│   ├── status.dat    # Current status data file
│   └── rw/           # Runtime writable directory
│       ├── nagios.cmd    # External command pipe
│       └── livestatus    # Livestatus socket
└── plugins/      # Standard Nagios plugins directory (part of the image)

/etc/thruk/         # Thruk specific configuration
├── thruk_local.conf # Local Thruk overrides (part of the image, can be customized)
└── htpasswd        # Thruk web UI authentication (part of the image, **should be replaced/mounted**)

/var/log/nagios4/   # Mounted Nagios logs (nagios.log, archives)

/var/spool/nagios/nrdp/ # Optional mounted NRDP spool directory

/etc/nrdp_micro/config.yaml # Configuration for the nrdp-micro service
```

**Managing Configuration Files:**

You manage the contents of the directory you mount to `/opt/nagios/etc`. Common approaches include:

1.  **Direct Editing:** Simply place your `nagios.cfg`, `cgi.cfg`, and `objects/` directory (with all your `.cfg` files inside) into your local `./my-nagios-config` directory before starting the container.
2.  **Version Control (Git):** Maintain your Nagios configuration in a Git repository. Clone the repository locally and mount it.
    ```bash
    git clone https://your-git-server/nagios-configs.git ./my-nagios-config
    # Add/edit files in ./my-nagios-config
    docker run ... -v ./my-nagios-config:/opt/nagios/etc ...
    ```
3.  **Git Submodules:** If parts of your configuration are shared across projects or maintained separately, you can use Git submodules within your main configuration repository.
    ```bash
    # Inside your main config git repo (e.g., ./my-nagios-config)
    git submodule add https://your-git-server/shared-nagios-templates.git objects/templates
    git submodule update --init --recursive
    # Now ./my-nagios-config/objects/templates contains the shared templates
    docker run ... -v ./my-nagios-config:/opt/nagios/etc ...
    ```
    Remember to commit changes in the submodule directory and push them to their own repository, then commit the updated submodule reference in the parent repository.

**Important:** Always validate your Nagios configuration before restarting the container or Nagios service:
`/usr/sbin/nagios4 -v /opt/nagios/etc/nagios.cfg` (you can run this inside the container using `docker exec`).

## Makefile Convenience Targets

This repository includes a `Makefile` to simplify common Docker operations:

- `make build`: Builds the Docker image (`nagios-thruk-app`).
- `make verify`: Builds the image (if needed) and runs the Nagios configuration verification (`nagios4 -v`) using the template configuration inside a temporary container.
- `make run`: Builds the image (if needed) and starts a new container (`nagios-thruk`) in detached mode, mapping host port `9095` to the container's port `80`.
- `make stop`: Stops the running container.
- `make rm`: Stops and removes the container.
- `make up`: A combination of `rm` and `run`. Stops/removes any existing container, builds the image, and starts a new one. This is the default target (`make` or `make all`).
- `make logs`: Tails the logs of the running container.
- `make clean`: Stops/removes the container and then removes the Docker image.

Adjust the `HOST_PORT` variable in the `Makefile` if you need to use a different port than `9095`.

## Development

To build the image locally *without* using the Makefile:

```bash
git clone https://github.com/your-org/nagios-thruk
cd nagios-thruk
docker build -t nagios-thruk .
```

## Contributing

Contributions, issues, and feature requests are welcome!

## License

This Docker setup is licensed under the MIT License - see the `LICENSE` file for details (if one exists in the repo). Note that Nagios Core, Thruk, and potentially other bundled components are distributed under their own licenses (often GPL).
