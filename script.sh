#!/bin/bash

# OPENSSL_CONF=/usr/local/ssl/openssl.cnf openssl ciphers | tr ":" "\n"  | grep GOST
# OPENSSL_CONF=/usr/local/ssl/openssl.cnf openssl ciphers -v
# vim /usr/local/ssl/openssl.cnf
# openssl engine -vv
# openssl engine -vvv
# openssl engine -t -tt -vvvv dynamic
# openssl engine -t -tt -vvvv dynamic
# openssl engine -c
# OPENSSL_ENGINES=/usr/local/lib64/engines-3 openssl engine -c
# OPENSSL_CONF=/etc/ssl/openssl.cnf engine dynamic -pre SO_PATH:gost -pre LOAD
# OPENSSL_CONF=/etc/ssl/openssl.cnf openssl engine dynamic -pre SO_PATH:gost -pre LOAD
# OPENSSL_CONF=/etc/ssl/openssl.cnf openssl engine dynamic -pre SO_PATH:gost -pre LOAD
# find . -type "f" -name "dso_lic.c"
# find . -type "f" -name "dso_lic.so"
# find . -type "f" -name "gost.so"
# find . -type "f" -name "dso*"
# OPENSSL_CONF=/etc/ssl/openssl.cnf openssl list -objects | grep GOST
# openssl ciphers -v 'ALL:eNULL' | grep gost  
# OPENSSL_CONF=/usr/local/ssl/openssl.cnf OPENSSL_ENGINES=/usr/local/lib64/engines-3/gost.so openssl ciphers   
# OPENSSL_CONF=/usr/local/ssl/openssl.cnf OPENSSL_ENGINES=/usr/local/lib64/engines-3 openssl ciphers   




script_version="0.1"
script_dir=$(dirname "$(realpath $0)")
docker_image="mbrav/docker-gost"

# Run repo program by default
script_command=build

# COLORS
ncolors=$(command -v tput > /dev/null && tput colors) # supports color
if [[ -n $ncolors && -z $NO_COLOR ]]; then
    TERMCOLS=$(tput cols)
    CLEAR="$(tput sgr0)"

    # 4 bit colors 
    if test $ncolors -ge 8; then 
        # Normal 
        BLACK="$(tput setaf 0)"
        RED="$(tput setaf 1)"
        GREEN="$(tput setaf 2)"
        YELLOW="$(tput setaf 3)"
        BLUE="$(tput setaf 4)"
        MAGENTA="$(tput setaf 5)"
        CYAN="$(tput setaf 6)"
        GREY="$(tput setaf 7)"
    fi

    # >4 bit colors 
    if test $ncolors -gt 8; then 
        # High intensity 
        BLACK_I="$(tput setaf 8)"
        RED_I="$(tput setaf 9)"
        GREEN_I="$(tput setaf 10)"
        YELLOW_I="$(tput setaf 11)"
        BLUE_I="$(tput setaf 12)"
        MAGENTA_I="$(tput setaf 13)"
        CYAN_I="$(tput setaf 14)"
        WHITE="$(tput setaf 15)"
    else
        BLACK_I=$BLACK
        RED_I=$RED
        GREEN_I=$GREEN
        YELLOW_I=$YELLOW
        BLUE_I=$BLUE
        MAGENTA_I=$MAGENTA
        CYAN_I=$CYAN
        WHITE=$GREY
    fi

    # Styles
    BOLD="$(tput bold)"
fi

function error_msg() {
    # Error message
    # $1            - Message string argument 
    # $2 (optional) - exit code  
    echo -e "${RED}${BOLD}[X] ${1}${CLEAR}"
    [[ -n $2 ]] && exit $2
}

function warning_msg() {
    echo -e "${YELLOW}${BOLD}[!] ${*}${CLEAR}"
}

function success_msg() {
    echo -e "${GREEN}${BOLD}[✓] ${*}${CLEAR}"
}

function info_msg() {
    # Info message if $verbose is set
    [ -n "$verbose" ] && echo -e "${CYAN}[i] ${*}${CLEAR}"
}


# Display Help
help() {
    echo -e "${CYAN}${BOLD}Docker GOST multi script v${script_version}${CLEAR}"
    echo
    echo -e "${YELLOW}ABOUT${CLEAR}"
    echo -e "Script for managing Docker GOST CI/Build process"
    echo
    echo -e "${YELLOW}SYNTAX${CLEAR}"
    echo -e "./script.sh [build] [-h|v|b|n|s|a] [-u|i|t|p] [ARG]"
    echo
    echo -e "${YELLOW}EXAMPLE${CLEAR}"
    echo -e "Build all docker images"
    echo -e "./script.sh -v -b -t my-gitlab-token -p ~/gitlab"
    echo
    echo -e "${YELLOW}COMMANDS${CLEAR}"
    echo -e "build               Run download.py (Default)."
    echo -e "report             Run html_reports.py"
    echo -e "rust               Compile and run rust program"
    echo
    echo -e "${YELLOW}OPTIONS${CLEAR}"
    echo -e "-h --help           Print this Help."
    echo -e "-v --verbose        Verbose output"
    echo -e "-p --path     [ARG] Specify Path to where git repos will be downloaded to, Default: ${repo_path}"
    echo
    echo -e "${GREEN}${TERMCOLS} colors ${CLEAR}"
}

