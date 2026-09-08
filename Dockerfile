FROM node:22-slim AS frontend
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM ruby:3.4-slim AS gems
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment true && bundle install --jobs 4

FROM ruby:3.4-slim
RUN apt-get update -qq && apt-get install --no-install-recommends -y libpq5 curl && rm -rf /var/lib/apt/lists/* && groupadd -r app && useradd -r -g app app
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=true
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=gems /app/vendor/bundle /app/vendor/bundle
COPY --chown=app:app . .
COPY --from=frontend --chown=app:app /frontend/dist/ ./public/
RUN mkdir -p storage tmp/pids log /home/app && chown -R app:app storage tmp log /home/app
USER app
EXPOSE 3000
ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
