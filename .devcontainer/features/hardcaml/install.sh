#!/bin/sh
set -eu
set -x

echo "Activating feature 'HARDCAML'"

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
UPDATE_RC="${UPDATE_RC:-"true"}"

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS="vscode node codespace $(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)"
    for CURRENT_USER in $POSSIBLE_USERS; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME="${CURRENT_USER}"
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
        if [ -f /etc/bash.bashrc ]; then
            /bin/echo -e "$1" >> /etc/bash.bashrc
        fi
        if [ -f "/etc/zsh/zshrc" ]; then
            /bin/echo -e "$1" >> /etc/zsh/zshrc
        fi
    fi
}

export OPAMROOT="/opt/opam"
export OPAMYES="true"

rc="$(cat << EOF
# >>> HARDCAML >>>
export OPAMROOT="$OPAMROOT"
# <<< HARDCAML <<<
EOF
)"
updaterc "$rc"

sudo apt-get update
sudo apt-get install --no-install-recommends opam ocaml m4 pkg-config libffi-dev

opam init --no-setup --disable-sandboxing
eval $(opam env)
opam install -y depext
PACKAGES=\
 dune\
 hardcaml\
 hardcaml_c\
 hardcaml_circuits\
 hardcaml_verilator\
 hardcaml_waveterm\
 hardcaml_xilinx\
 merlin\
 utop\

opam depext ${PACKAGES}
opam install ${PACKAGES}
opam clean --repo-cache
chown -R ${USERNAME} $OPAMROOT
