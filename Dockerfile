# Prepare the base environment.
FROM ubuntu:20.04 as builder_base_parkpasses
MAINTAINER asi@dbca.wa.gov.au

ARG DEBIAN_FRONTEND=noninteractive
#ENV DEBUG=True
ENV TZ=Australia/Perth
ENV EMAIL_HOST="smtp.corporateict.domain"
ENV DEFAULT_FROM_EMAIL='no-reply@dbca.wa.gov.au'
ENV NOTIFICATION_EMAIL='oak.mcilwain@dbca.wa.gov.au'
ENV NON_PROD_EMAIL='none@none.com'
ENV PRODUCTION_EMAIL=False
ENV EMAIL_INSTANCE='DEV'
ENV SECRET_KEY="ThisisNotRealKey"
ENV SITE_PREFIX='lals-dev'
ENV SITE_DOMAIN='dbca.wa.gov.au'
ENV OSCAR_SHOP_NAME='Parks & Wildlife'
ENV BPAY_ALLOWED=False
ARG BRANCH
ARG REPO
ARG REPO_NO_DASH

RUN echo "ENV VARS"
RUN echo $BRANCH
RUN echo $REPO
RUN echo $REPO_NO_DASH


RUN apt-get clean
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install --no-install-recommends -y curl wget git libmagic-dev gcc binutils libproj-dev gdal-bin
RUN apt-get -y install ca-certificates
RUN update-ca-certificates

WORKDIR /app
#RUN mkdir ~/.ssh/
#RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
#RUN git clone -v -b $BRANCH git@github.com:mintcoding/$REPO.git .
RUN git clone -v -b $BRANCH https://github.com/dbca-wa/$REPO.git .

RUN apt-get install --no-install-recommends -y sqlite3 vim postgresql-client ssh htop libspatialindex-dev
RUN apt-get install --no-install-recommends -y python3-setuptools python3-dev python3-pip tzdata libreoffice cron rsyslog python3.8-venv gunicorn
RUN apt-get install --no-install-recommends -y libpq-dev patch
RUN apt-get install --no-install-recommends -y postgresql-client mtr
RUN apt-get install --no-install-recommends -y python-pil
# install node 16
RUN touch install_node.sh
RUN curl -fsSL https://deb.nodesource.com/setup_16.x -o install_node.sh
RUN chmod +x install_node.sh && ./install_node.sh
RUN apt-get install -y nodejs
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN pip install --upgrade pip

#WORKDIR /app
#RUN git clone -b $BRANCH https://github.com/dbca-wa/$REPO.git .

ENV POETRY_VERSION=1.1.13
RUN pip install "poetry==$POETRY_VERSION"
RUN poetry config virtualenvs.create false \
  && poetry install --no-dev --no-interaction --no-ansi

RUN touch /app/rand_hash
RUN git pull && cd $REPO_NO_DASH/frontend/$REPO_NO_DASH/
RUN npm run build && cd /app
RUN python manage.py collectstatic --no-input
RUN git log --pretty=medium -30 > ./git_history_recent

# Install the project (ensure that frontend projects have been built prior to this step).
COPY ./timezone /etc/timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Patch also required on local environments after a venv rebuild
# (in local) patch /home/<username>/park-passes/.venv/lib/python3.8/site-packages/django/contrib/admin/migrations/0001_initial.py admin.patch.additional
RUN patch /usr/local/lib/python3.8/dist-packages/django/contrib/admin/migrations/0001_initial.py /app/admin.patch.additional

COPY ./cron /etc/cron.d/dockercron
RUN service rsyslog start
RUN chmod 0644 /etc/cron.d/dockercron
RUN crontab /etc/cron.d/dockercron
RUN touch /var/log/cron.log
RUN service cron start
RUN chmod 755 /startup.sh
RUN touch /app/.env
EXPOSE 8080
HEALTHCHECK --interval=1m --timeout=5s --start-period=10s --retries=3 CMD ["wget", "-q", "-O", "-", "http://localhost:8080/"]
CMD ["/startup.sh"]
