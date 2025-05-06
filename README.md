# nagios-thruk

Docker image combining Nagios Core 4.2.4 with Thruk 3.22. Built on Debian Bookworm.

## Usage

```bash
docker run -d \
  -p 80:80 \
  -v /your/config:/opt/nagios/etc \
  -v /your/data:/opt/nagios/var \
  -v /your/logs:/var/log/nagios4 \
  ghcr.io/your-org/nagios-thruk
```

Default login: `thrukadmin:thrukadmin`

## What's included

- Nagios Core 4.2.4 (monitoring engine)
- Thruk 3.22 (modern web UI)
- MK Livestatus (real-time query interface)
- Nginx + uWSGI for serving Thruk
- Proper Unix permissions and security defaults

## Directory structure

```
/opt/nagios/
├── etc/          # config files
│   ├── nagios.cfg
│   ├── cgi.cfg
│   └── objects/
├── var/          # runtime data
│   ├── status.dat
│   └── rw/       # sockets, command pipe
└── plugins/      # monitoring plugins
```

## Configuration

Key paths:
- Main config: `/opt/nagios/etc/nagios.cfg`
- Objects: `/opt/nagios/etc/objects/*.cfg`
- Command pipe: `/opt/nagios/var/rw/nagios.cmd`
- Livestatus: `/opt/nagios/var/rw/livestatus`

## Development

```bash
git clone https://github.com/your-org/nagios-thruk
cd nagios-thruk
docker build -t nagios-thruk .
```

## License

GPL (Nagios Core and Thruk are GPL-licensed)
