ARG VERSION=3.2.9-trixie

FROM haproxy:$VERSION AS build

USER 0

RUN \
    LUA_VERSION=$(haproxy -vv | awk '/: Lua /{print $NF}' | awk -F'.' '{print $1"."$2}') &&\
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
        libmariadb-dev-compat

COPY print_r.lua /build/

RUN \
    LUA_VERSION=$(haproxy -vv | awk '/: Lua /{print $NF}' | awk -F'.' '{print $1"."$2}') &&\
    LUA_INSTALL="luarocks --lua-version $LUA_VERSION --tree /build install" &&\
    #$LUA_INSTALL lua-llthreads2 &&\
    $LUA_INSTALL time-sleep &&\
    $LUA_INSTALL luaposix &&\
    $LUA_INSTALL ansicolors &&\
    $LUA_INSTALL string-split &&\
    $LUA_INSTALL redis-lua &&\
    $LUA_INSTALL luasql-mysql MYSQL_INCDIR=/usr/include/mysql &&\
    cp -v /build/print_r.lua /build/share/lua/$LUA_VERSION/

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
        libmariadb3

USER haproxy
