# fluent-bit-out-http-sequential-plugin
A plugin for `fluent-bit` to get `out-http` to submit long chunks sequentially 

# Approach zero: Utilize out_sequentialhttp plugin for submitting requests sequentially 
## Create a docker file with the out_sequentialhttp plugin in it
Make sure you are on the `plugin-out-sequentialhttp` branch

A sample docker file is provided in the root of the repository. Build the stock image:

```docker build . -t plugin-fluent-bit-image```

Note that we supply the plugin via `-e` flag in the Dockerfile:

```
CMD ["/fluent-bit/bin/fluent-bit", "-e", "/plugin/build/flb-out_sequentialhttp.so","-c", "/fluent-bit/etc/fluent-bit.conf"]
```

It is possible to supply plugins via `-p pluging.conf`, too:

```
[PLUGINS]
    Path /plugin/out_sequentialhttp/build/out_sequentialhttp.so
```

## Sample set up
Let us use a mock server for the sake of this demonstration.

### Fluentbit Configuration

```
[SERVICE]
    Flush         3
    Log_Level     info
    Daemon        off
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

[INPUT]
    Name              dummy
    Tag               *
    Rate              1
    Dummy             {"log":"level-info","msg":"succesful", "username":"username", "email":"email@email.com", "time":"2020-11-25T12:37:22Z"}

[OUTPUT]
    Name             sequentialhttp
    Match            *
    Retry_Limit      False
    Host             mock
    Port             8081
    URI              /audit-log
    Header           Content-Type application/json
    HTTP_User        user
    HTTP_Passwd      pass
    Format           json_stream
    tls              on
    tls.verify       off
```


### Mockserver configuration

Here is the content of `initializer.json`:

```
[
  {
    "httpRequest": {
      "path": "/audit-log"
    },
    "httpResponse": {
      "statusCode": 201,
      "body": "some response"
    }
  }
]
```

## Sample execution
```
docker network create logging

docker run --rm -it --name fluent --network logging --mount type=bind,source="$(pwd)",target="/fluent-bit/etc" docker.io/library/plugin-fluent-bit-image

docker run --rm --name mock --network logging -ti --mount type=bind,source="$(pwd)",target="/config" -p 8081:1080  mockserver/mockserver -serverPort 8081

```