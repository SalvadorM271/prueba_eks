FROM alpine:3.14

# Install required packages

RUN apk update && apk add --no-cache curl unzip git docker

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install --install-dir /usr/local/bin/aws \
    && rm -rf aws awscliv2.zip






