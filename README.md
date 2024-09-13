# Concourse HTTP jq resource

A Concourse resource to make HTTP calls to JSON endpoints, and parse them using custom JQ filter. 

**Note: see the section "Cloud.gov Specific Notes" for important information**

## Source Configuration

| Parameter                   | Required | Example                                     | Description                                                                                                                                                                                                                                                                                |
|-----------------------------|----------|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `base_url`                  | Yes      | `https://api.github.com/users/octocat/orgs` | Url for the json payload to get.                                                                                                                                                                                                                                                           |
| `jq_filter`                 | No       | `{user, title: .titles[]}`                  | Valid JQ filter. Defaults to ".". The output of JQ filter needs to be vaild JSON.                                                                                                                                                                                                                                                        |
| `credentials`               | No       | `root:hunter2`                              | Basic auth. Will be base64 encoded.                                                                                                                                                                                                                                                        |
| `headers`                   | No       | `["Cookie: UserName=Bob"]`                  | an array containing headers, in "Name: Value" format.                                                                                                                                                                                                                                      |
| `debug`                     | Yes      | `true`                                      | The default value is `false`, use this when attempting to debug new `jg_filter` values                                                                                                                                                                                                     |

Notes:
 - Look at the [Concourse Resources documentation](https://concourse-ci.org/resources.html#resource-webhook-token)
 for webhook token configuration.

## Behaviour

#### `check`

Produces new versions from a JSON payload defined in `base_url`. `jq_filter` then parses the payload accordingly to your needs.

#### `get`

Does nothing.

#### `put`

Does nothing.

## Examples
### Check deployment version on Bamboo

Triggering a job in concourse based on a release in bamboo.

```yaml
resource_types:
- name: http-jq-resource
  type: docker-image
  source:
    repository: qudini/concourse-http-jq-resource
    tag: latest

resources:
  - name: bamboo-staging-release
    type: http-jq-resource
    source:
      base_url: https://<Bamboo instance>/rest/api/latest/deploy/environment/{env_id}/results?os_authType=basic
      jq_filter: "{.results[] | {"deploymentVersionName":.deploymentVersionName,"id":.id|tostring,"key":.deploymentVersion.items[0].planResultKey.key,"startedDate":.startedDate|tostring,finishedDate:.finishedDate|tostring}"
      # bamboo_readonly_credentials = username:password
      credentials: ((bamboo_readonly_credentials))
```
Results in
```json
[
    {
      "deploymentVersionName": "master-718",
      "id": "107282481",
      "key": "KEY-QD678-718",
      "startedDate": "1579089918295",
      "finishedDate": "1579090971755"
    },
    {
      "deploymentVersionName": "master-717",
      "id": "107282475",
      "key": "KEY-QD678-717",
      "startedDate": "1579027585024",
      "finishedDate": "1579028083334"
    }
]
```
### Check Docker Hub for new docker image tag to trigger a job

```yaml
resource_types:
- name: http-jq-resource
  type: docker-image
  source:
    repository: qudini/concourse-http-jq-resource
    tag: latest

resources:
  - name: dockerhub-http-jq-release
    type: http-jq-resource
    source:
      base_url: https://registry.hub.docker.com/v1/repositories/qudini/concourse-http-jq-resource/tags
      jq_filter: ".[] | {releaseTag:.name}"
```
Results in 

![screenshot of resource with release tags](https://raw.githubusercontent.com/qudini/concourse-http-jq-resource/master/screenshot-1.png)

## Cloud.gov Specific Notes

 - The modified Dockerfile requires `jq`, `wget` and the contents of the `assets` folder of this repo and uses the hardened container the Assurance team maintains as the base image.
 - See [cg-provision](https://github.com/cloud-gov/cg-provision/blob/main/ci/pipeline.yml) for an example of usage

   ```yaml
   resource_types:
     - name: http-jq-resource
       type: registry-image
       source:
         aws_access_key_id: ((ecr_aws_key))
         aws_secret_access_key: ((ecr_aws_secret))
         repository: concourse-http-jq-resource
         aws_region: us-gov-west-1
         tag: latest
   resources:
     - name: check-s3-cidr-ranges
       type: http-jq-resource
       debug: true
       source:
         base_url: https://ip-ranges.amazonaws.com/ip-ranges.json
         jq_filter: '[.prefixes[] | select(.service=="S3") | select(.region=="us-gov-west-1")] | [.[].ip_prefix] | sort | {"range" : join("__")}'
   ```
 - The output needs to be in a single `key: value` format, otherwise Concourse interprets each row returned as separate "new" versions.  In the example above, all the ip addresses are sorted and concatenated so a single row is returned.  
 - `jq_filter` require trial and error to get right.  Enabling `debug: true` in the `resources` block will emit details of the `check` script.
 - The [`check`](https://github.com/cloud-gov/concourse-http-jq-resource/blob/main/assets/check#L40) script attempts to format the results, in particular the `| jq -Ms` at the end has a tendency to make creating `jq_filter` values difficult to configure. Enable the debugging to assist if you run into problems with `jq_filter` values.
 - There is a Concourse pipeline named `concourse-http-jq-resource` that deploys the Dockerfile found in this repo.  There is no `ci/` folder in this repo because the pipeline is controlled by [`common-pipelines`](https://github.com/cloud-gov/common-pipelines/blob/main/ci/container/internal/concourse-http-jq-resource/vars.yml).