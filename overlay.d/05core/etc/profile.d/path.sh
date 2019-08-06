# install default PATH file to expand non-login shells PATH for kola
# https://github.com/openshift/os/issues/191
pathmunge /bin
pathmunge /sbin
pathmunge /usr/bin
pathmunge /usr/sbin
pathmunge /usr/local/bin
pathmunge /usr/local/sbin
