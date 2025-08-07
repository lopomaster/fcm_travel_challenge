FROM ruby:3.3.5-slim

LABEL maintainer="lopez.urbina.manuel@gmail.com"
LABEL description="FCM Travel Challenge - Ruby - RSpec - SimpleCov"

RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      git \
      curl \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler:2.5.16 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development' && \
    bundle install --jobs 4 --retry 3

COPY *.rb ./
COPY lib/ ./lib/
COPY extended_segments_samples/ ./extended_segments_samples/
COPY spec/ ./spec/

RUN mkdir -p spec/fixtures coverage tmp

CMD ["ruby"]