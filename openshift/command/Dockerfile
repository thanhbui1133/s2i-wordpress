FROM centos/mysql-57-centos7:latest
RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -b ~/bin/aws && \
    rm awscli-bundle.zip
ENV PATH="~/bin:${PATH}"
COPY *.sh /var/lib/mysql/bin/
RUN mkdir -p /var/lib/mysql/.aws && chgrp root /var/lib/mysql/.aws && chmod g+rwx /var/lib/mysql/.aws
USER 1001
CMD /bin/bash
