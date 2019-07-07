FROM ruby:1.9.3

RUN apt-get update -yqq \
&& apt-get install -yqq --no-install-recommends \
    nodejs \
    vim-tiny\
    postgresql-client\
    tmux\
    # net-tools\
    # nodejs \
    # nodejs \
&& apt-get -q clean \
&& rm -rf /var/lib/apt/lists


WORKDIR /var/www/inki/
# Setup
COPY ./Gemfile* ./
# RUN gem install bundler:2.0.1  # bundler 2.0.1 is used in Gemfile.
# RUN bundler update --bundler
RUN bundler install

# install inki

# RUN gem install middleman     # install middleman
# RUN ls -liah                # just a test; TODO: remove   
