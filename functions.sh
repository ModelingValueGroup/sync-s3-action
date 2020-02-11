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

main() {
    local      access_key="$1"; shift
    local      secret_key="$1"; shift
    local   trigger_token="$1"; shift
    local             cmd="$1"; shift
    local          bucket="$1"; shift
    local       local_dir="$1"; shift
    local          s3_dir="$1"; shift
    local s3_dir_branched="$1"; shift
    local            host="$1"; shift
    local          region="$1"; shift

    if [[ "${host:-}" == "" ]];then
        region="${region:-nl-ams}"
          host="s3.region.scw.cloud"
    fi
    if [[ "${s3_dir_branched:-}" != "" && "${s3_dir:-}" != "" ]]; then
        echo "::error::only pass one of: s3_dir, s3_dir_branched"
        exit 67
    fi
    if [[ "${s3_dir_branched:-}" != "" ]]; then
        local g a v e flags bareBranch
        # shellcheck disable=SC2034
        read -r g a v e flags < <(getFirstArtifactWithFlags)
        if [[ "$g" != "" ]]; then
            bareBranch="$(sed 's|refs/heads/||;s|/|_|g' <<<"$GITHUB_REF")"
            s3_dir="$s3_dir_branched/$g/$a/$bareBranch"
        fi
    fi

    prepS3cmd "https://$host" "$access_key" "$secret_key"

    local loc buc rem
    loc="$local_dir/"
    buc="s3://$bucket"
    rem="$(sed 's|^s3:/||;s|//*|/|g;s|/[.]/|/|g;s|^|s3:/|' <<<"$buc/$s3_dir/")"

    case "$cmd" in
    (get)
        s3get "$buc" "$rem" "$loc"
        ;;
    (put)
        s3put "$buc" "$loc" "$rem"
        if [[ "$s3_dir_branched" != "" && "$trigger_token" != "" ]]; then
            trigger "$trigger_token" "$rem"
        fi
        ;;
    (*)
        echo "::error::'cmd' must be 'put' or 'get' (not '$cmd')"
        exit 99
        ;;
    esac
}
