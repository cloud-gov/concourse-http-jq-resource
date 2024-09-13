ARG base_image

FROM ${base_image}

RUN apt-get -y upgrade
RUN apt-get install -y wget
  
RUN wget -q -L -O /usr/local/bin/jq "https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64" && \
  chmod +x /usr/local/bin/jq && \
  mkdir -p /opt/resource/logs/    
ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

