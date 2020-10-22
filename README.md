# sync-s3-action
```get``` or ```put``` files from/to an S3 bucket

The Amsterdam Scaleway S3 repo is the default but you can use other Scaleway and AWS as well.

## Example Usage

To put some files in S3:
```yaml
      - name: "put in S3"
        uses: ModelingValueGroup/sync-s3-action@master
        with:
          access_key: "${{ secrets.SCALEWAY_ACCESS_KEY }}"
          secret_key: "${{ secrets.SCALEWAY_SECRET_KEY }}"
          bucket    : my-bucket
          cmd       : put
          local_dir : theDirOnDiskForPut
          s3_dir    : theDirInS3
```
To get this file back:
```yaml
      - name: "get from S3"
        uses: ModelingValueGroup/sync-s3-action@master
        with:
          access_key: "${{ secrets.SCALEWAY_ACCESS_KEY }}"
          secret_key: "${{ secrets.SCALEWAY_SECRET_KEY }}"
          bucket    : my-bucket
          cmd       : get
          local_dir : theDirOnDiskForGet
          s3_dir    : theDirInS3
```

# Current structure in S3

```
    aBucket
        /<group>
            /<artifact>
                /<branch-name>
                    /<asset-1>
                    /<asset-2>
                    /triggers
                        /<github-user>#<github-repo>.trigger
```
where ```trigger``` files contain:
```
TRIGGER_REPOSITORY='<github-user>/<github-repo>'
TRIGGER_BRANCH='<branch-name>'
```
The presence of one or more trigger files tells the script that publishes a new version of an asset that the actions job 
at the mentioned repo and branch should be triggered.

### Future structure (on Github)
```
    <github-user>/artifacts
        [branch-name]
            /trigger
                /<group>
                    /<artifact>
                        /<github-user>#<github-repo>.trigger
            /lib
                /<group>
                    /<artifact>
                        /<object-1>
                        /<object-2>
```
