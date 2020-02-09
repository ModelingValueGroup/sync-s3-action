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

export PROJECT_SH="project.sh"
export TRIGGERS_DIR="triggers"
export INPUT_VARS=(
    TRACE
    HOST
    REGION
    BUCKET
    ACCESS_KEY
    SECRET_KEY
    CMD
    LOCAL_DIR
    S3_DIR
    S3_DIR_BRANCHED
    TRIGGERS
)

setupTracing() {
    if [[ "${INPUT_TRACE:-false}" == "true" ]]; then
        for name in "${INPUT_VARS[@]}"; do
            printf "# %16s = %s\n" "$name" "$(eval "echo \${INPUT_$name:-}")"
        done
        set -x
    fi
}
handleArgs() {
    if [[ "${INPUT_HOST:-}" == "" ]];then
        INPUT_REGION="${INPUT_REGION:-nl-ams}"
        INPUT_HOST="s3.$INPUT_REGION.scw.cloud"
    fi
    if [[ "${INPUT_S3_DIR_BRANCHED:-}" != "" && "${INPUT_S3_DIR:-}" != "" ]]; then
        echo "::error::only pass one of: s3_dir, s3_dir_branched"
        exit 67
    fi
    if [[ "${INPUT_S3_DIR_BRANCHED:-}" != "" ]]; then
        local g a v e flags
        read g a v e flags < <(getFirstArtifactWithFlags)
        if [[ "$g" != "" ]]; then
            local bareBranch="$(sed 's|refs/heads/||;s|/|_|g'  <<<$GITHUB_REF)"
            INPUT_S3_DIR="$INPUT_S3_DIR_BRANCHED/$g/$a/$bareBranch"
        fi
    fi
}
getFirstArtifactWithFlags() {
    if [[ ! -f "$PROJECT_SH" ]]; then
        echo "::error::$PROJECT_SH file not found" 1>&2
        exit 45
    fi
    local artifacts=()
    . $PROJECT_SH
    printf "%s\n" "${artifacts[0]}"
}
installS3cmd() {
    export   S3CMD_HOST_URL="$1"; shift
    export S3CMD_ACCESS_KEY="$1"; shift
    export S3CMD_SECRET_KEY="$1"; shift

    if ! command -v s3cmd >/dev/null; then
        sudo apt-get update
        sudo apt-get install -y s3cmd
    fi
}
s3cmd_() {
    s3cmd                                   \
               --host="$S3CMD_HOST_URL"     \
         --access_key="$S3CMD_ACCESS_KEY"   \
         --secret_key="$S3CMD_SECRET_KEY"   \
        --host-bucket=                      \
        "$@"
}
get() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    echo "# going to get from '$S3CMD_HOST_URL' from '$from' to '$to'"
    mkdir -p "$to"
    s3cmd_ --recursive get "$from" "$to"
}
put() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    echo "# going to put on '$S3CMD_HOST_URL' from '$from' to '$to'"
    if ! s3cmd_ ls "$buc" 2>/dev/null 1>&2; then
        echo "# bucket not found, creating bucket: $buc"
        s3cmd_ mb "$buc"
    fi
    s3cmd_ --recursive put "$from" "$to"
}
trigger() {
    local   to="$1"; shift

    if [[ "$INPUT_TRIGGERS" == "true" ]]; then
        if [[ "$(s3cmd_ ls "$to$TRIGGERS_DIR/" | wc -l)" != 0 ]]; then
            local triggersTmpDir="$TRIGGERS_DIR-$$"
            s3cmd_ get "$to$TRIGGERS_DIR/" "$triggersTmpDir"
            local f
            for f in $triggersTmpDir/*.trigger; do
                if [[ -f "$f" ]]; then
                    # TODO: do the actual triggering
                    echo "found trigger file: $f:"
                    sed 's/^/       /' "$f"
                fi
            done
            rm -rf "$triggersTmpDir"
        fi
    fi
}
triggerOther() {
    curl \
        -XPOST \
        -u "${{ secrets.PAT_USERNAME}}:${{secrets.PAT_TOKEN}}" \
        -H "Accept: application/vnd.github.everest-preview+json"  \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/YOURNAME/APPLICATION_NAME/dispatches" \
        --data '{"event_type": "build_application"}'
}
main() {
    setupTracing
    handleArgs

    installS3cmd "https://$INPUT_HOST" "$INPUT_ACCESS_KEY" "$INPUT_SECRET_KEY"

    local loc="$INPUT_LOCAL_DIR/"
    local buc="s3://$INPUT_BUCKET"
    local rem="$(sed 's|^s3:/||;s|//*|/|g;s|/[.]/|/|g;s|^|s3:/|' <<<"$buc/$INPUT_S3_DIR/")"

    case "$INPUT_CMD" in
    (get)
        get "$buc" "$rem" "$loc"
        ;;
    (put)
        put "$buc" "$loc" "$rem"
        trigger "$rem"
        ;;
    (*)
        echo "::error::'cmd' must be 'put' or 'get' (not '$INPUT_CMD')"
        exit 99
        ;;
    esac
}
