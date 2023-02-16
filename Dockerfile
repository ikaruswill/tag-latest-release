FROM alpine:3.17
RUN apk --no-cache add git openssh bash curl
WORKDIR /app
VOLUME /repos

ADD . /app
ENTRYPOINT [ "./tag-latest-release.sh" ]