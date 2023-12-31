# Use imutable image tags rather than mutable tags (like ubuntu:20.04)
FROM ubuntu:focal-20220531
# Some tools like yamllint need this
# Pip needs this as well at the moment to install ansible
# (and potentially other packages)
# See: https://github.com/pypa/pip/issues/10219
ENV VAGRANT_VERSION=2.3.4 \
    VAGRANT_DEFAULT_PROVIDER=libvirt \
    VAGRANT_ANSIBLE_TAGS=facts \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

RUN apt update -q \
    && apt install -yq \
         libssl-dev \
         python3-dev \
         python3-pip \
         sshpass \
         apt-transport-https \
         jq \
         moreutils \
         libvirt-dev \
         openssh-client \
         rsync \
         git \
         ca-certificates \
         curl \
         gnupg2 \
         software-properties-common \
         unzip \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt update -q \
    && apt install --no-install-recommends -yq docker-ce \
    && apt autoremove -yqq --purge && apt clean && rm -rf /var/lib/apt/lists/* /var/log/*

WORKDIR /kubespray
COPY . .

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && pip install --no-compile --no-cache-dir pip -U \
    && pip install --no-compile --no-cache-dir -r tests/requirements.txt -r requirements.txt \
    && KUBE_VERSION=$(sed -n 's/^kube_version: //p' roles/kubespray-defaults/defaults/main.yaml) \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/$KUBE_VERSION/bin/linux/$(dpkg --print-architecture)/kubectl -o /usr/local/bin/kubectl \
    && echo $(curl -L https://storage.googleapis.com/kubernetes-release/release/$KUBE_VERSION/bin/linux/$(dpkg --print-architecture)/kubectl.sha256) /usr/local/bin/kubectl | sha256sum --check \
    && chmod a+x /usr/local/bin/kubectl \
    # Install Vagrant
    && curl -LO https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && dpkg -i vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && rm vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && vagrant plugin install vagrant-libvirt \
    # Install Kubernetes collections
    && pip install --no-compile --no-cache-dir kubernetes \
    && ansible-galaxy collection install kubernetes.core \
    # Clean cache python
    && find / -type d -name '*__pycache__' -prune -exec rm -rf {} \;
