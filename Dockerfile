# DOCKER-VERSION 1.12.3
FROM ens-mirror
MAINTAINER  Richard Challis/Lepbase contact@lepbase.org

ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive

USER root
RUN cpanm Tree::DAG_Node \
        IO::Unread \
        Text::LevenshteinXS \
        Math::SigFigs

WORKDIR /ensembl
USER eguser
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
