# Dockerfile
FROM brinkmanlab/psortb_commandline:1.0.2

COPY psort.sh /
RUN ln -s /psort.sh /usr/local/bin/psort

RUN chmod +x /usr/local/bin/psort

ENTRYPOINT ["/bin/bash","/psort.sh"]
