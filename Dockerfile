# Copyright (c) 2022-2025, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


FROM registry.conarx.tech/containers/alpine/3.22 as builder


ENV VAULTWARDEN_VER=1.35.2

# NK: Take note of the versions!!!
# https://github.com/dani-garcia/vaultwarden/blob/main/docker/Dockerfile.debian#L21
ENV VAULTWARDEN_WEB_VER=2025.12.1.1

# https://github.com/dani-garcia/vaultwarden/blob/main/docker/Dockerfile.debian#L39
ENV RUST_VER=1.92.0



# Install libs we need
RUN set -eux; \
	true "Installing build dependencies"; \
	apk add --no-cache \
		build-base \
		curl \
		git \
		\
		openssl-dev openssl-libs-static \
		pkgconf \
		libpq-dev \
		mariadb-dev mariadb-static \
		sqlite-dev sqlite-libs sqlite-static \
		zlib-static \
		\
		nodejs npm


# Download Rust
RUN set -eux; \
	mkdir build; \
	cd build; \
	true "Downloading Rust"; \
	# Grab VaultWarden
	curl -L "https://static.rust-lang.org/dist/rust-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" \
		-o "rust-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz"; \
	\
	curl -L "https://static.rust-lang.org/dist/rust-std-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" \
		-o "rust-std-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz"; \
	\
	curl -L "https://static.rust-lang.org/dist/cargo-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" \
		-o "cargo-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz"

# Install Rust
RUN set -eux; \
	cd build; \
	mkdir /opt/rust; \
	true "Installing Rust to /opt/rust"; \
	tar -zx --strip-components=2 -f "rust-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" -C /opt/rust; \
	tar -zx --strip-components=2 -f "rust-std-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" -C /opt/rust; \
	tar -zx --strip-components=2 -f "cargo-${RUST_VER}-x86_64-unknown-linux-musl.tar.gz" -C /opt/rust

# Prepare linking hacks for building VaultWarden
# NK: This is pretty fucked up, but it doesn't seem Rust wants to link using the libs.private
RUN set -eux; \
	cd build; \
	true "Relinking static libraries"; \
	# NK: Work around libpq linking issue, we need libpgcommon and libpgport
	mkdir libpq; \
	cd libpq; \
	ar -x /usr/lib/libpq.a; \
	ar -x /usr/lib/libpgcommon_shlib.a; \
	ar -x /usr/lib/libpgport_shlib.a; \
	ar -qc libpq.a  *.o; \
	cat libpq.a > /usr/lib/libpq.a; \
	cd ..; \
	# NK: Work around libmysqlclient linking issue, we need libz
	mkdir libmysqlclient; \
	cd libmysqlclient; \
	ar -x /usr/lib/libmysqlclient.a; \
	if [ -e /usr/lib/libz.a ]; then \
		LIBZ_PATH=/usr/lib/libz.a; \
	else \
		LIBZ_PATH=/lib/libz.a; \
	fi; \
	ar -x $LIBZ_PATH; \
	ar -qc libmysqlclient.a  *.o; \
	cat libmysqlclient.a > /usr/lib/libmysqlclient.a; \
	cd ..


# Download VaultWarden
RUN set -eux; \
	mkdir -p build; \
	cd build; \
	true "Downloading VaultWarden"; \
	# Grab VaultWarden
	curl -L "https://github.com/dani-garcia/vaultwarden/archive/refs/tags/${VAULTWARDEN_VER}.tar.gz" \
		-o "vaultwarden-${VAULTWARDEN_VER}.tar.gz"; \
	tar -zxf "vaultwarden-${VAULTWARDEN_VER}.tar.gz"; \
	# Grab VaultWarden Web
	curl -L "https://github.com/vaultwarden/vw_web_builds/archive/refs/tags/v${VAULTWARDEN_WEB_VER}.tar.gz" \
		-o "vw_web_builds-${VAULTWARDEN_WEB_VER}.tar.gz"; \
	tar -zxf "vw_web_builds-${VAULTWARDEN_WEB_VER}.tar.gz"; \
	# Download dependencies
	cd "vaultwarden-$VAULTWARDEN_VER"; \
	export PATH="/opt/rust/bin:$PATH"; \
	cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"; \
	# Install cross-env, needed for node
	npm install cross-env


