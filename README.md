# sync-s3-action
```get``` or ```put``` files from/to an S3 bucket

The Amsterdam Scaleway S3 repo is the default but you can use other Scaleway and AWS as well.

## Example Usage

To put some files in S3:
```yaml
      - name: "put in S3"
        uses: ModelingValueGroup/sync-s3-action@master
        with:
          access_key: "${{ secrets.SCALEWAY_ACC }}"
          secret_key: "${{ secrets.SCALEWAY_SEC }}"
          bucket: my-bucket
          cmd: put
          local_dir: theDirOnDisk
          s3_dir: theDirInS3
```
To get this file back:
```yaml
      - name: "get from S3"
        uses: ModelingValueGroup/sync-s3-action@master
        with:
          access_key: "${{ secrets.SCALEWAY_ACC }}"
          secret_key: "${{ secrets.SCALEWAY_SEC }}"
          bucket: my-bucket
          cmd: get
          local_dir: theDirOnDiskAgain
          s3_dir: theDirInS3
```
