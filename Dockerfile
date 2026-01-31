FROM ruby:3.3-alpine AS build
RUN apk add --no-cache build-base git
WORKDIR /site
COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without "test" && \
    bundle install --jobs 4 --retry 3
COPY . .
RUN JEKYLL_ENV=production bundle exec jekyll b

FROM nginx:alpine
COPY --from=build /site/_site /usr/share/nginx/html
