ARG BASE_IMAGE=dlrobson/dotfiles:latest

FROM debian:bullseye-slim AS chktex

###############################################################################
# Install chktex
###############################################################################
ARG CHKTEX_VERSION=1.7.6

WORKDIR /tmp/workdir
RUN apt-get update && \
    apt-get install -y --no-install-recommends g++ make wget 
RUN wget -qO- http://download.savannah.gnu.org/releases/chktex/chktex-${CHKTEX_VERSION}.tar.gz | \
    tar -xz --strip-components=1
RUN ./configure && \
    make && \
    mv chktex /tmp && \
    rm -r *

###############################################################################
# Setup base image
###############################################################################
FROM $BASE_IMAGE

ARG UID=1000
ARG GID=1000
ARG USERNAME=ubuntu

USER root

# If the User does not exist, create it
# Otherwise, If the UID is not equal to the specified UID, run a usermod command to change
# the UID.
RUN if ! id -u ${USERNAME} > /dev/null 2>&1; then \
    group add -g ${GID} ${USERNAME} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd; \
    elif [ $(id -u ${USERNAME}) -ne ${UID} ]; then \
    usermod -u ${UID} ${USERNAME} && \
    echo "UID updated to ${UID}"; \
    else echo "User ${USERNAME} already has UID ${UID}"; \
    fi

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # For texlive
    wget gnupg \
    # For latexindent dependencies
    cpanminus make gcc libc6-dev && \
    apt-get autoremove -y && \
    apt-get purge -y --auto-remove && \
    apt-get clean

# Install latexindent dependencies
RUN cpanm -n -q Log::Log4perl XString Log::Dispatch::File YAML::Tiny File::HomeDir Unicode::GCString

###############################################################################
# Install texlive
###############################################################################
ARG SCHEME=scheme-basic
ARG DOCFILES=0
ARG SRCFILES=0
ARG TEXLIVE_VERSION=2023
ARG TEXLIVE_MIRROR=http://ctan.math.utah.edu/ctan/tex-archive/systems/texlive/tlnet

RUN mkdir -p -m 777 /tmp/texlive /usr/local/texlive
USER ${USERNAME}
RUN cd /tmp/texlive && \
    wget -qO- ${TEXLIVE_MIRROR}/install-tl-unx.tar.gz | \
    tar -xz --strip-components=1 && \
    export TEXLIVE_INSTALL_NO_CONTEXT_CACHE=1 && \
    export TEXLIVE_INSTALL_NO_WELCOME=1 && \
    printf "selected_scheme ${SCHEME}\ninstopt_letter 0\ntlpdbopt_autobackup 0\ntlpdbopt_desktop_integration 0\ntlpdbopt_file_assocs 0\ntlpdbopt_install_docfiles ${DOCFILES}\ntlpdbopt_install_srcfiles ${SRCFILES}" > profile.txt && \
    perl install-tl -profile profile.txt --location ${TEXLIVE_MIRROR}

###############################################################################
# Cleanup
###############################################################################
USER root
RUN apt-get purge -y --auto-remove \
    cpanminus make gcc libc6-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/texlive /usr/local/texlive/${TEXLIVE_VERSION}/*.log

###############################################################################
# Setup user
###############################################################################
USER ${USERNAME}

ENV PATH ${PATH}:/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:/usr/local/texlive/${TEXLIVE_VERSION}/bin/aarch64-linux

COPY --from=chktex /tmp/chktex /usr/local/bin/chktex

RUN tlmgr install latexindent latexmk && \
    texhash && \
    rm /usr/local/texlive/${TEXLIVE_VERSION}/texmf-var/web2c/*.log && \
    rm /usr/local/texlive/${TEXLIVE_VERSION}/tlpkg/texlive.tlpdb.main.*

# Verify binaries work and have the right permissions
RUN tlmgr version && \
    latexmk -version && \
    texhash --version && \
    chktex --version