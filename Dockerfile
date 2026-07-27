# syntax=docker/dockerfile:1
#
# CS3100 Paradigms of Programming — IIT Madras 2026
# OCaml 4.10.0 + ocaml-jupyter classroom image.
#
# Design goals:
#   * Reproducible: base image (pinned by digest) + opam package + pip
#     packages are all version-pinned.
#   * Self-contained at RUNTIME: notebooks are baked into the image and the
#     kernel is prebuilt, so `docker run` needs NOTHING from github.com
#     (github is blacklisted on the lab machines). github/opam are used at
#     BUILD time only.
#   * Same UX as the predecessor kartiknagar/cs3100_o23:latest — one
#     `docker run -it -p 8888:8888 ...` and the notebook is reachable at
#     http://127.0.0.1:8888 with no token/password friction.
#
# Build (from the repo root):
#   docker buildx build --platform linux/amd64 -t durwasa/cs3100_o26 .
# Run (offline, no volume needed — notebooks are baked in):
#   docker run -it -p 8888:8888 durwasa/cs3100_o26
# Run (mounting the host repo so saved edits persist to disk):
#   docker run -it -p 8888:8888 -v "$(pwd)":/cs3100_o26 durwasa/cs3100_o26

# --- Base image -------------------------------------------------------------
# Official ocaml/opam image with OCaml 4.10 prebuilt on Debian 11 (bullseye).
# Debian 11 is still served from the main mirrors (buster/Debian 10 is EOL and
# removed from deb.debian.org, which breaks `apt-get update`). Python is 3.9,
# and bullseye's pip is not PEP-668 "externally managed", so system-wide
# `pip install` works without extra flags.
#
# Pinned to the linux/amd64 manifest-list digest so `docker pull` yields an
# identical, working env on any x86_64 Linux lab machine. To refresh the base,
# replace the digest with the one from:
#   docker buildx imagetools inspect ocaml/opam:debian-11-ocaml-4.10
FROM --platform=linux/amd64 ocaml/opam:debian-11-ocaml-4.10@sha256:8c2e175f5ba3483eb4b4fad76423188d3af48b838b86e526cb2111d526740ed5

# --- OS-level build dependencies -------------------------------------------
# ocaml/opam images default to the non-root 'opam' user with passwordless
# sudo. ocaml-jupyter needs ZeroMQ (libzmq3-dev) and the usual C toolchain
# bits; the notebook server needs python3 + pip; curl is only for HEALTHCHECK.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        libzmq3-dev \
        libgmp-dev \
        libffi-dev \
        m4 \
        pkg-config \
        zlib1g-dev \
        curl \
    && rm -rf /var/lib/apt/lists/*

# --- ocaml-jupyter kernel: opam build (SLOW, STABLE) -----------------------
# Build ocaml-jupyter (opam package name 'jupyter') as the non-root 'opam' user
# (opam refuses to run as root). The base image ships opam 2.0 with a LOCAL,
# pinned opam-repository snapshot (git+file:///home/opam/opam-repository), so
# `opam update` touches NO network and the resolved package set is fixed by the
# base-image digest — deterministic without an explicit version pin. opam 2.0
# performs no automatic depext, and every C dependency ocaml-jupyter needs
# (libzmq3-dev for ZeroMQ, libgmp-dev for zarith, libffi-dev, m4, pkg-config,
# zlib1g-dev) is already apt-installed above.
#
# This layer is placed BEFORE the pip layer so that iterating on the Python
# pins below does not invalidate (and re-trigger, under slow amd64 emulation)
# this OCaml compile.
USER opam
RUN opam update \
    && opam install -y jupyter

# --- Jupyter (Python side) --------------------------------------------------
# Classic Notebook stack (notebook < 7) pinned to a Python-3.9-compatible,
# mutually-coherent set so the classic UI behaves like the 2023 predecessor
# image. Pins matter beyond reproducibility here: some 2025+ releases of
# transitive deps (notably fastjsonschema) use `X | Y` type-union syntax that
# only parses on Python >= 3.10 and crash at IMPORT on this 3.9 base; and
# jsonschema >= 4.18 pulls the referencing/rpds-py stack, so jsonschema is held
# at 4.17.x (pyrsistent-based) to avoid dragging in those newer packages.
USER root
RUN python3 -m pip install --no-cache-dir --upgrade "pip==22.3.1" \
    && python3 -m pip install --no-cache-dir \
        "notebook==6.4.12" \
        "jupyter-client==7.4.9" \
        "jupyter-core==4.11.2" \
        "ipython==7.34.0" \
        "ipykernel==6.16.2" \
        "tornado==6.2" \
        "pyzmq==24.0.1" \
        "jinja2==3.0.3" \
        "MarkupSafe==2.1.1" \
        "traitlets==5.9.0" \
        "nbconvert==6.5.4" \
        "nbformat==5.7.0" \
        "nbclient==0.7.0" \
        "jsonschema==4.17.3" \
        "fastjsonschema==2.16.3" \
        "pyrsistent==0.19.2" \
        "attrs==22.2.0" \
        "mistune==0.8.4" \
        "lxml==4.9.4"

# --- Register the OCaml kernelspec -----------------------------------------
# ocaml-jupyter does not ship a ready-made kernelspec: `ocaml-jupyter-opam-genspec`
# (an opam-installed binary, hence `opam exec --`) GENERATES it into
# $(opam config var share)/jupyter, which we then register for the 'opam' user
# (the same user that runs the notebook server at runtime) with --user, so the
# "OCaml 4.10.0" kernel is listed. Runs after pip so the system `jupyter` binary
# exists. `opam clean` is deferred to here (after the spec is generated) so it
# cannot prune the freshly generated share/jupyter tree.
# `jupyter kernelspec list` fails the build if the kernel did not register.
USER opam
RUN opam exec -- ocaml-jupyter-opam-genspec \
    && jupyter kernelspec install --user --name ocaml-jupyter "$(opam config var share)/jupyter" \
    && jupyter kernelspec list \
    && opam clean -c

# --- Bake the course notebooks into the image ------------------------------
# The README mounts the host repo to /cs3100_o26, so we use that as WORKDIR and
# also bake a copy there. This makes the image fully usable WITHOUT any volume
# mount (offline classroom use); a bind mount simply overlays these files.
# Ownership is set to 'opam' so the non-root runtime user can also create new
# notebooks when running without a volume mount.
USER root
WORKDIR /cs3100_o26
COPY --chown=opam:opam Lectures/ /cs3100_o26/Lectures/
COPY --chown=opam:opam README.md LICENSE /cs3100_o26/
RUN chown -R opam:opam /cs3100_o26

# --- Runtime ---------------------------------------------------------------
# Run the notebook server as the non-root 'opam' user. `opam exec --` puts the
# OCaml 4.10 switch on PATH for the server and the kernel subprocess it spawns,
# deterministically (no reliance on login-shell rc hooks).
USER opam
ENV JUPYTER_ENABLE_LAB=no
EXPOSE 8888

# Classroom UX: bind all interfaces, no token, no password — matches the
# predecessor image so students just open http://127.0.0.1:8888.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8888/api || exit 1

CMD ["opam", "exec", "--", "jupyter", "notebook", \
     "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--NotebookApp.token=", "--NotebookApp.password=", \
     "--NotebookApp.notebook_dir=/cs3100_o26"]
