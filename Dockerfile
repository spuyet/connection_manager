FROM ruby:latest
RUN mkdir /usr/src/app
ADD . /usr/src/app/
WORKDIR /usr/src/app/
RUN ["bundle", "install"]
