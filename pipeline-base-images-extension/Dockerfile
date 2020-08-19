FROM ibmcom/pipeline-base-image:latest

# https://www.vultr.com/docs/installing-docker-ce-on-ubuntu-16-04
# Step 1 and step 2
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Step 3 and additional step - add complementary tools (nc)
RUN apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io && \
    apt-get -q clean && \
    rm -rf /var/lib/apt/lists 

RUN systemctl enable docker