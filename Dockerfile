FROM ${YOUR_BASE_IMAGE} 

ENV TZ=Asia/Seoul
ARG DEBIAN_FRONTEND=noninteractive
ARG USER_ID
ARG USER_NAME
ARG USER_HOME

RUN apt-get update
RUN apt install -y sudo zsh ssh git
RUN chsh -s /usr/bin/zsh

RUN useradd -rm -d /home/${USER_NAME} -s /bin/zsh -u ${USER_ID} ${USER_NAME}
RUN adduser ${USER_NAME} sudo
RUN passwd -d ${USER_NAME}
WORKDIR /home/${USER_NAME}

RUN mkdir /root/.ssh && chmod 0700 /root/.ssh
COPY ${USER_HOME}/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub
COPY ${USER_HOME}/.ssh/id_rsa /root/.ssh/id_rsa
RUN chmod 400 ~/.ssh/id_rsa

RUN sudo ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
RUN git clone https://github.com/SeongwoongCho/dotfiles.git ~/.dotfiles
RUN cd ~/.dotfiles && bash src/install.sh

CMD ["zsh"]