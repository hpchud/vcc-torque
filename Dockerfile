FROM hpchud/vcc-base-centos:systemd

# install packages required
RUN yum -y install make libtool openssl-devel libxml2-devel boost-devel gcc gcc-c++ git nano openssh-server openssh-clients gcc-gfortran

# build and install torque 5 in one step
WORKDIR /
RUN git clone https://github.com/adaptivecomputing/torque.git -b 5.1.1.2 torque-src \
	&& cd torque-src \
	&& ./autogen.sh \
	&& ./configure --prefix=/usr --disable-posixmemlock --disable-cpuset \
	&& make \
	&& make install \
	&& cp contrib/systemd/trqauthd.service /etc/systemd/system/ \
	&& cp contrib/systemd/pbs_server.service /etc/systemd/system/ \
	&& cp contrib/systemd/pbs_mom.service /etc/systemd/system/ \
	&& ldconfig \
	&& cd .. \
	&& cp torque-src/torque.setup . \
	&& rm -r torque-src

# torque config
# we don't have interaction so need to fix setup script
RUN sed -i 's/-t create/-t create -f/' torque.setup \
	&& ./torque.setup root localhost \
	&& qmgr -c "set server auto_node_np=true" \
	&& rm torque.setup

# build and install pdsh
RUN cd /tmp \
	&& git clone https://github.com/grondo/pdsh.git pdsh-build \
	&& cd pdsh-build \
	&& git checkout -q e1c8e71dd6a26b40cd067a8322bd14e10e4f7ded \
	&& ./configure --with-ssh --without-rsh --prefix=/usr --with-machines=/etc/vcc/pdsh_machines \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /tmp/pdsh-build

# build and install MAUI
RUN cd /tmp \
	&& git clone https://github.com/jbarber/maui.git maui-build \
	&& cd maui-build \
	&& git checkout -q 7a8513a1317afd57afab6f800d0c15f124d6083f \
	&& ./configure --with-pbs \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /tmp/maui-build
ADD maui-config.sh /etc/vcc/maui-config.sh
ADD units/maui.service /etc/systemd/system/maui.service

# build and install mpich
RUN cd /tmp \
	&& curl -O https://www.mirrorservice.org/sites/distfiles.macports.org/mpich/mpich-3.2.tar.gz \
	&& tar xf mpich-*.tar.gz \
	&& cd mpich-* \
	&& ./configure \
	&& make \
	&& make install \
	&& cd / \
	&& rm -rf /tmp/mpich-*

# make links for maui tools
RUN ln -s /usr/local/maui/bin/showq /usr/bin/showq
RUN ln -s /usr/local/maui/bin/showbf /usr/bin/showbf
RUN ln -s /usr/local/maui/bin/showres /usr/bin/showres
RUN ln -s /usr/local/maui/bin/checkjob /usr/bin/checkjob

# install vcc configuration files
ADD cluster.yml /etc/cluster.yml
ADD services.yml /etc/services.yml
ADD dependencies.yml /etc/vcc/dependencies.yml

# cluster hook scripts
ADD hooks/pbsnodes.sh /etc/vcc/cluster-hooks.d/pbsnodes.sh
ADD hooks/pdsh.sh /etc/vcc/cluster-hooks.d/pdsh.sh
RUN chmod +x /etc/vcc/cluster-hooks.d/*

# service hook scripts
ADD hooks/headnode.sh /etc/vcc/service-hooks.d/headnode.sh
RUN chmod +x /etc/vcc/service-hooks.d/*

# set up SSH config
ADD sshd_config /etc/ssh/sshd_config
RUN echo -e "\tPort 2222" >> /etc/ssh/ssh_config
RUN echo -e "\tStrictHostKeyChecking no" >> /etc/ssh/ssh_config
RUN echo -e "\tUserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config
RUN systemctl enable sshd

# install sshfs
RUN yum -y makecache fast
RUN yum -y install epel-release
RUN yum -y install sshfs

# set up /cluster shared folder
RUN mkdir /cluster

# add the units and configure for services
RUN mkdir /etc/systemd/system/trqauthd.service.d
RUN mkdir /etc/systemd/system/pbs_server.service.d
RUN mkdir /etc/systemd/system/pbs_mom.service.d
RUN mkdir /etc/systemd/system/maui.service.d

ADD units/required-by-vcc.conf /etc/systemd/system/trqauthd.service.d/required-by-vcc.conf
ADD units/required-by-vcc.conf /etc/systemd/system/pbs_server.service.d/required-by-vcc.conf
ADD units/required-by-vcc.conf /etc/systemd/system/pbs_mom.service.d/required-by-vcc.conf
ADD units/required-by-vcc.conf /etc/systemd/system/maui.service.d/required-by-vcc.conf

ADD units/headnode-service.conf /etc/systemd/system/pbs_server.service.d/headnode-service.conf
ADD units/headnode-service.conf /etc/systemd/system/maui.service.d/headnode-service.conf

ADD units/workernode-service.conf /etc/systemd/system/pbs_mom.service.d/workernode-service.conf

ADD units/cluster-sshfs.service /etc/systemd/system/cluster-sshfs.service

ADD units/server_name.conf /etc/systemd/system/pbs_server.service.d/server_name.conf

RUN systemctl enable trqauthd.service \
	pbs_server.service \
	pbs_mom.service \
	maui.service \
	cluster-sshfs.service

RUN ln -s /etc/systemd/system/trqauthd.service /etc/systemd/system/vcc-services.target.requires/trqauthd.service \
	&& ln -s /etc/systemd/system/pbs_server.service /etc/systemd/system/vcc-services.target.requires/pbs_server.service \
	&& ln -s /etc/systemd/system/pbs_mom.service /etc/systemd/system/vcc-services.target.requires/pbs_mom.service \
	&& ln -s /etc/systemd/system/maui.service /etc/systemd/system/vcc-services.target.requires/maui.service