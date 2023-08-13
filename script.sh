#!/bin/bash

script_version="0.1"
script_dir="$(dirname "$(realpath "$0")")"

# Run all commands by default
script_command=fetch

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
    echo -e "./script.sh [build|fetch|all] [-h|v|n] [-p] [ARG]"
    echo
    echo -e "${YELLOW}EXAMPLE${CLEAR}"
    echo -e "Build all docker images without pusshing with verbose output"
    echo -e "./script.sh build --no-push -v"
    echo
    echo -e "${YELLOW}COMMANDS${CLEAR}"
    echo -e "build               Build docker images."
    echo -e "fetch               Fetch latest versions."
    echo -e "fetch-openssl       Fetch latest openssl version and print to console."
    echo -e "fetch-nginx         Fetch latest nginx version and print to console."
    echo
    echo -e "${YELLOW}OPTIONS${CLEAR}"
    echo -e "-h --help           Print this Help."
    echo -e "-v --verbose        Verbose output"
    echo -e "-b --no-build       Don't trigger build if new version is available"
    echo -e "-n --no-push        Don't push images, only build"
    echo -e "-p --path     [ARG] Path"
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
            fetch)
                script_command=fetch
                shift # shift argument
            ;;
            fetch-openssl)
                script_command=fetch-openssl
                shift # shift argument
            ;;
            fetch-nginx)
                script_command=fetch-nginx
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
            --no-build|-b)
                no_build=true
                shift # shift argument
            ;;
            --no-push|-n)
                no_push=true
                shift # shift argument
            ;;
            --path|-p)
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

function build_images {
    # Check for required commands 
    command -v jq >/dev/null || error_msg "Please install jq JSON parser package"
    
    # Set versions 
    OPENSSL_VERSION=$(jq -r '.versions.openssl' data.json) 
    NGINX_VERSION=$(jq -r '.versions.nginx' data.json) 

    info_msg "Copying data.json"
    cp -v "${script_dir}/data.json" "${script_dir}/.data.json"
    
    info_msg "Replacing variables in .data.json"
    sed -i "s/%%openssl%%/${OPENSSL_VERSION}/g" "${script_dir}/.data.json"
    sed -i "s/%%nginx%%/${NGINX_VERSION}/g" "${script_dir}/.data.json"

    info_msg ".data.json diff:\n $(diff --color data.json .data.json)"

    # Set docker repository 
    docker_repo=$(jq -r '.docker.repository' data.json)
    
    # Load images from data JSON to Bash list
    local images=($(jq -r '.images[]|.name' .data.json))

    # Loop through all images in list
    for image in "${images[@]}"; do
        info_msg "Building $image for $docker_repo"
        
        # Load tags for image from data JSON to Bash list
        local tags=($(jq -r ".images[] | select(.name == \"${image}\") | .tags | join (\" \")" .data.json)) 
        local dockerfile="$(jq -r ".images[] | select(.name == \"${image}\") | .dockerfile" .data.json)"
        local full_img_name="${docker_repo}:${image}"

        # Build image 
        info_msg "Building ${full_img_name}" 
        docker build --progress plain \
            --build-arg="OPENSSL_VERSION=openssl-${OPENSSL_VERSION}" \
            -f "${dockerfile}" \
            --tag "${full_img_name}" \
            . \
            && success_msg "Image ${full_img_name} build sucess" \
            || failed_builds="${failed_builds} ${full_img_name}"

        # Loop through all tags in list
        for tag in "${tags[@]}"; do
            info_msg "Retaging ${full_img_name} to ${docker_repo}:${tag}"
            
            # Retag image with all alternative tags
            docker tag "${full_img_name}" "${docker_repo}:${tag}" \
                && success_msg "Sucessfully retagged ${full_img_name} to ${docker_repo}:${tag}" \
                || error_msg "Failed to retag ${full_img_name} to ${docker_repo}:${tag}" 1
            
            # Check if --no-push tag was passed
            if [ -z "$no_push" ]; then
                # Push retagged image 
                docker push "${docker_repo}:${tag}" \
                    && success_msg "Sucessfully pushed ${docker_repo}:${tag}" \
                    || error_msg "Failed to push ${docker_repo}:${tag}" 1
            else
                warning_msg "Not pushing image since --no-push flag was passed"
            fi
        done 
        success_msg "Succesfully built and pushed $image for $docker_repo"
    done
    success_msg "Succesfully finished built procedure"
}

function fetch_version_openssl {
    # Get latest OpenSSL version and print result

    curl -s "https://api.github.com/repos/openssl/openssl/tags" | \
        # Get all tag names
        jq -r '.[]|.name' | \
        # Get "openssl-3.x.x" pattern
        grep -P -m 1 'openssl-3\.[0-9]+\.[0-9]+$' | \
        # Get version number after "openssl-"
        cut -d "-" -f2 
}

function fetch_version_nginx {
    # Get latest Nginx version and print result
    
    curl -s "https://api.github.com/repos/nginx/nginx/tags" | \
        # Get all tag names
        jq -r '.[]|.name' | \
        # Get first "release-x.x.x" match
        grep -P -m 1 'release-[0-9]+\.[0-9]+\.[0-9]+$' | \
        # Get version number after "release-"
        cut -d "-" -f2     
}

function fetch_versions {
    # Check for required commands 
    command -v sponge >/dev/null || error_msg "Please install sponge utility from moreutils package"
    command -v jq >/dev/null || error_msg "Please install jq JSON parser package"
    command -v curl >/dev/null || error_msg "Please install curl"

    info_msg "Fetching versions"

    # Get latest openssl version 
    local openssl_version=$(fetch_version_openssl)

    # Get latest nginx version 
    local nginx_version=$(fetch_version_nginx)

    info_msg "Fetched latest versions:" 
    info_msg "OpenSSL $openssl_version"
    info_msg "Nginx $nginx_version"
    
    [[ "$nginx_version" != $(jq -r '.versions.nginx' data.json) ]] \
        && warning_msg "New Nginx version" \
        && version_trigger=1 \
        || success_msg "Nginx version unchaged"

    [[ "$openssl_version" != $(jq -r '.versions.openssl' data.json) ]] \
        && warning_msg "New OpenSSL version" \
        && version_trigger=1 \
        || success_msg "OpenSSL version unchaged"
    
    [[ -n "$version_trigger" ]] && warning_msg "New Version detected"

    # Save version data to json 
    jq ".versions.openssl=\"$openssl_version\"" data.json | sponge data.json
    jq ".versions.nginx=\"$nginx_version\"" data.json | sponge data.json

    success_msg "All versions fetched and saved to data.json file"

    # If no_build is undefined and version_trigger is not empty
    if [ -z "$no_build" ] && [ -n "$version_trigger" ]; then
        warning_msg "Build triggered"
        build_images
    elif [ -n "$version_trigger" ]; then 
        warning_msg "Version change detected but build not triggered"
    else
        success_msg "Build not triggered"
    fi
}

# Run Command parser
case $script_command in
    build)
        build_images
        shift # shift argument
    ;;
    fetch)
        fetch_versions
        shift # shift argument
    ;;
    fetch-openssl)
        fetch_version_openssl
        shift # shift argument
    ;;
    fetch-nginx)
        fetch_version_nginx
        shift # shift argument
    ;;
    *)
        error_msg "Unknown command '$script_command'"
        error_msg "Please see list of commands that you can run in help"
        exit 1
    ;;
esac

# Check for failed variables and output bad exit code
if [ -n "$failed_builds" ]; then
    error_msg "Some builds were not sucessfull:\n${YELLOW}${failed_builds}"
    exit 1
fi

exit 0
