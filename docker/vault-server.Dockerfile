FROM docker.io/hashicorp/vault-enterprise:1.19-ent

ARG TARGETARCH

USER root
COPY --from=docker.io/vegardit/softhsm2-pkcs11-proxy:latest /usr/local/lib/libpkcs11-proxy* /usr/local/lib/
COPY --from=docker.io/vegardit/softhsm2-pkcs11-proxy:latest /opt/test.tls.psk /opt/test.tls.psk
WORKDIR /tmp/foo
RUN apk add --no-cache opensc curl libc6-compat && \
	curl -SsLo ./vault.zip https://releases.hashicorp.com/vault/1.19.14+ent.hsm/vault_1.19.14+ent.hsm_linux_${TARGETARCH}.zip && \
	unzip ./vault.zip && \
	install -m0755 ./vault /bin/vault
WORKDIR /
RUN rm -rf /tmp/foo
USER vault
