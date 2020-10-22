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

export ARTIFACTS_REPOS="tmp-artifacts"
export ARTIFACTS_CLONE="/tmp/artifacts/$ARTIFACTS_REPOS"

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
          host="s3.$region.scw.cloud"
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

    local confArg="$(prepS3cmd "https://$host" "$access_key" "$secret_key")"

    local loc buc rem
    loc="$local_dir/"
    buc="s3://$bucket"
    rem="$(sed 's|^s3:/||;s|//*|/|g;s|/[.]/|/|g;s|^|s3:/|' <<<"$buc/$s3_dir/")"

    case "$cmd" in
    (get)
        s3get "$confArg" "$buc" "$rem" "$loc"
        ;;
    (put)
        s3put "$confArg" "$buc" "$loc" "$rem"
        if [[ "$s3_dir_branched" != "" && "$trigger_token" != "" ]]; then
            s3trigger "$confArg" "$trigger_token" "$rem"
        fi
        ;;
    (*)
        echo "::error::'cmd' must be 'put' or 'get' (not '$cmd')"
        exit 99
        ;;
    esac
}
#############################################################################################
#############################################################################################
### the new functionality, using github iso S3
#############################################################################################
#############################################################################################
prepare() {
    local trigger_token="$1"; shift
    local    bareBranch="$1"; shift

    git config --global user.email "automation@modelingvalue.nl"
    git config --global user.name  "automation"

    rm -rf "$ARTIFACTS_CLONE"
    mkdir -p "$ARTIFACTS_CLONE"
    (   cd "$ARTIFACTS_CLONE/.."
        if [[ -d "$ARTIFACTS_REPOS/.git" ]]; then
            echo "### clone already on disk"
        elif git clone "https://$trigger_token@github.com/$GITHUB_ACTOR/$ARTIFACTS_REPOS.git"; then
            echo "### clone made"
        else
            echo "### create new repo"
            (   cd "$ARTIFACTS_CLONE"
                echo "### create repos $GITHUB_ACTOR/$ARTIFACTS_REPOS"
                printf "%s\n%s\n" "# ephemeral artifacts repo" "Build assets from branches are stored here. This is an ephemeral repo." > "README.md"
                git init
                git add "README.md"
                git commit -m "first commit"
                git remote add origin "git@github.com:$GITHUB_ACTOR/$ARTIFACTS_REPOS.git"
                curl -X POST \
                        --location \
                        --remote-header-name \
                        --fail \
                        --silent \
                        --show-error \
                        --header "Authorization: token $trigger_token" \
                        -d '{"name":"'"$ARTIFACTS_REPOS"'"}' \
                        "$GITHUB_API_URL/orgs/$GITHUB_ACTOR/repos" \
                        -o - \
                    | jq .
               git push -u origin master

               git checkout -b _
               git push -u origin _

               git checkout -b develop
               git push -u origin develop
            )
        fi #>> "$ARTIFACTS_CLONE/../log" 2>&1

        if [[ ! -d "$ARTIFACTS_REPOS/.git" ]]; then
            echo "::error::could not clone or create $GITHUB_ACTOR/$ARTIFACTS_REPOS" 1>&2
            exit 24
        fi

        (   cd "$ARTIFACTS_CLONE"
            echo "### checkout $bareBranch"
            if ! git checkout "$bareBranch"; then
                git checkout _
                git checkout -b "$bareBranch"
                git push -u origin "$bareBranch"
            fi
        ) #>> "$ARTIFACTS_CLONE/../log" 2>&1
    )
}
push() {
    (   cd "$ARTIFACTS_CLONE"
        echo "### pushing"
        git add .
        git commit -a -m "branch assets @$(date +'%Y-%m-%d %H:%M:%S')"
        git push || echo bla
    ) #>> "$ARTIFACTS_CLONE/../log" 2>&1
}
copyAll() {
    local local_dir="$1"; shift
    local  subPath="$1"; shift

    mkdir -p "$ARTIFACTS_CLONE/lib/$subPath"
    cp -r "$local_dir/" "$ARTIFACTS_CLONE/lib/$subPath"
}
triggerAll() {
    local subPath="$1"; shift

    local trigger
    for trigger in "$ARTIFACTS_CLONE/trigger/$subPath"/*; do
        if [[ -f "$trigger" ]]; then
            . "$trigger"
            echo "TRIGGER $TRIGGER_REPOSITORY -> $TRIGGER_BRANCH" # TODO
        fi
    done
}
newmain() {
    local   trigger_token="$1"; shift
    local       local_dir="$1"; shift
    local           group="$1"; shift
    local        artifact="$1"; shift
    local          branch="$1"; shift

    local      bareBranch="${branch#refs/heads/}"
    local         subPath="${group//./\/}/$artifact"

    prepare "$trigger_token" "$bareBranch"
    copyAll "$local_dir" "$subPath"
    push
    triggerAll "$subPath"
}

testit() {
    . ~/secrets.sh
      GITHUB_ACTOR="ModelingValueGroup"
    GITHUB_API_URL="https://api.github.com"


    testBranch="refs/heads/feature/my-funny-branch-name"
    testBranch="feature/my-funny-branch-name"
    testBranch="master"
    testBranch="develop"
    testBranch="feature/should-be-based-on-_"

    rm -rf /tmp/artifacts-tmp
    mkdir /tmp/artifacts-tmp
    (   cd /tmp/artifacts-tmp

        mkdir upl
        echo "aap$(date +'%Y-%m-%d %H:%M:%S')" > upl/asset1.txt
        echo "bla$(date +'%Y-%m-%d %H:%M:%S')" > upl/asset2.txt

        #set -x
        rm -f "$ARTIFACTS_CLONE/../log"
        newmain \
                "$INPUT_TOKEN3" \
                "upl" \
                "the.group.name" \
                "the-artifact-name" \
                "$testBranch" \
            || echo "failed: $?"

        sed 's/^/ >>> /' $ARTIFACTS_CLONE/../log || :
    )
}
