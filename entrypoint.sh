#!/bin/bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2019 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
##                                                                                                                     ~
## Licensed under the GNU Lesser General Public License v3.0 (the 'License'). You may not use this file except in      ~
## compliance with the License. You may obtain a copy of the License at: https://choosealicense.com/licenses/lgpl-3.0  ~
## Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on ~
## an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the  ~
## specific language governing permissions and limitations under the License.                                          ~
##                                                                                                                     ~
## Maintainers:                                                                                                        ~
##     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Carel Bast                                                                                           ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

if [[ "${INPUT_TRACE:-false}" == "true" ]]; then
    for name in         \
            TRACE       \
            HOST        \
            REGION      \
            BUCKET      \
            ACCESS_KEY  \
            SECRET_KEY  \
            CMD         \
            LOCAL_DIR   \
            S3_DIR      \
        ; do
        printf "# %12s = %s\n" "$name" "$(eval "echo \${INPUT_$name:-}")"
    done
    set -x
fi

if ! command -v s3cmd >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y s3cmd
fi

if [[ "$INPUT_HOST" == "" ]];then
    if [[ "$INPUT_REGION" == "" ]]; then
        INPUT_REGION="nl-ams"
    fi
    INPUT_HOST="s3.$INPUT_REGION.scw.cloud"
fi
if [[ "$INPUT_CMD" != "put" && "$INPUT_CMD" != "get" && "$INPUT_CMD" != "nop" ]]; then
    echo "::error::CMD must be 'put' or 'get' (not '$INPUT_CMD')"
    exit 99
fi

echo "# going to $INPUT_CMD on $INPUT_HOST"

s3cmd_(){
    s3cmd                                           \
                   --host="https://$INPUT_HOST"     \
            --host-bucket=                          \
             --access_key="$INPUT_ACCESS_KEY"       \
             --secret_key="$INPUT_SECRET_KEY"       \
        "$@"
}

case "$INPUT_CMD" in
(put)
    if ! s3cmd_ -q ls "s3://$INPUT_BUCKET"; then
        echo "# creating bucket: $INPUT_BUCKET"
        s3cmd_  mb "s3://$INPUT_BUCKET"
    fi
    s3cmd_ --recursive put "$INPUT_LOCAL_DIR/" "s3://$INPUT_BUCKET/$INPUT_S3_DIR/"
    ;;
(get)
    mkdir -p "$INPUT_LOCAL_DIR"
    if ! s3cmd_ -q ls "s3://$INPUT_BUCKET"; then
        echo "# creating bucket: $INPUT_BUCKET"
        s3cmd_  mb "s3://$INPUT_BUCKET"
    fi
    s3cmd_ --recursive get "s3://$INPUT_BUCKET/$INPUT_S3_DIR/" "$INPUT_LOCAL_DIR/"
    ;;
(nop)
    ;;
esac
