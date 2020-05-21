FROM alpine:3.9
RUN apk --no-cache add git openssh bash curl
WORKDIR /app
VOLUME /repos

ADD . /app
ENTRYPOINT [ "./tag-latest-release.sh" ]