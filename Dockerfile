# Use Debian Bookworm as base (provides GLIBC >= 2.33 needed by livestatus.o)
FROM debian:bookworm-slim

# Ensure localhost always resolves to IPv4
RUN echo "127.0.0.1 localhost" > /etc/hosts && \
    echo "::1" >> /etc/hosts

# --- Environment Variables ---
# Nagios ENV VARS
ENV NAGIOSCFG="/opt/nagios/etc/nagios.cfg" \
    CGICFG="/opt/nagios/etc/cgi.cfg" \
    NICENESS=5 \
    NAGIOS_HOME="/opt/nagios/etc" \
    NAGIOS_USER="root" \
    NAGIOS_GROUP="root" \
    NAGIOS_LOG_DIR="/var/lib/nagios4" \
    NAGIOS_LIB_DIR="/var/lib/nagios4" \
    NAGIOS_RUN_DIR="/run/nagios4" \
    NAGIOS_CMD_FILE="/var/lib/nagios4/rw/nagios.cmd" \
    NAGIOS_PLUGIN_DIR="/usr/lib/nagios/plugins" \
    LIVESTATUS_SOCKET="/var/lib/nagios4/rw/livestatus" \
    THRUK_VERBOSE="2" \
    NRDP_MICRO_CONFIG="/etc/nrdp_micro/config.yaml"

# Install base dependencies first
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget ca-certificates procps sed python3 mailutils curl psmisc apache2-utils \
    nagios-plugins-standard nagios-plugins-basic \
    perl nginx-core uwsgi uwsgi-plugin-psgi \
    liblwp-protocol-https-perl libgd3 libmariadb3 libcpanel-json-xs-perl \
    libdate-calc-perl libplack-perl libdate-manip-perl libcrypt-rijndael-perl \
    libdigest-sha-perl libwww-perl liburi-perl libhtml-parser-perl \
    liblog-log4perl-perl libtemplate-perl \
    supervisor cron logrotate \
    build-essential cpanminus \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

# Install Mozilla::CA using cpanminus (needed for Thruk::UserAgent)
RUN cpanm Mozilla::CA


# --- Thruk Setup ---
# Thruk ARG VARS (keep args for potential build-time override)
ARG THRUK_VERSION=3.22
ARG DEB_DIST=debian12
ARG DEB_ARCH=amd64
ARG OSUSE_REPO_URL=https://download.opensuse.org/repositories/home:/naemon/Debian_12/amd64
ARG THRUK_BASE_FILE=thruk-base_${THRUK_VERSION}-1_${DEB_ARCH}.deb
ARG LIBTHRUK_FILE=libthruk_3.20-1_${DEB_ARCH}.deb
ARG DEB_URL_BASE=${OSUSE_REPO_URL}

RUN echo "Downloading Thruk Base from ${DEB_URL_BASE}/${THRUK_BASE_FILE}" && \
    wget --no-verbose "${DEB_URL_BASE}/${THRUK_BASE_FILE}" -O /tmp/${THRUK_BASE_FILE} && \
    echo "Downloading LibThruk from ${DEB_URL_BASE}/${LIBTHRUK_FILE}" && \
    wget --no-verbose "${DEB_URL_BASE}/${LIBTHRUK_FILE}" -O /tmp/${LIBTHRUK_FILE} && \
    echo "Installing Thruk packages..." && \
    dpkg --force-depends -i /tmp/${THRUK_BASE_FILE} /tmp/${LIBTHRUK_FILE} || true && \
    echo "Fixing dependencies..." && \
    apt-get install -y -f --no-install-recommends && \
    echo "Cleaning up..." && \
    rm /tmp/${THRUK_BASE_FILE} /tmp/${LIBTHRUK_FILE} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- Thruk Post-Install Setup ---
COPY htpasswd /etc/thruk/htpasswd

# Create symlink for cgi.cfg within app directory
RUN ln -sf ${CGICFG} /usr/share/thruk/cgi.cfg

# Copy local Thruk configuration overrides
COPY thruk_local.conf /etc/thruk/thruk_local.conf

# --- Nginx Setup ---
COPY nginx/thruk.conf /etc/nginx/sites-available/thruk
RUN ln -sf /etc/nginx/sites-available/thruk /etc/nginx/sites-enabled/thruk && \
    rm -f /etc/nginx/sites-enabled/default

# --- uWSGI Setup ---
RUN mkdir -p /etc/uwsgi/apps-available /etc/uwsgi/apps-enabled /var/log/uwsgi /var/run/thruk
COPY uwsgi/thruk.ini /etc/uwsgi/apps-available/thruk.ini
RUN ln -s /etc/uwsgi/apps-available/thruk.ini /etc/uwsgi/apps-enabled/thruk.ini

# --- Nagios Setup ---
RUN mkdir -p /var/lib/nagios4/rw \
             /var/lib/nagios4/spool/checkresults \
             /var/lib/nagios4/archives \
             ${NAGIOS_RUN_DIR} \
             /usr/local/lib/mk-livestatus \
             /opt/nagios.template \
             /usr/local/nagios/var \
             /var/log/nagios4 \
             /var/log/nagios4/archives

# Copy configs to template directory first
COPY etc/ /opt/nagios.template/etc/

# Copy template to actual location (Done in entrypoint.sh)
RUN mkdir -p ${NAGIOS_HOME}

COPY bin/nagios /usr/sbin/nagios4
COPY lib/livestatus.o /usr/local/lib/mk-livestatus/livestatus.o
RUN chmod +x /usr/sbin/nagios4

# --- nrdp-micro Setup ---
COPY nrdp-micro /nrdp-micro
RUN cd /nrdp-micro && go build -o /usr/local/bin/nrdp_micro main.go && \
    mkdir -p /var/spool/nagios/nrdp /var/lib/nrdp_micro /etc/nagios/conf.d/nrdp_hosts /etc/nrdp_micro

COPY nrdp_micro.yaml ${NRDP_MICRO_CONFIG}

# --- Set permissions for Thruk runtime/cache directories ---
RUN mkdir -p /var/cache/thruk

# --- Supervisor Setup ---
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN mkdir -p /var/log/supervisor

# --- Ports and Command ---
EXPOSE 80

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]