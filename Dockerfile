FROM ruby:2.6-stretch

WORKDIR /inki
COPY Gemfile /inki
COPY Gemfile.lock /inki
ENV RAILS_ENV production
RUN bundle install -V
RUN ln -s /usr/local/bin/ruby /usr/bin/ruby
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y locales
RUN locale-gen en_US.UTF-8 && localedef -i en_US -f UTF-8 en_US.UTF-8
COPY . /inki