# ARG parser
if [ $# -eq 0 ]; then
    # If no arguments, display help
    help
else
    while [ $# -gt 0 ]; do
        case $1 in
            build)
                script_command=build
                shift # shift argument
            ;;
            --help|-h)
                help
                shift # shift argument
                exit 0
            ;;
            --verbose|-v)
                verbose=true
                shift # shift argument
            ;;
            --path|-p)
                repo_path=$(realpath $2)
                shift # shift argument
                shift # shift value
            ;;
            -*)
                error_msg "Unknown option $1" 22
                exit 1
            ;;
            *)
                error_msg "Unknown argument $1"
                echo 'If you want to pass an argument with spaces'
                echo 'pass the argument like this: "my argument"'
                exit 1
            ;;
        esac
    done
fi

function fetch_versions {
    # Run build command
    info_msg "Running build"

    # Get latest OpenSSL version
    # curl -s -o /tmp/openssl.dat https://raw.githubusercontent.com/openssl/openssl/master/VERSION.dat \
    #     warning_msg "Failed fetching newest OpenSSL version"
    # openssl_version=$(source /tmp/openssl.dat && echo "$MAJOR.$MINOR.$PATCH")
    # source /tmp/openssl.dat && openssl_version="$MAJOR.$MINOR.$PATCH"
    # rm /tmp/openssl.dat
    
    openssl_version="3.1.2"

    # Get latest nginx version 
    # curl -s -o /tmp/nginx.h https://raw.githubusercontent.com/nginx/nginx/master/src/core/nginx.h \
    #     warning_msg "Failed fetching newest nginx version"
    # nginx_version="$(grep 'define NGINX_VERSION' /tmp/nginx.h | sed -e 's/^.*"\(.*\)".*/\1/')"
    # rm /tmp/nginx.h
    
    nginx_version="1.25.1"
    info_msg "Latest versions:" 
    info_msg "OpenSSL $openssl_version"
    info_msg "Nginx $nginx_version"
    
    # Save to data file
    echo "OPENSSL_VERSION=$openssl_version" > "${script_dir}/VERSION.dat"
    echo "NGINX_VERSION=$nginx_version" >> "${script_dir}/VERSION.dat"

    success_msg "All versions fetched and saved to VERSION.dat file"
}

function build_images {
    # Build images

    source "${script_dir}/VERSION.dat"

    # Build Debian Bookworm 12
    docker build --progress plain \
        --build-arg="OPENSSL_VERSION=openssl-${OPENSSL_VERSION}" \
        -f debian-bookworm/Dockerfile \
        --tag "${docker_image}:bookworm" \
        . \
        || error_msg "Image ${docker_image}:bookworm failed"

    docker tag "${docker_image}:bookworm" "${docker_image}:latest" 
    docker tag "${docker_image}:bookworm" "${docker_image}:bookworm"
    docker tag "${docker_image}:bookworm" "${docker_image}:bookworm-${OPENSSL_VERSION}"

    docker push "${docker_image}:latest" 
    docker push "${docker_image}:bookworm-${OPENSSL_VERSION}"

    # Build Ubuntu Jammy 22.04
    # docker build --progress plain \
    #     --build-arg="OPENSSL_VERSION=openssl-${OPENSSL_VERSION}" \
    #     -f ubuntu-jammy/Dockerfile \
    #     --tag "${docker_image}:jammy" \
    #     . \
    #     || error_msg "Image ${docker_image}:jammy failed"
    #
    # docker tag "${docker_image}:jammy" "${docker_image}:jammy"
    # docker tag "${docker_image}:jammy" "${docker_image}:jammy-${OPENSSL_VERSION}"
    #
    # docker push "${docker_image}:jammy" 
    # docker push "${docker_image}:jammy-${OPENSSL_VERSION}"

    # Build Debian Bookworm 12 with nginx
    docker build --progress plain \
        --build-arg="OPENSSL_VERSION=openssl-${OPENSSL_VERSION}" \
        --build-arg="NGINX_VERSION=${NGINX_VERSION}" \
        -f debian-bookworm/nginx.Dockerfile \
        --tag "${docker_image}:bookworm-nginx" \
        . \
        || error_msg "Image ${docker_image}:bookworm-nginx failed"

    docker tag "${docker_image}:bookworm-nginx" "${docker_image}:nginx" 
    docker tag "${docker_image}:bookworm-nginx" "${docker_image}:nginx-${OPENSSL_VERSION}" 
    docker tag "${docker_image}:bookworm-nginx" "${docker_image}:nginx-${OPENSSL_VERSION}-${NGINX_VERSION}" 
    docker tag "${docker_image}:bookworm-nginx" "${docker_image}:bookworm-nginx-${OPENSSL_VERSION}" 
    docker tag "${docker_image}:bookworm-nginx" "${docker_image}:bookworm-nginx-${OPENSSL_VERSION}-${NGINX_VERSION}" 

    docker push "${docker_image}:nginx-latest" 
    docker push "${docker_image}:nginx-${OPENSSL_VERSION}" 
    docker push "${docker_image}:nginx-${OPENSSL_VERSION}-${NGINX_VERSION}" 
    docker push "${docker_image}:bookworm-nginx-${OPENSSL_VERSION}" 
    docker push "${docker_image}:bookworm-nginx-${OPENSSL_VERSION}-${NGINX_VERSION}" 

    success_msg "All images built and taged sucessfully"
}

# Run Command parser
case $script_command in
    build)
        fetch_versions
        build_images
        shift # shift argument
        ;;
    *)
        error_msg "Unknown command '$script_command'"
        error_msg "Please see list of commands that you can run in help"
        exit 1
    ;;
esac

exit 0
