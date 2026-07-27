# CS3100: Paradigms of Programming (2026)

## Lab machines: `docker pull` fallback (when GitHub is blacklisted)

> **Why this exists:** once the lab opens up, **`github.com` is blacklisted**, so
> the usual setup that clones/pulls this repo from GitHub can fail on the lab
> machines. **Docker Hub is _not_ blacklisted.** A prebuilt, self-contained image
> is published there, so if the manual/script-based install is not working you can
> pull a ready-to-run environment directly from Docker Hub — no GitHub access needed.

The image bundles OCaml 4.10 + the `ocaml-jupyter` kernel + Jupyter Notebook and
**bakes in the course notebooks**, so it works fully offline:

```bash
# 1. Pull the prebuilt image from Docker Hub (not blacklisted in the lab)
$ docker pull durwasa/cs3100_o26:latest

# 2. Run it — notebooks are already inside the image
$ docker run -it -p 8888:8888 durwasa/cs3100_o26:latest
#   (on Linux lab machines you may need: sudo docker run -it -p 8888:8888 durwasa/cs3100_o26:latest)
```

Then open the printed `http://127.0.0.1:8888` URL in a browser and pick the
**OCaml 4.10** kernel. To keep edits on the host disk instead, mount a folder:

```bash
$ docker run -it -p 8888:8888 -v "$(pwd)":/cs3100_o26 durwasa/cs3100_o26:latest
```

This image is produced automatically by the
[`docker-publish`](.github/workflows/docker-publish.yml) GitHub Actions workflow.
Once it is published under the course's own Docker Hub account, replace
`durwasa/cs3100_o26` above with `<course-account>/cs3100_o26`.

## Running the Jupyter notebooks

Install [docker](https://docs.docker.com/install/#supported-platforms) and [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) for your platform. 
Then run the following commands:

```bash
$ git clone https://github.com/kartiknagar/cs3100_o26
$ docker run -it -p 8888:8888 -v "$(pwd)":/lectures kartiknagar/cs3100_o23:latest
$ jupyter notebook --ip=0.0.0.0
```
The second step in the above will download the image from dockerhub 
automatically. About 500MB download and requires about 5GB storage space 
in hard disk when uncompressed. This needs to be done only once.

After the above three steps: copy and paste the displayed URL that starts with `http://127.0.0.1:8888` into
your browser. If you save the changes to the notebook, they are saved locally.
As you go through the course, you will have to do `git pull` in the
`cs3100_o26` directory to get the latest updates from upstream.

## Linux

On Linux, you need at least 5GB free space in the partition in which `/var` lives.
And you need to run the docker command with `sudo`:

```bash
$ sudo docker run -it -p 8888:8888 -v "$(pwd)":/cs3100_o26 kartiknagar/cs3100_o23:latest
```

# Windows

In some windows machines you may have to install `wsl 2`. Follow only `step 4` from this [link](https://docs.microsoft.com/en-us/windows/wsl/install-win10#step-4---download-the-linux-kernel-update-package).
For running the docker step, on Windows, you need to run the docker command as follows:

```bash
$ docker run -it -p 8888:8888 -v PATH:/cs3100_o26 kartiknagar/cs3100_o23:latest
```
where `PATH` in the command should be replaced with the location you cloned the git repo into in the above steps

