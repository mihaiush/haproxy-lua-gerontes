ARG VERSION=3.2.9-trixie

FROM haproxy:$VERSION AS build

USER 0

RUN \
    LUA_VERSION=$(haproxy -vv | awk '/: Lua /{print $NF}' | awk -F'.' '{print $1"."$2}') &&\
    echo "export LUA_VERSION=$LUA_VERSION" >>/environ

RUN \
    . /environ &&\
    echo 'APT::Install-Recommends "false";' >>/etc/apt/apt.conf &&\
    echo 'APT::Install-Suggests "false";' >>/etc/apt/apt.conf &&\
    export DEBIAN_FRONTEND=noninteractive &&\
    apt-get -y update &&\
    apt-get -y install \
        build-essential \
        git \
        luarocks \
        lua${LUA_VERSION} \
        liblua${LUA_VERSION}-dev \
        libmariadb-dev-compat \
        libpq-dev

RUN \
    . /environ &&\
    LUA_INSTALL="luarocks --lua-version $LUA_VERSION --tree /build install" &&\
    $LUA_INSTALL time-sleep &&\
    $LUA_INSTALL luaposix &&\
    $LUA_INSTALL ansicolors &&\
    $LUA_INSTALL string-split &&\
    $LUA_INSTALL lunajson &&\
    $LUA_INSTALL redis-lua &&\
    $LUA_INSTALL luasql-mysql MYSQL_INCDIR=/usr/include/mysql &&\
    $LUA_INSTALL luasql-postgres PGSQL_INCDIR=/usr/include/postgresql

COPY static /static/
RUN \ 
    . /environ &&\
    cp -rv /static/* /build/share/lua/$LUA_VERSION/

FROM haproxy:$VERSION

USER 0

COPY --from=build /build/lib/lua /usr/local/lib/lua/
COPY --from=build /build/share/lua /usr/local/share/lua/

RUN \
    LUA_VERSION=$(haproxy -vv | awk '/: Lua /{print $NF}' | awk -F'.' '{print $1"."$2}') &&\
    echo 'APT::Install-Recommends "false";' >>/etc/apt/apt.conf &&\
    echo 'APT::Install-Suggests "false";' >>/etc/apt/apt.conf &&\
    export DEBIAN_FRONTEND=noninteractive &&\
    apt-get -y update &&\
    apt-get -y install \
        tini \
        libmariadb3 \
        libpq5

USER haproxy

ENTRYPOINT ["/usr/bin/tini", "--", "haproxy"]
