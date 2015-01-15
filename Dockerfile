FROM dockerfile/java:oracle-java8
RUN      apt-get -y update
RUN      apt-get -y upgrade


# ---------------- #
#   Installation   #
# ---------------- #

# Install all prerequisites
RUN     apt-get -y install software-properties-common
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get -y update
RUN     apt-get -y install python-django-tagging python-simplejson python-memcache python-ldap python-cairo python-pysqlite2 python-support \
                           python-pip gunicorn supervisor nginx-light nodejs git wget curl build-essential python-dev

# Elasticsearch
RUN \
    wget -qO - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - && \
    if ! grep "elasticsearch" /etc/apt/sources.list; then echo "deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main" >> /etc/apt/sources.list;fi && \
    apt-get update

RUN \
    apt-get install -y elasticsearch && \
    apt-get clean && \
    sed -i '/#cluster.name:.*/a cluster.name: grafana' /etc/elasticsearch/elasticsearch.yml && \
    sed -i '/#path.data: \/path\/to\/data/a path.data: /data' /etc/elasticsearch/elasticsearch.yml



# Install Whisper, Carbon and Graphite-Web
RUN     pip install Twisted==11.1.0
RUN     pip install Django==1.5
RUN     pip install whisper==0.9.12
RUN     pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/lib" carbon==0.9.12
RUN     pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/webapp" graphite-web==0.9.12




# --------------------------------------- #
#   Install & Patch StatsD and Grafana    #
# --------------------------------------- #

#  We are patching StatsD and Grafana to play nice with url-encoded metric names, that makes the dashboard more usable when displaying
#  metrics names for actors, http traces and dispatchers.

# Install & Patch StatsD
RUN     mkdir /src                                                                                                                      &&\
        git clone https://github.com/etsy/statsd.git /src/statsd                                                                        &&\
        cd /src/statsd                                                                                                                  &&\
        git checkout v0.7.2                                                                                                             &&\
        sed -i -e "s|.replace(/\[^a-zA-Z_\\\\-0-9\\\\.]/g, '');|.replace(/[^a-zA-Z_\\\\-0-9\\\\.\\\\%]/g, '');|" /src/statsd/stats.js




# Install & Patch Grafana
RUN     mkdir /src/grafana                                                                                                              &&\
        git clone https://github.com/grafana/grafana.git /src/grafana                                                                   &&\
        cd /src/grafana                                                                                                                 &&\
        git checkout v1.9.1


RUN     cd /src/grafana                                                                                                                 &&\
        npm install                                                                                                                     &&\
        npm install -g grunt-cli                                                                                                        &&\
        grunt build






# Configure nginx and supervisord
ADD     ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD     ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


ADD     ./grafana/config.js /src/grafana/dist/config.js
ADD     ./grafana/default-dashboard.json /src/grafana/dist/app/dashboards/default.json

ADD     ./statsd/config.js /src/statsd/config.js

ADD     ./graphite/initial_data.json /var/lib/graphite/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py /var/lib/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf /var/lib/graphite/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf /var/lib/graphite/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf /var/lib/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /var/lib/graphite/storage/whisper
RUN     touch /var/lib/graphite/storage/graphite.db /var/lib/graphite/storage/index
RUN     chown -R www-data /var/lib/graphite/storage
RUN     chmod 0775 /var/lib/graphite/storage /var/lib/graphite/storage/whisper
RUN     chmod 0664 /var/lib/graphite/storage/graphite.db
RUN     cd /var/lib/graphite/webapp/graphite && python manage.py syncdb --noinput


ADD etc/supervisor/conf.d/elasticsearch.conf /etc/supervisor/conf.d/elasticsearch.conf
ADD etc/supervisor/conf.d/carbon-cache.conf /etc/supervisor/conf.d/carbon-cache.conf
ADD etc/supervisor/conf.d/graphite-webapp.conf /etc/supervisor/conf.d/graphite-webapp.conf
ADD etc/supervisor/conf.d/nginx.conf /etc/supervisor/conf.d/nginx.conf
ADD etc/supervisor/conf.d/statsd.conf /etc/supervisor/conf.d/statsd.conf


# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80

# StatsD UDP port
EXPOSE  8125/udp

# StatsD Management port
EXPOSE  8126

EXPOSE  9200




# -------- #
#   Run!   #
# -------- #

CMD     ["/usr/bin/supervisord"]
