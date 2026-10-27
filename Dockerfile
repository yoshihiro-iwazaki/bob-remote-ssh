# IBM Bob の Remote-SSH 検証用「リモート Linux ホスト」
# 元記事: https://www.the-main-thread.com/p/ibm-bob-remote-ssh-podman-macos-linux

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# openjdk-21-jdk / maven は記事のデモ (Maven プロジェクトのビルド) 用。不要なら削ってよい
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-server sudo bash curl git ca-certificates tar gzip unzip \
      procps less nano vim iproute2 locales \
      openjdk-21-jdk maven \
 && locale-gen en_US.UTF-8 ja_JP.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

RUN sed -i '1i : "${LANG:=C.UTF-8}"; export LANG' /etc/bash.bashrc

# UsePAM no の場合、useradd 直後のロック状態 ("!") だと公開鍵でもログインを拒否される。
# "*" にしてロック解除しつつパスワードログインは不可能にしておく (記事の passwd -d の代替)
RUN useradd -m -s /bin/bash bob \
 && usermod -p '*' bob \
 && echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob \
 && chmod 0440 /etc/sudoers.d/bob \
 && install -d -m 700 -o bob -g bob /home/bob/.ssh \
 && install -d -o bob -g bob /home/bob/workspace /home/bob/workspace/demo-app

# リモート側のプロジェクトであることが分かるよう、目印の README を置く
RUN printf '%s\n' '# このディレクトリはリモート環境 (Docker コンテナ bob-remote-host) 上のプロジェクトです' \
      > /home/bob/workspace/demo-app/README.md \
 && chown bob:bob /home/bob/workspace/demo-app/README.md

COPY --chown=bob:bob --chmod=600 ssh/bob_remote_key.pub /home/bob/.ssh/authorized_keys
COPY --chmod=644 sshd/remote-dev.conf /etc/ssh/sshd_config.d/remote-dev.conf

# sshd -t で設定ミスがあればビルド時点で失敗させる
RUN mkdir -p /run/sshd \
 && ssh-keygen -A \
 && /usr/sbin/sshd -t

EXPOSE 2222

CMD ["/usr/sbin/sshd", "-D", "-e"]