# Patch VaultWarden web client
RUN set -eux; \
	cd build; \
	cd "vw_web_builds-${VAULTWARDEN_WEB_VER}"; \
	# Fixes
	sed -i -e 's/{{ version }}//' \
		"apps/web/src/app/layouts/frontend-layout.component.html" \
		"libs/components/src/anon-layout/anon-layout.component.html"; \
	# Set much longer timeouts so we don't fail
	npm config set fetch-retries 50; \
	npm config set fetch-retry-mintimeout 120000; \
	npm config set fetch-retry-maxtimeout 900000; \
	if ! npm ci; then \
		cat /root/.npm/_logs/*.log; \
		false; \
	fi; \
	cd apps/web; \
	npm run dist:oss:selfhost


# Build VaultWarden
RUN set -eux; \
	cd build; \
	cd "vaultwarden-$VAULTWARDEN_VER"; \
	\
	# Set up path to point to our Rust build environment
	export PATH="/opt/rust/bin:$PATH"; \
	\
	VW_VERSION="$VAULTWARDEN_VER" cargo build -j $(nproc) --release --frozen --features sqlite,mysql,postgresql


# Install VaultWarden Web and VaultWarden
RUN set -eux; \
	cd build; \
	# Install VaultWarden Web
	mkdir -p vaultwarden-root/usr/local/share/vaultwarden-web; \
	cd "vw_web_builds-${VAULTWARDEN_WEB_VER}"; \
	cp -R apps/web/build/* "../vaultwarden-root/usr/local/share/vaultwarden-web"; \
	cd ..; \
	# Install VaultWarden
	mkdir -p vaultwarden-root/usr/local/bin; \
	cd "vaultwarden-$VAULTWARDEN_VER"; \
	cp target/release/vaultwarden "../vaultwarden-root/usr/local/bin"; \
	cd ..; \
	# Create directories
	mkdir -p vaultwarden-root/etc/vaultwarden; \
	mkdir -p vaultwarden-root/var/lib/vaultwarden


# Strip binaries
RUN set -eux; \
	cd build/vaultwarden-root; \
	scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs \
		strip \
			--remove-section=.comment \
			--remove-section=.note \
			-R .gnu.lto_* -R .gnu.debuglto_* \
			-N __gnu_lto_slim -N __gnu_lto_v1 \
			--strip-unneeded



FROM registry.conarx.tech/containers/postfix/3.22


ARG VERSION_INFO=

LABEL org.opencontainers.image.authors   = "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   = "3.22"
LABEL org.opencontainers.image.base.name = "registry.conarx.tech/containers/postfix/3.22"


# Copy in built binaries
COPY --from=builder /build/vaultwarden-root /


RUN set -eux; \
	true "Utilities"; \
	apk add --no-cache \
		argon2 \
		curl \
		openssl; \
	true "User setup"; \
	addgroup -S vaultwarden 2>/dev/null; \
	adduser -S -D -H -h /var/lib/vaultwarden -s /sbin/nologin -G vaultwarden -g vaultwarden vaultwarden; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# VaultWarden
COPY etc/supervisor/conf.d/vaultwarden.conf /etc/supervisor/conf.d/vaultwarden.conf
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-vaultwarden.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/init.d/42-vaultwarden.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-vaultwarden.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-vaultwarden.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/99-vaultwarden.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/bin/start-vaultwarden /usr/local/bin/start-vaultwarden
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown vaultwarden:vaultwarden \
		/var/lib/vaultwarden; \
	chown root:vaultwarden /etc/vaultwarden; \
	chown root:root \
		/usr/local/bin/start-vaultwarden; \
	chmod 0770 \
		var/lib/vaultwarden; \
	chmod 0750 /etc/vaultwarden; \
	chmod 0755 \
		/usr/local/bin/start-vaultwarden \
		/usr/local/bin/vaultwarden; \
	fdc set-perms


VOLUME ["/var/lib/vaultwarden"]

EXPOSE 8080
