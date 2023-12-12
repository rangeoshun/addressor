FROM ruby:3.3-rc

RUN apt update && \
    apt install -y zlib1g-dev libprotobuf-c-dev

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock

WORKDIR /app

RUN bundle

