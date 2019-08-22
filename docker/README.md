# Readme for Docker-Inki

This readme is about docker-inki and accumulates some information about the build process and how to use.


## Usage

This section describes the usage of docker-inki. Some of it is included in `script--docker-inki-manage`.


### Before Docker-Inki Can Be Run

There are some configuration files that need to be configured before one can run docker-inki (for configuring
inki itself -> [Inki](www.inki.io).
- `cp .env.template .env` and configure if needed (at the moment just Traefik).
- `cp inki_db.env.template inki_db.env` and configure POSTGRESQL usr/pw.


### Build Docker-Inki Image Locally

Just run `docker-compose build` to build the image which can be used to run inki in a docker-container.

To modify the build of the image, edit the Dockerfile. The build process is staged and steps are
cached, thus editing and building an updated version does not necessarily need the full time required
at the first build.
Hint: The most time to build the image is needed to install packages, hence, if installation-section is left
untouched, the build process is quite fast (matter of seconds).


### Run Docker-Inki Image Locally

The provided docker-compose.yml can be run with `docker-compose up [-d]` ("-d" for detach, so no output to
current tty [if needed later on, use `docker attach`, or omit "-d"]).

Standard port to connect to docker-inki is 3000 i.e. browse to "localhost:3000" to access instance.


## RVM Container for INKI


### Nice To Know
- rvm is only available if login shell is used i.e. use `bash -l`.
    - to ssh into running docker-inki-container:
        - `docker exec -it <CONTAINER_ID> bash -l`
        - docker-ssh-loginshell: add this to bashrc to ssh into docker-container via `dsshl <CONTAINER_ID>`
              ` function dsshl() {
                docker exec -it $1 bash -l
              ` }


### TODOs:
[ ] use variable to set listening port for docker-inki-container (would pbly be in .env)?
[ ] YAML safe loading is not available. Please upgrade psych to a version that supports safe loading (>= 2.0).
[ ] unable to convert U+00E9 from UTF-8 to US-ASCII for spec/bundler/bundler_spec.rb, skipping
[ ] tzdata (Time Zone Data) is not set correctly (-2h from vienna), set locale


## Lost + Found


## Notes
- Bundler 1.3.0 does not work anymore (22.08.2019) -> gem install bundler -v '~>1'
[Link](https://makandracards.com/makandra/62887-how-to-install-bundler-for-ruby-2-3)
`
rvm@eb9f628e539f:/var/www/inki$ gem install bundler
Fetching: bundler-2.0.2.gem (100%)
ERROR:  Error installing bundler:
        bundler requires Ruby version >= 2.3.0.
        rvm@eb9f628e539f:/var/www/inki$ gem install bundler -v '~>1'
        Fetching: bundler-1.17.3.gem (100%)
        Successfully installed bundler-1.17.3
        1 gem installed
        Installing ri documentation for bundler-1.17.3...
        Installing RDoc documentation for bundler-1.17.3...
`,
`
RUN gem install bundler:1.3.0
ERROR:  Could not find a valid gem 'bundler:1.3.0' (>= 0) in any repository`
, thus: -> use `gem install bundler -v '~>1'` in Dockerfile instead.


### Dockerfile

1) Option for production? - use curl/wget/git/etc to load a specific version.
`
ARG INKI_VERSION="x.x"
e.g. ARG INKI_URL="https://github.com/wogri/inki/archive/v${INKI_VERSION}.tar.gz"
TODO: [...] && curl -sSL $PASSBOLT_URL | tar zxf - -C . --strip-components 1 \
