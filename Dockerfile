# DOCKER-VERSION 1.12.3
FROM lepbase/easy-mirror
MAINTAINER  Richard Challis/Lepbase contact@lepbase.org

ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive

USER root
RUN cpanm Tree::DAG_Node \
        IO::Unread \
        Text::LevenshteinXS \
        Math::SigFigs

RUN apt-get update && apt-get install -y parallel

WORKDIR /ensembl
USER eguser
ARG cachebuster=0b56f064
RUN git clone -b develop --recursive https://github.com/lepbase/easy-import

USER root
RUN mkdir /import
COPY startup.sh /import/

WORKDIR /import
RUN mkdir blast
RUN mkdir conf
RUN mkdir download
RUN mkdir meta
RUN mkdir data
WORKDIR data

#CMD ["/import/startup.sh", $FLAGS, "-d", $DATABASE]
CMD /import/startup.sh $FLAGS
